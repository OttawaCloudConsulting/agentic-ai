#!/usr/bin/env bash
# The mediator image's policy compile stage (01.5 SF-4).
#
# R7.4 and D10 require the resolved policy to be compiled BY THE BUILD, never by an
# operator step. The milestone README requires it to be a committed, reviewable
# artifact under policy/resolved/. A build stage cannot write to the repository, so
# Interface Contract 4 resolves the two: the stage compiles authoritatively into the
# image layer, and the build FAILS if that output differs from the committed copy.
#
# This script is those two halves, invoked from images/mediator/Dockerfile:
#
#   emit  <src> <out>        compile every committed artifact's inputs into <out>
#   drift <out> <committed>  refuse to continue if <out> differs from <committed>
#
# They are two stages, not one RUN, and the separation is load-bearing. The host
# wrapper (scripts/compile-policy-build.sh) exists to REGENERATE the committed
# artifact when the inputs change -- which is precisely when emit and committed
# differ. A drift gate inside the emit stage would fail on the only occasion the
# wrapper is needed. So `emit` refuses nothing, `drift` is a separate stage, and the
# runtime image reaches the artifact only THROUGH it: the Dockerfile's final
# `COPY --from=drift` is what makes the gate mechanical rather than advisory.
#
# It lives in the image build context rather than inline in a RUN because the emit
# half has a real branch, and a branch that decides whether policy is compiled or
# copied should be reviewable as code. It runs host-side too, which is how it is
# tested without a build.
set -euo pipefail

usage() { echo "usage: compile-stage.sh emit <src> <out> | drift <out> <committed>" >&2; exit 1; }
fail()  { echo "compile-stage: FAIL: $*" >&2; exit 2; }
note()  { echo "compile-stage: $*" >&2; }

