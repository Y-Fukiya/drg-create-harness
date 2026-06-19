# reviewerguideR 0.1.1

Released: 2026-06-19

## Highlights

- Switched DOCX rendering to an R Markdown + officedown workflow.
- Added `templates/reviewers-guide.Rmd` as the editable document source for
  harness projects.
- Added `templates/word/base.docx` as the single Word style base for generated
  reviewer guide drafts.
- Kept the officer/flextable direct renderer as an explicit fallback with
  `rg_render_docx(..., engine = "officer")`.
- Added validation coverage proving that custom Rmd sources are reflected in
  generated DOCX output.

## Quality

- Confirmed GitHub Actions R CMD check on Ubuntu and Windows.
- Confirmed local anonymous ADRG/cSDRG demo generation with QC pass.
- Tightened `.Rbuildignore` so local check/build artifacts and macOS metadata do
  not enter source package builds.

# reviewerguideR 0.1.0

Initial public MVP release.

- Generated ADRG and cSDRG draft DOCX files from define.xml and validation
  finding CSV/XLSX metadata.
- Added evidence tables, source manifests, QC reports, and QC summaries.
- Added deterministic dry-run drafting and guarded stubs for future LLM, RAG,
  GraphRAG, and integrated guide workflows.
