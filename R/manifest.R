rg_source_type <- function(path) {
  file <- tolower(fs::path_file(path))
  ext <- tolower(fs::path_ext(path))
  no_ext <- tools::file_path_sans_ext(file)

  if (identical(file, "define.xml")) {
    return("define")
  }
  if (identical(ext, "xpt")) {
    return("dataset")
  }
  if (ext %in% c("csv", "xlsx") && grepl("validation|p21|pinnacle|conformance|finding", file)) {
    return("validation")
  }
  if (ext %in% c("sas", "r")) {
    return("program")
  }
  if (ext %in% c("pdf", "doc", "docx", "txt", "md")) {
    if (grepl("protocol", no_ext)) return("protocol")
    if (grepl("(^|[^a-z])sap([^a-z]|$)|statistical.analysis.plan", no_ext)) return("sap")
    if (grepl("csr|clinical.study.report", no_ext)) return("csr")
    if (grepl("acrf|annotated.crf|annotated.case.report", no_ext)) return("acrf")
    if (grepl("spec", no_ext)) return("spec")
  }
  if (grepl("validation|p21|pinnacle|conformance|finding", file) && ext %in% c("csv", "xlsx")) {
    return("validation")
  }
  "other"
}

rg_guide_scope <- function(source_type, data_class) {
  if (source_type %in% c("protocol", "sap", "csr", "acrf", "other", "program")) {
    return("both")
  }
  if (identical(data_class, "adam")) return("adrg")
  if (identical(data_class, "sdtm")) return("csdrg")
  "unknown"
}

rg_is_dataset_like_source <- function(path, source_type, data_class) {
  ext <- tolower(fs::path_ext(as.character(path %||% "")))
  source_type <- as.character(source_type %||% "")
  data_class <- as.character(data_class %||% "")

  if (identical(source_type, "dataset")) {
    return(TRUE)
  }
  if (ext %in% c("xpt", "sas7bdat", "parquet", "rds")) {
    return(TRUE)
  }
  if (!identical(source_type, "validation") && ext %in% c("csv", "xlsx") && data_class %in% c("adam", "sdtm")) {
    return(TRUE)
  }
  FALSE
}

rg_manifest_dataset_like <- function(manifest) {
  if (nrow(manifest) == 0) {
    return(logical())
  }
  col_or_na <- function(name) {
    if (name %in% names(manifest)) manifest[[name]] else rep(NA_character_, nrow(manifest))
  }
  mapply(
    rg_is_dataset_like_source,
    col_or_na("file_path"),
    col_or_na("source_type"),
    col_or_na("data_class"),
    USE.NAMES = FALSE
  )
}

rg_scan_sources <- function(project_path, write = TRUE) {
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)
  source_root <- fs::path(project_path, "source")

  if (!fs::dir_exists(source_root)) {
    stop("source/ was not found. Run rg_init_project() first.", call. = FALSE)
  }

  external_annotations <- rg_external_manifest_annotations(project_path)
  files <- fs::dir_ls(source_root, recurse = TRUE, type = "file", fail = FALSE)
  if (length(files) == 0) {
    manifest <- rg_empty_manifest()
  } else {
    rows <- lapply(seq_along(files), function(i) {
      path <- rg_norm_path(files[[i]])
      source_type <- rg_source_type(path)
      data_class <- rg_infer_data_class(path, "auto")
      dataset_like <- rg_is_dataset_like_source(path, source_type, data_class)
      hash <- digest::digest(file = path, algo = "sha256")
      doc_id <- paste0("DOC-", substr(digest::digest(path, algo = "xxhash64"), 1, 12))
      external <- rg_external_annotation_for_path(path, external_annotations)
      tibble::tibble(
        doc_id = doc_id,
        study_id = study_id,
        file_path = path,
        file_name = fs::path_file(path),
        file_ext = tolower(fs::path_ext(path)),
        source_type = source_type,
        data_class = data_class,
        guide_scope = rg_guide_scope(source_type, data_class),
        file_hash = hash,
        modified_time = as.character(fs::file_info(path)$modification_time),
        include_in_llm = !dataset_like,
        include_in_rag = !dataset_like,
        status = "active",
        notes = if (dataset_like) "Excluded from LLM/RAG paths by policy." else NA_character_,
        external_origin = external$external_origin,
        upstream_url = external$upstream_url,
        upstream_commit = external$upstream_commit,
        attribution = external$attribution,
        disclaimer_source = external$disclaimer_source
      )
    })
    manifest <- dplyr::bind_rows(rows)
    manifest <- dplyr::select(manifest, dplyr::all_of(rg_manifest_columns()))
  }

  if (write) {
    out <- fs::path(project_path, "work", "manifest.json")
    fs::dir_create(fs::path_dir(out))
    jsonlite::write_json(manifest, out, dataframe = "rows", pretty = TRUE, auto_unbox = TRUE, na = "null")
  }
  manifest
}
