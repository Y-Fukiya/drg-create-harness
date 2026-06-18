# AGENTS.md

Guidance for Codex and other coding agents working in this repository.

## Project Intent

This repository is a local harness for drafting ADRG and cSDRG reviewer guides
from structured metadata such as `define.xml` and validation finding CSV/XLSX
files. The R package code is the engine; the harness entrypoints are the primary
user workflow.

Generated reviewer guides are drafts and always require human review.

## Privacy And Data Rules

- Do not commit real study data, subject-level datasets, sponsor documents,
  protocol PDFs, SAPs, CSRs, aCRFs, proprietary templates, credentials, or API
  keys.
- Only synthetic or anonymous fixtures belong under `inst/extdata/`.
- Keep local study projects under `studies/` or `.harness/`; both are ignored by
  git and R package builds.
- Do not send subject-level data or dataset records to LLM, RAG, or external API
  paths.

## Useful Commands

Run the harness example:

```sh
make run-example PROJECT=.harness/rg-demo EXAMPLE=anonymous
```

Run directly with R:

```sh
Rscript scripts/run_harness.R --project .harness/rg-demo --copy-example anonymous
```

Windows PowerShell:

```powershell
.\scripts\run_harness.ps1 -Project .\.harness\rg-demo -CopyExample anonymous
```

Run tests:

```sh
Rscript -e 'testthat::test_local(reporter = "summary")'
```

Run package checks:

```sh
R CMD build .
_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --no-build-vignettes reviewerguideR_*.tar.gz
```

## Development Notes

- Keep changes small and scoped to the harness or R engine area being touched.
- Prefer deterministic dry-run behavior in tests. Do not require external LLM,
  embedding, or retrieval services in automated tests.
- `ellmer`, `ragnar`, and `readxl` are optional `Suggests`; tests must pass
  without them.
- If changing harness behavior, update `README.md`, `harness/README.md`, and
  CLI tests as needed.
- If changing public R functions, update `NAMESPACE`, Rd docs, and focused
  tests.
- Validate both Unix-style and Windows-style paths when touching file handling.
