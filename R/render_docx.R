rg_render_docx <- function(project_path,
                           guide_type = c("adrg", "csdrg"),
                           template = NULL,
                           output = NULL,
                           rmd = NULL,
                           reference_docx = NULL,
                           engine = NULL) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  config <- rg_read_config(project_path)
  draft <- rg_read_draft(project_path, guide_type)
  if (is.null(draft)) {
    stop("Draft JSON was not found. Run rg_draft_guide() first.", call. = FALSE)
  }
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)

  engine <- tolower(engine %||% rg_config_value(config, c("render", "engine"), default = "officedown"))
  rmd <- rg_render_path(
    project_path,
    rmd %||%
      rg_config_value(config, c("guides", guide_type, "rmd"), default = NULL) %||%
      rg_config_value(config, c("render", "rmd"), default = "templates/reviewers-guide.Rmd")
  )
  reference_docx <- rg_render_path(
    project_path,
    reference_docx %||%
      template %||%
      rg_config_value(config, c("guides", guide_type, "reference_docx"), default = NULL) %||%
      rg_config_value(config, c("render", "reference_docx"), default = NULL) %||%
      rg_config_value(config, c("guides", guide_type, "template"), default = NULL) %||%
      "templates/word/base.docx"
  )
  output <- rg_render_path(
    project_path,
    output %||% rg_config_value(config, c("guides", guide_type, "output"), default = paste0("output/", guide_type, "_draft.docx"))
  )

  rg_ensure_default_render_assets(project_path, rmd, reference_docx)
  qc_summary <- rg_render_qc_summary(project_path, guide_type)

  if (identical(engine, "officer")) {
    return(rg_render_docx_officer(project_path, guide_type, draft, data, reference_docx, output, qc_summary))
  }
  if (!identical(engine, "officedown")) {
    stop("-- render engine must be 'officedown' or 'officer'.", call. = FALSE)
  }
  if (!rg_can_render_officedown()) {
    warning("officedown/rmarkdown/Pandoc is not available; falling back to officer DOCX rendering.", call. = FALSE)
    return(rg_render_docx_officer(project_path, guide_type, draft, data, reference_docx, output, qc_summary))
  }

  rg_render_docx_officedown(project_path, guide_type, draft, data, rmd, reference_docx, output, qc_summary)
}

rg_render_path <- function(project_path, path) {
  path <- as.character(path)[[1]]
  if (grepl("^([A-Za-z]:)?[\\/]", path) || startsWith(path, "\\\\")) {
    return(fs::path_norm(path))
  }
  fs::path(project_path, path)
}

rg_ensure_default_render_assets <- function(project_path, rmd, reference_docx) {
  default_rmd <- fs::path(project_path, "templates", "reviewers-guide.Rmd")
  default_reference_docx <- fs::path(project_path, "templates", "word", "base.docx")
  if (identical(rg_norm_path(rmd), rg_norm_path(default_rmd))) {
    rg_write_default_rmd_template(default_rmd)
  }
  if (identical(rg_norm_path(reference_docx), rg_norm_path(default_reference_docx))) {
    rg_write_default_reference_docx(default_reference_docx)
  }
  invisible(project_path)
}

rg_can_render_officedown <- function() {
  requireNamespace("officedown", quietly = TRUE) &&
    is.function(officedown::rdocx_document) &&
    requireNamespace("rmarkdown", quietly = TRUE) &&
    isTRUE(rmarkdown::pandoc_available())
}

rg_guide_title <- function(guide_type) {
  if (identical(guide_type, "adrg")) {
    "Analysis Data Reviewer's Guide Draft"
  } else {
    "Study Data Reviewer's Guide Draft"
  }
}

rg_render_context <- function(guide_type, draft, data, qc_summary) {
  list(
    guide_type = guide_type,
    title = rg_guide_title(guide_type),
    study_id = draft$study_id %||% NA_character_,
    generated_on = format(Sys.Date(), "%Y-%m-%d"),
    draft = draft,
    data = data,
    qc_summary = qc_summary
  )
}

