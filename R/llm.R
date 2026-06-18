rg_draft_section_ellmer <- function(project_path, guide_type, section_id, chat = NULL) {
  project_path <- rg_norm_path(project_path)
  config <- rg_read_config(project_path)
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("ellmer is not installed. Install ellmer to use mode = 'ellmer'.", call. = FALSE)
  }
  if (!isTRUE(rg_config_value(config, c("llm", "enabled"), default = FALSE))) {
    stop("LLM drafting is disabled in config.yml (llm.enabled is false).", call. = FALSE)
  }
  if (!isTRUE(rg_config_value(config, c("llm", "external_llm_allowed"), default = FALSE))) {
    stop("External LLM providers are disabled by config.yml.", call. = FALSE)
  }
  stop("ellmer drafting is an integration point in the MVP and is not implemented yet.", call. = FALSE)
}
