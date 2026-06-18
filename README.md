# reviewerguideR

`reviewerguideR` is an MVP R package for creating basic ADRG and cSDRG draft
reviewer guides from structured metadata, especially `define.xml` and
validation finding CSV/XLSX files.

The package creates evidence-bound drafts and DOCX output. It is not intended to
produce submission-ready reviewer guides without human review.

## Minimal example

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

For a runnable package-bundled example with synthetic fixtures:

```r
source(system.file("examples", "synthetic-e2e.R", package = "reviewerguideR"))
result$docx
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