# ------------------------------------------------------------------------------------
# emit -- compile each committed artifact from its own declared inputs.
#
# The set of artifacts is read from policy/resolved/ rather than from a list of profile
# names, because the committed artifacts ARE what the image ships and what the drift
# gate compares against. A profile with no committed artifact (oauth-mount today) is
# not shipped and is not compiled here.
#
# Each artifact names its own bases in `compiled_from`, and the branch is on whether
# those bases are IN THE BUILD CONTEXT -- not on the profile's name:
#
#   * present  -> recompile. This is the authoritative path, and it is the only path
#                 the shipped `default` artifact can take.
#   * absent, and the declared base is a `*.test.yaml` fixture -> carry the committed
#                 copy through. 01.3's harness fixtures are deliberately excluded from
#                 the mediator's context (see .dockerignore), so the stage physically
#                 cannot recompile them, yet compose/overrides/test-egress.yaml runs
#                 the mediator on `test-fixtures`. Recorded as SF-4 Deviation 9.
#   * absent, anything else -> FAIL THE BUILD.
#
# That third branch is the point of writing the test as file-presence in the first
# place. Carrying a copy through is a hole in Contract 4 -- an artifact nothing
# recompiled -- and it must never open silently for a shipped profile. Delete
# `!policy/allowlist.base.yaml` from .dockerignore and this fails loudly instead of
# quietly shipping an uncompiled `default`. Admit the test bases to the context one
# day and they are compiled automatically, with no edit here.
# ------------------------------------------------------------------------------------
emit() {
  local src="$1" out="$2"
  [[ -d "$src/policy/resolved" ]] || fail "$src/policy/resolved is not in the build context"
  [[ -x "$src/scripts/compile-policy.sh" || -f "$src/scripts/compile-policy.sh" ]] \
    || fail "$src/scripts/compile-policy.sh is not in the build context"
  mkdir -p "$out"

  local found=0 f profile allow deny
  for f in "$src"/policy/resolved/*.yaml; do
    [[ -e "$f" ]] || fail "$src/policy/resolved holds no committed artifact"
    found=1
    profile="$(basename "$f" .yaml)"

    allow="$(yq eval '.compiled_from.allowlist' "$f")"
    deny="$(yq eval '.compiled_from.denylist' "$f")"
    [[ -n "$allow" && "$allow" != "null" ]] || fail "$f: compiled_from.allowlist is missing"
    [[ -n "$deny"  && "$deny"  != "null" ]] || fail "$f: compiled_from.denylist is missing"

    if [[ -f "$src/$allow" && -f "$src/$deny" ]]; then
      note "compiling $profile from $allow + $deny"
      # --allowlist/--denylist are passed ONLY where they differ from the compiler's
      # own defaults, and that is not a tidiness choice -- it was found by probing.
      # The compiler embeds its re-verification hint in the artifact's header, and the
      # hint names every non-default flag it was given. Passing the base lists
      # explicitly therefore emits a DIFFERENT header from the committed artifact and
      # trips this stage's own drift gate on identical policy. The rule that survives
      # both cases is: reproduce the invocation the artifact records, no more.
      local -a flags=(--profile "$profile" --out "$out/$profile.yaml")
      [[ "$allow" == "policy/allowlist.base.yaml" ]] || flags+=(--allowlist "$allow")
      [[ "$deny"  == "policy/denylist.base.yaml"  ]] || flags+=(--denylist "$deny")
      # Run from $src so the compiler's BASH_SOURCE-derived REPO_ROOT resolves to the
      # laid-out inputs (Edge Case 17, obligation 2).
      ( cd "$src" && bash scripts/compile-policy.sh "${flags[@]}" )
    else
      case "$allow" in
        *.test.yaml)
          note "carrying $profile through: $allow is a harness fixture and is not in the build context (SF-4 Deviation 9)"
          cp "$f" "$out/$profile.yaml"
          ;;
        *)
          fail "$f declares $allow, which is not in the build context. A shipped artifact must be COMPILED by this stage, never copied -- check the .dockerignore allowlist."
          ;;
      esac
    fi
    chmod 0644 "$out/$profile.yaml"
  done
  [[ "$found" == 1 ]] || fail "$src/policy/resolved holds no committed artifact"
}

# ------------------------------------------------------------------------------------
# drift -- the build fails rather than warns (Interface Contract 4).
#
# R5.14 requires policy changes to be version-controlled and reviewed, and a warning in
# a build log is neither. A build that merely warned would produce a mediator running a
# resolved policy no reviewer has seen, and would make the committed artifact
# decorative, since nothing would ever force it to be true.
#
# The comparison is against what this build ACTUALLY EMITTED, not against a third
# compile: `--check` would recompile and compare that, leaving the emitted copy
# unexamined. `compiled_at` is excluded because it changes on every compile by design.
#
# Both directions are checked. An emitted artifact with no committed counterpart is a
# policy nobody reviewed; a committed artifact the stage never emitted is one that
# silently stopped shipping.
# ------------------------------------------------------------------------------------
drift() {
  local out="$1" committed="$2" rc=0 f profile

  for f in "$out"/*.yaml; do
    [[ -e "$f" ]] || fail "$out holds no emitted artifact"
    profile="$(basename "$f" .yaml)"
    if [[ ! -f "$committed/$profile.yaml" ]]; then
      echo "compile-stage: DRIFT: $profile was emitted but policy/resolved/$profile.yaml is not committed." >&2
      rc=1; continue
    fi
    if ! diff -u \
        <(grep -v '^compiled_at:' "$committed/$profile.yaml") \
        <(grep -v '^compiled_at:' "$f") >&2; then
      echo "compile-stage: DRIFT: policy/resolved/$profile.yaml does not match what this build compiled." >&2
      rc=1
    fi
  done

  for f in "$committed"/*.yaml; do
    [[ -e "$f" ]] || continue
    profile="$(basename "$f" .yaml)"
    [[ -f "$out/$profile.yaml" ]] || {
      echo "compile-stage: DRIFT: policy/resolved/$profile.yaml is committed but this build emitted nothing for it." >&2
      rc=1
    }
  done

  if [[ "$rc" != 0 ]]; then
    echo "compile-stage: the resolved policy is a GENERATED, REVIEWED artifact (SC-6, R5.14)." >&2
    echo "compile-stage: refresh it with 'bash scripts/compile-policy-build.sh', review the diff, commit it, and rebuild." >&2
    exit 4
  fi
  note "all emitted artifacts match their committed copies"
}

case "${1:-}" in
  emit)  [[ $# -eq 3 ]] || usage; emit  "$2" "$3" ;;
  drift) [[ $# -eq 3 ]] || usage; drift "$2" "$3" ;;
  *)     usage ;;
esac
