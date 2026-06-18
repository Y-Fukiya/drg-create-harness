# Reviewer Guide Draft Harness

This repository is a local harness for creating draft ADRG and cSDRG reviewer
guides from structured metadata, especially `define.xml` and validation finding
CSV/XLSX files.

The R package code is the engine. Most users should use the harness commands:
put study inputs under a project `source/` directory, run one command, and
review the generated DOCX drafts and QC artifacts.

Generated documents are evidence-bound drafts. They are not submission-ready
reviewer guides without human review.

## What It Produces

A harness run creates:

- `output/adrg_draft.docx`
- `output/csdrg_draft.docx`
- `output/harness_summary.json`
- `work/manifest.json`
- extracted metadata CSV files under `work/extracted/`
- evidence rows under `work/evidence/`
- QC rows under `work/qc/qc_report.csv`

## Safety First

This repository contains only synthetic and anonymous fixtures under
`inst/extdata/`. Do not commit real study data, subject-level datasets, sponsor
documents, protocol PDFs, SAPs, CSRs, aCRFs, API keys, or generated study
projects. Local `studies/` and `.harness/` directories are ignored by git and by
R package builds for that reason.

## Prerequisites

- R 4.1 or later
- Git, if you want to clone the repository
- Optional: GNU Make on macOS/Linux for the `make ...` shortcuts
- Optional: `readxl` for richer XLSX validation finding imports

Install required R packages from the repository root:

```r
install.packages(c(
  "cli", "digest", "dplyr", "flextable", "fs", "glue", "jsonlite",
  "officer", "purrr", "stringr", "tibble", "tidyr", "xml2", "yaml"
))
```

## Quick Start: macOS

Clone and enter the repository:

```bash
git clone https://github.com/Y-Fukiya/drg-create-harness.git
cd drg-create-harness
```

Run the bundled anonymous example:

```bash
make run-example PROJECT=.harness/rg-demo EXAMPLE=anonymous
```

Create your own study project:

```bash
make init PROJECT=studies/ABC-001 STUDY_ID=ABC-001
```

Copy your `define.xml` and validation CSV/XLSX files into
`studies/ABC-001/source/`, then run:

```bash
make run PROJECT=studies/ABC-001 GUIDE=both
```

If `make` is not available, use R directly:

```bash
Rscript scripts/run_harness.R --project studies/ABC-001 --study-id ABC-001 --guide both
```

## Quick Start: Windows PowerShell

Clone and enter the repository:

```powershell
git clone https://github.com/Y-Fukiya/drg-create-harness.git
cd drg-create-harness
```

Run the bundled anonymous example:

```powershell
.\scripts\run_harness.ps1 -Project .\.harness\rg-demo -CopyExample anonymous
```

Create your own study project:

```powershell
.\scripts\run_harness.ps1 -Project .\studies\ABC-001 -StudyId ABC-001 -Init -NoRun
```

Copy your `define.xml` and validation CSV/XLSX files into
`.\studies\ABC-001\source\`, then run:

```powershell
.\scripts\run_harness.ps1 -Project .\studies\ABC-001 -Guide both
```

## Quick Start: Windows Command Prompt

```bat
git clone https://github.com/Y-Fukiya/drg-create-harness.git
cd drg-create-harness
scripts\run_harness.cmd --project .harness\rg-demo --copy-example anonymous
scripts\run_harness.cmd --project studies\ABC-001 --study-id ABC-001 --guide both
```

## Expected Input Layout

For both macOS and Windows, a study project should look like this:

```text
studies/ABC-001/
  source/
    analysis/
      define.xml
      validation/
        adam_validation.csv
    tabulation/
      define.xml
      validation/
        sdtm_validation.csv
```

CSV is the safest validation finding format for the MVP. XLSX is supported with
`readxl` when installed; otherwise the built-in fallback handles only simple
single-sheet workbooks.

## Expected Output Layout

```text
studies/ABC-001/
  output/
    adrg_draft.docx
    csdrg_draft.docx
    harness_summary.json
  work/
    manifest.json
    extracted/
    evidence/
    qc/
