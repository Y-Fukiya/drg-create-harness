rg_section_spec_path <- function(guide_type) {
  file <- system.file("section_specs", paste0(guide_type, ".yml"), package = "reviewerguideR")
  if (!nzchar(file)) {
    file <- fs::path("inst", "section_specs", paste0(guide_type, ".yml"))
  }
  if (!fs::file_exists(file)) {
    stop(sprintf("Section spec was not found for guide_type = '%s'.", guide_type), call. = FALSE)
  }
  file
}

rg_read_section_spec <- function(guide_type) {
  spec <- yaml::read_yaml(rg_section_spec_path(guide_type))
  sections <- spec$sections
  tibble::tibble(
    section_id = vapply(sections, `[[`, character(1), "section_id"),
    title = vapply(sections, `[[`, character(1), "title"),
    required = vapply(sections, `[[`, logical(1), "required"),
    output_type = vapply(sections, `[[`, character(1), "output_type"),
    source_tables = I(lapply(sections, function(x) x$source_tables %||% character()))
  )
}
