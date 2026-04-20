# Redaction patterns

> Centralised list of secret-pattern regexes for the `architecture-doc`
> skill. Read by `SKILL.md` Step 4.9 (post-scan redaction over
> `findings.md`) and by `SKILL.md` Steps 6 and 7 when implemented
> (post-synthesis redaction over the produced
> `docs/ARCHITECTURE_AND_DESIGN.md`). Per Decision #8
> (read-but-redact), the patterns below are the **second** line of
> defence; the scan sub-agent's own discipline of writing names not
> values is the **first**.

## How redaction is applied

The orchestrator reads the target file, applies each pattern in order,
replaces every match with the literal string `[REDACTED]`, and writes
the result back. The implementation may use Bash with `perl -pi` /
`sed -E`, or it may be performed entirely in orchestrator context with
`Read` + `Edit` / `Write`. Either is acceptable; the patterns below are
specified in PCRE syntax to be unambiguous.

The orchestrator MUST count the number of replacements made (across all
patterns) and write a summary line to `run.log`:

```
2026-04-10T14:25:01Z INFO scan redacted findings.md hits=<total>
```

If `<total>` is greater than zero, an additional warning line MUST be
written naming the patterns that matched:

```
2026-04-10T14:25:01Z WARN scan redaction findings.md patterns=<comma-separated names of matched patterns>
```

so post-mortem inspection can identify what category of secret the
scan agent attempted to write. The same convention applies to the
post-synthesis redaction pass over the produced architecture document
(Steps 6 and 7), substituting the file name in the log lines.

## Pattern list

Each row below is a stable name + a PCRE regex. Names are the
identifiers used in the `run.log` warning line above.

| Name | Regex (PCRE) | Notes |
|------|--------------|-------|
| `aws_access_key_id` | `AKIA[0-9A-Z]{16}` | AWS access key ID prefix. |
| `aws_secret_access_key` | `(?i)aws(.{0,20})?(secret\|private)(.{0,20})?['"=:\s]+[A-Za-z0-9/+=]{40}` | 40-char AWS secret following an `aws...secret` cue. |
| `github_token` | `gh[pousr]_[A-Za-z0-9]{36,}` | GitHub PAT / OAuth / refresh / user / server tokens. |
| `slack_token` | `xox[abprs]-[A-Za-z0-9-]{10,}` | Slack tokens. |
| `private_key_pem` | `-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----` | PEM-encoded private keys (any algorithm). |
| `pkcs8_encrypted` | `-----BEGIN ENCRYPTED PRIVATE KEY-----[\s\S]*?-----END ENCRYPTED PRIVATE KEY-----` | Encrypted PKCS#8 keys. |
| `jwt` | `eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}` | JSON Web Tokens. |
| `generic_bearer` | `(?i)bearer\s+[A-Za-z0-9._\-]{20,}` | `Authorization: Bearer ...` style. |
| `generic_password_assignment` | `(?i)(password\|passwd\|secret\|token\|api[_-]?key)\s*[=:]\s*['"][^'"]{6,}['"]` | Quoted secret-looking assignments. Conservative -- redacts the value, leaves the key visible. |
| `db_connection_string` | `(?i)(postgres\|mysql\|mongodb\|redis)(\+srv)?://[^:\s]+:[^@\s]+@[^\s'"]+` | Connection strings with embedded credentials. |
| `aws_access_key_id_b64` | `QUtJQVtBLVowLTld` | Base64-encoded AWS access key ID prefix (`AKIA[A-Z0-9]` → `QUtJQV...`). Partial match; redacts entire base64 block on hit. |
| `k8s_secret_data` | `(?i)kind:\s*Secret[\s\S]{0,200}data:[\s\S]{0,500}?[A-Za-z0-9+/]{20,}={0,2}` | Kubernetes Secret manifests with base64-encoded `data:` fields. Conservative multi-line match. |

## Application order

Apply patterns in the order listed in the table above. Order matters
for the few cases where one pattern's match would otherwise overlap
another (e.g. a JWT inside a `Bearer` header would be caught by
`generic_bearer` if processed first). The orchestrator MUST NOT reorder
the patterns; if a new pattern is added, it should be added at the end
of the table.

## Known limitations

Regex-based redaction is not airtight (Decision #8 tradeoff). The
patterns above target the **common** shapes of widely-used secrets;
non-standard formats can slip through. The first line of defence
remains the scan sub-agent prompt's instruction to write **names**, not
**values**.

**Base64 encoding:** Secrets encoded as base64 (common in Kubernetes
Secret manifests, CI/CD configs, etc.) are partially addressed by the
`aws_access_key_id_b64` and `k8s_secret_data` patterns. However,
base64 encoding can obscure many secret formats. The `k8s_secret_data`
pattern conservatively matches entire Kubernetes Secret manifests with
`data:` fields to err on the side of redaction. For other base64
contexts, the scan agent's primary obligation to never write secret
values remains the main defence.

If a new secret format becomes common in scanned codebases, add a row
to the table above. The orchestrator reads this file fresh on every run
-- there is no caching layer to invalidate.