```

See `harness/README.md` for the full directory contract and CLI options.

See `docs/release-checklist.md` for the local release checks and
`docs/post-mvp-roadmap.md` for the deferred ellmer, ragnar, iADRG/icSDRG,
GraphRAG, Tauri, and shinylive direction. See `docs/github-publish.md` before
publishing the repository to GitHub.

## Direct R Engine Example

For direct package-level use:

```r
library(reviewerguideR)

proj <- tempfile("study-")
rg_init_project(proj, study_id = "TEST-001")

# User copies define.xml and validation CSV/XLSX into source folders.
rg_scan_sources(proj)
rg_extract_metadata(proj)
rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
rg_qc(proj, guide_type = "adrg")
rg_render_docx(proj, guide_type = "adrg")
```

## Scope

This MVP supports single-study ADRG/cSDRG draft generation, basic `define.xml`
metadata extraction, validation finding CSV/XLSX import, evidence table
generation, QC reporting, and DOCX output through `officer` and `flextable`.
For XLSX validation imports, `readxl` is used when installed; otherwise the
package falls back to a minimal built-in reader for simple first-sheet workbooks.
The fallback intentionally does not support multi-sheet workbooks, merged cells,
formula cells, or complex type inference. Install `readxl` or export validation
findings as flat CSV when those features are needed.
Sheet selection is intentionally not exposed in the MVP; XLSX imports read the
first sheet only.

The basic `define.xml` parser detects `ValueListDef` and `WhereClauseDef`
metadata but does not expand them in the MVP. When those constructs are present,
QC reports them as `severity = "warning"` and `status = "fail"` so document
generation can continue while human reviewers still see the gap. The same gap is
also summarized in the draft guide's unresolved items section, whose
`evidence_ids` are limited to the unresolved items mentioned in that section
when gaps are present. If no gap is detected, the section carries source
metadata evidence supporting that no-gap statement.

QC output is intentionally row-oriented in the MVP. It does not add an overall
status column yet; a separate summary helper can be added later when CI or
release gating needs are clearer.

`rg_extract_metadata()` uses the existing `work/manifest.json` when present and
does not automatically rescan source files. If no manifest exists yet, it runs
an initial `rg_scan_sources()` for convenience. This keeps first use simple
while making later extraction runs reproducible. Run `rg_scan_sources()` again
when the source file set should intentionally change; stale file hashes are
surfaced by QC warnings.

`rg_draft_guide()` follows the same pattern for extracted metadata. If extracted
CSV files are missing, it runs `rg_extract_metadata()` for first-use convenience.
If extracted CSV files already exist, it drafts from those files and does not
re-extract automatically.

`rg_render_docx()` intentionally continues even when QC rows have
`status = "fail"`. The package prioritizes producing a reviewable draft; QC
issues remain visible in `work/qc/qc_report.csv` and in the unresolved items
section where applicable.
DOCX output does not include a QC summary table in the MVP; QC remains a
separate CSV artifact.

Human review is required. The generated documents are drafts and are not
submission-ready reviewer guides.

Subject-level data is not sent to LLM paths. XPT and dataset-like files are
excluded from LLM and RAG eligibility by the source scanner.

GraphRAG, iADRG/icSDRG, Tauri, shinylive production packaging, and PDF
conversion are future work. Stable stubs are included for those extension
points. shinylive is reserved for demos or UI prototypes rather than production
processing. If the workflow becomes an app, the intended direction is Tauri with
a local R sidecar; heavier `officer`, `flextable`, `ellmer`, and `ragnar` work
should stay in that local R process.

## CI

The repository includes a GitHub Actions workflow at
`.github/workflows/R-CMD-check.yaml` that runs R CMD check on pushes and pull
requests to `master` or `main` on Ubuntu and Windows.
