# Input Resolution

How `/research` turns whatever the user typed into four resolved values:
`research_question`, `input_files`, `available_tooling`, and `artifact_path`.

The skill accepts free text, paths, or both, because those are the two
states real work arrives in. Sometimes you have a question and nothing
written down. Sometimes someone already wrote a problem statement and an
options survey, and the thing that is actually missing is an adversarial
opinion about which option to pick. Both are valid entry points and neither
should require reformatting the other.

## Parsing the arguments

Treat every whitespace-separated token that resolves to an existing path on
disk as an input path. Everything else is free text.

| Invocation | Resolves to |
|---|---|
| `/research` (no args) | Nothing — prompt for question and tooling |
| `/research Is Redis Streams a fit for our job queue?` | Question only |
| `/research docs/_working/auth-options/` | Directory input, question derived from contents |
| `/research docs/rfc-014.md docs/rfc-015.md` | Two file inputs, question derived |
| `/research docs/_working/auth/ which option actually scales?` | Both — free text is the question, path is prior work |

A token that looks like a path but does not exist is an error, not free
text. Report the exact path and ask; a typo'd path silently reinterpreted as
part of the question produces research aimed at the wrong target.

### Available tooling

Tooling may be stated explicitly (`Available tooling: Redis, NATS,
RabbitMQ`), inferred from the input files (an options document naming its
candidates), or absent entirely. An empty tooling list is normal and fine —
it just means the research is about approaches rather than a bake-off, and
the research agent drops its per-tool sections accordingly.

When you infer tooling from input files rather than being told, say so in
the confirmation prompt. An inferred list the user did not intend is worth
one line to correct and expensive to discover after two agents have run.

## Reading input files

Read input files before prompting the user. This is what lets you propose a
specific question instead of asking the user to retype something they
already wrote down.

**Single file:** read it in full.

**Multiple files:** read each in full.

**Directory:** list it non-recursively first. Read `*.md`, `*.txt`, `*.rst`,
`*.yaml`, and `*.yml` files. Budget roughly 100KB total across all of them:

- Under budget: read them all.
- Over budget: list what you found with sizes, and ask which matter. Do not
  read the largest few and quietly proceed — the file you skipped is exactly
  where the constraint that invalidates the recommendation tends to live.
- Nested directories: mention them, do not descend unless the user says to.

Skip `.git`, `node_modules`, and other dependency or VCS directories.

## Deriving the research question

When free text is supplied, that is the question. Use it.

When only paths are supplied, derive a candidate and confirm it. Prior work
usually states its own open question — look for a section named something
like "Open Question", "Carried Forward", "Next Phase", "Decision Required",
or "Out of Scope for This Document". Those sections exist precisely because
the author hit the boundary of what they could settle, which is the boundary
this skill is built to push on.

If the input files contain a requirements list and a candidate list but no
stated open question, the implied question is almost always *which candidate
best satisfies those requirements, and does the front-runner actually hold
up*. Propose that.

## Deriving the artifact path

| Input shape | Artifact path |
|---|---|
| A directory was given | `<dir>/RESEARCH-<slug>.md` |
| Only files were given | `<parent of first file>/RESEARCH-<slug>.md` |
| Free text only | `docs/_working/<slug>/RESEARCH-<slug>.md` |

Writing the artifact next to the prior work it critiques is deliberate: the
problem statement, the options survey, and the adversarial read on them
belong in one place, and a reader who finds one finds all three.

If the derived directory does not exist, create it. If the user gave an
explicit destination in their invocation, that always wins.

### Slug generation

1. Lowercase
2. Spaces to hyphens
3. Strip everything that is not alphanumeric or a hyphen
4. Collapse repeated hyphens
5. Trim leading and trailing hyphens
6. Truncate to roughly 60 characters at a hyphen boundary

Derive the slug from the *topic*, not the full sentence. "Which of the four
viable ArgoCD generator options best fits development environments?" becomes
`argocd-dev-environment-generators`, not a 70-character transcription of the
sentence.

| Topic | Slug |
|---|---|
| ArgoCD dev environment generators | `argocd-dev-environment-generators` |
| SQLite to Postgres migration | `sqlite-to-postgres-migration` |
| React 19 vs Svelte 5 | `react-19-vs-svelte-5` |

## Existing-artifact detection

Free-text slugs drift with rewording, so path derivation alone is not a
reliable identity check. Before assuming new-research mode:

1. Check the exact derived `artifact_path`.
2. For directory or file inputs, also glob `RESEARCH-*.md` in the target
   directory.

If nothing matches, proceed as new research. If exactly one matches and its
`## Question` covers the same ground, offer follow-up mode. If several match,
or the match is ambiguous, ask — list the candidates by filename and their
`## Question` line so the user can pick without opening files.
