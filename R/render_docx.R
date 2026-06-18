rg_render_docx <- function(project_path, guide_type = c("adrg", "csdrg"), template = NULL, output = NULL) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  config <- rg_read_config(project_path)
  draft <- rg_read_draft(project_path, guide_type)
  if (is.null(draft)) {
    stop("Draft JSON was not found. Run rg_draft_guide() first.", call. = FALSE)
  }
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)

  template <- template %||% fs::path(project_path, rg_config_value(config, c("guides", guide_type, "template"), default = paste0("templates/", guide_type, "_template.docx")))
  output <- output %||% fs::path(project_path, rg_config_value(config, c("guides", guide_type, "output"), default = paste0("output/", guide_type, "_draft.docx")))

  doc <- if (!is.null(template) && fs::file_exists(template)) {
    officer::read_docx(path = template)
  } else {
    officer::read_docx()
  }

  title <- if (identical(guide_type, "adrg")) "Analysis Data Reviewer's Guide Draft" else "Study Data Reviewer's Guide Draft"
  doc <- officer::body_add_par(doc, title, style = "heading 1")
  doc <- officer::body_add_par(doc, paste("Study:", draft$study_id %||% NA_character_), style = "Normal")

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
      doc <- flextable::body_add_flextable(doc, flextable::autofit(flextable::flextable(tbl)))
    }
    if (grepl("conformance_findings$", section$section_id)) {
      tbl <- rg_compact_table(
        data$validation_findings,
        c("rule_id", "severity", "dataset_name", "variable_name", "message", "count", "status")
      )
      doc <- flextable::body_add_flextable(doc, flextable::autofit(flextable::flextable(tbl)))
    }
  }

  fs::dir_create(fs::path_dir(output))
  print(doc, target = output)
  invisible(output)
}