rg_render_qc_summary <- function(project_path, guide_type) {
  qc_summary <- rg_read_csv_if_exists(
    fs::path(project_path, "work", "qc", paste0(guide_type, "_qc_summary.csv")),
    rg_qc_summary_columns()
  )
  if (nrow(qc_summary) > 0) {
    return(qc_summary)
  }
  qc_report_path <- fs::path(project_path, "work", "qc", paste0(guide_type, "_qc_report.csv"))
  if (!fs::file_exists(qc_report_path)) {
    qc_report_path <- fs::path(project_path, "work", "qc", "qc_report.csv")
  }
  if (!fs::file_exists(qc_report_path)) {
    return(qc_summary)
  }
  qc_report <- rg_read_csv_if_exists(qc_report_path)
  rg_qc_summary(project_path, guide_type = guide_type, qc = qc_report, write = FALSE)
}

rg_render_docx_officedown <- function(project_path, guide_type, draft, data, rmd, reference_docx, output, qc_summary) {
  if (!fs::file_exists(rmd)) {
    stop("R Markdown DOCX template was not found: ", rmd, call. = FALSE)
  }

  fs::dir_create(fs::path_dir(output))
  env <- new.env(parent = globalenv())
  env$rg_render_context <- rg_render_context(guide_type, draft, data, qc_summary)
  env$rg_compact_table <- rg_compact_table
  env$rg_flextable <- rg_flextable

  output_options <- list()
  if (fs::file_exists(reference_docx)) {
    output_options$reference_docx <- reference_docx
  } else {
    warning("Reference DOCX was not found; using the Rmd template default: ", reference_docx, call. = FALSE)
  }

  rmarkdown::render(
    input = rmd,
    output_file = fs::path_file(output),
    output_dir = fs::path_dir(output),
    output_options = output_options,
    quiet = TRUE,
    envir = env
  )
  invisible(output)
}

rg_render_docx_officer <- function(project_path, guide_type, draft, data, reference_docx, output, qc_summary) {
  doc <- if (!is.null(reference_docx) && fs::file_exists(reference_docx)) {
    officer::read_docx(path = reference_docx)
  } else {
    officer::read_docx()
  }

  doc <- officer::body_add_par(doc, rg_guide_title(guide_type), style = "heading 1")
  doc <- officer::body_add_par(doc, paste("Study:", draft$study_id %||% NA_character_), style = "Normal")
  doc <- officer::body_add_par(doc, paste("Generated by reviewerguideR officer fallback on", format(Sys.Date(), "%Y-%m-%d")), style = "Normal")

  for (section in draft$sections) {
    doc <- officer::body_add_par(doc, section$section_title, style = "heading 2")
    paragraphs <- rg_markdown_to_paragraphs(section$draft_markdown)
    if (length(paragraphs) == 0) paragraphs <- ""
    for (paragraph in paragraphs) {
      doc <- officer::body_add_par(doc, paragraph, style = "Normal")
    }
    if (grepl("dataset_inventory$", section$section_id)) {
      tbl <- rg_compact_table(
        data$define_datasets,
        c("dataset_name", "dataset_label", "structure", "purpose", "class")
      )
      doc <- flextable::body_add_flextable(doc, rg_flextable(tbl))
    }
    if (grepl("conformance_findings$", section$section_id)) {
      tbl <- rg_compact_table(
        data$validation_findings,
        c("rule_id", "severity", "dataset_name", "variable_name", "message", "count", "status")
      )
      doc <- flextable::body_add_flextable(doc, rg_flextable(tbl))
    }
  }

  if (nrow(data$define_valuelevel) > 0) {
    doc <- officer::body_add_par(doc, "Value-Level Metadata", style = "heading 2")
    valuelevel_tbl <- rg_compact_table(
      data$define_valuelevel,
      c(
        "value_list_oid", "where_clause_oid", "dataset_name", "variable_name",
        "where_variable_name", "comparator", "check_value", "mandatory"
      )
    )
    doc <- flextable::body_add_flextable(doc, rg_flextable(valuelevel_tbl))
  }

  if (nrow(qc_summary) > 0) {
    doc <- officer::body_add_par(doc, "QC Summary", style = "heading 2")
    qc_tbl <- rg_compact_table(
      qc_summary,
      c(
        "guide_type", "summary_status", "total_rows", "fail_rows",
        "warning_fail_rows", "error_fail_rows", "review_required_rows",
        "manifest_drift_rows"
      )
    )
    doc <- flextable::body_add_flextable(doc, rg_flextable(qc_tbl))
  }

  fs::dir_create(fs::path_dir(output))
  print(doc, target = output)
  invisible(output)
}
