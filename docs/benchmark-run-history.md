# Skill Benchmark Run History

Each row represents one `bash scripts/run-benchmark.sh` run. Scores are out of 63 (7 dimensions × 3 inputs × max 3 points each, from 2026-03-08; prior runs used 6 dimensions, max 54).

| Run timestamp | Label | Champion | Challenger | Champion score | Challenger score | Verdict |
|---------------|-------|----------|------------|----------------|------------------|---------|
| 20260307T002147Z | initial | occ-skill-creator | skill-creator (Anthropic plugin) | 52/54 | 53/54 | NO CHANGE |
| 20260308-181817 | tc2-bad-baseline | baseline (no skill) | bad-skill | 51/54 | 54/54 | PROMOTE |
| 20260308-182937 | tc3-good-baseline | baseline (no skill) | occ-skill-creator | 53/54 | 53/54 | NO VALUE |
| 20260308-184050 | tc4-champ-vs-bad | occ-skill-creator | bad-skill | 53/54 | 54/54 | NO CHANGE |
| 20260308-211457 | test-anti-quality-baseline | baseline (no skill) | anti-quality | 49/54 | 26/54 | REJECT |
| 20260308-220524 | bad-skill-champion-validation | occ-skill-creator | bad-skill | 58/63 | 52/63 | CHAMPION CONFIRMED |
| 20260308-220509 | bad-skill-baseline-validation | baseline (no skill) | bad-skill | 47/63 | 52/63 | PROMOTE |
| 20260308-231015 | occ-creator-baseline-v3 | baseline (no skill) | occ-skill-creator | 46/63 | 57/63 | PROMOTE |
| 20260308-231011 | occ-creator-baseline-v2 | baseline (no skill) | occ-skill-creator | 51/63 | 58/63 | PROMOTE |
| 20260308-231006 | occ-creator-baseline-v1 | baseline (no skill) | occ-skill-creator | 51/63 | 60/63 | PROMOTE |
| 20260309-143146 | occ-skill-refactor-baseline__var1 | baseline (no skill) | occ-skill-refactor | 45/63 | 55/63 | PROMOTE |
| 20260309-145027 | occ-skill-refactor-baseline__var2 | baseline (no skill) | occ-skill-refactor | 52/63 | 57/63 | PROMOTE |
| 20260309-150630 | occ-skill-refactor-baseline__var3 | baseline (no skill) | occ-skill-refactor | 50/63 | 52/63 | NO VALUE |
