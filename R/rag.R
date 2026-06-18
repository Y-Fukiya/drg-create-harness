rg_build_rag_index <- function(project_path, backend = c("none", "ragnar")) {
  backend <- match.arg(backend)
  project_path <- rg_norm_path(project_path)
  if (identical(backend, "none")) {
    return(tibble::tibble(
      backend = "none",
      status = "skipped",
      message = "RAG indexing is disabled for backend = 'none'."
    ))
  }
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    stop("ragnar is not installed. Install ragnar to use backend = 'ragnar'.", call. = FALSE)
  }
  stop("ragnar indexing is an integration point in the MVP and is not implemented yet.", call. = FALSE)
}

rg_retrieve_context <- function(project_path, query, filters = list(), backend = c("none", "mock", "ragnar", "graph", "hybrid"), top_k = 8) {
  backend <- match.arg(backend)
  project_path <- rg_norm_path(project_path)
  if (identical(backend, "none")) {
    return(tibble::tibble(
      context_id = character(),
      source_file = character(),
      text = character(),
      score = numeric(),
      evidence_id = character()
    ))
  }
  if (identical(backend, "mock")) {
    return(tibble::tibble(
      context_id = "mock-1",
      source_file = NA_character_,
      text = paste("Mock context for query:", query),
      score = 1,
      evidence_id = NA_character_
    ) |>
      utils::head(top_k))
  }
  if (backend %in% c("graph", "hybrid")) {
    stop(sprintf("%s retrieval is not implemented yet.", backend), call. = FALSE)
  }
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    stop("ragnar is not installed. Install ragnar to use backend = 'ragnar'.", call. = FALSE)
  }
  stop("ragnar retrieval is an integration point in the MVP and is not implemented yet.", call. = FALSE)
}
