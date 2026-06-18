# Synthetic end-to-end example for reviewerguideR.
#
# This script creates a temporary project, copies the package's synthetic
# define.xml and validation CSV fixtures, and generates an ADRG draft DOCX.

run_synthetic_e2e <- function(project_path = tempfile("reviewerguideR-e2e-")) {
  if (dir.exists(project_path)) {
    stop("project_path already exists: ", project_path, call. = FALSE)
  }

  source_root <- system.file(
    "extdata", "synthetic_study", "source",
    package = "reviewerguideR"
  )
  if (!nzchar(source_root)) {
    source_root <- file.path("inst", "extdata", "synthetic_study", "source")
  }
  if (!dir.exists(source_root)) {
    stop("Synthetic source fixture was not found.", call. = FALSE)
  }

  reviewerguideR::rg_init_project(project_path, study_id = "SYN-E2E-001")

  copied <- file.copy(
    list.files(source_root, full.names = TRUE, all.files = FALSE),
    file.path(project_path, "source"),
    recursive = TRUE,
    overwrite = TRUE
  )
  if (!all(copied)) {
    stop("Failed to copy one or more synthetic source fixture paths.", call. = FALSE)
  }

  manifest <- reviewerguideR::rg_scan_sources(project_path)
  extracted <- reviewerguideR::rg_extract_metadata(project_path)
  draft <- reviewerguideR::rg_draft_guide(
    project_path,
    guide_type = "adrg",
    mode = "dry_run"
  )
  qc <- reviewerguideR::rg_qc(project_path, guide_type = "adrg")
  docx <- reviewerguideR::rg_render_docx(project_path, guide_type = "adrg")

  list(
    project_path = project_path,
    docx = docx,
    manifest_rows = nrow(manifest),
    dataset_rows = nrow(extracted$define_datasets),
    validation_finding_rows = nrow(extracted$validation_findings),
    draft_sections = length(draft$sections),
    qc_fail_rows = sum(qc$status == "fail"),
    qc_path = file.path(project_path, "work", "qc", "qc_report.csv")
  )
}

result <- run_synthetic_e2e()
if (interactive()) {
  print(result)
}
