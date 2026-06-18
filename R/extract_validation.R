rg_normalize_col <- function(x) {
  stringr::str_replace_all(stringr::str_to_lower(x), "[^a-z0-9]+", "")
}

rg_pick_col <- function(data, candidates) {
  if (is.null(candidates) || length(candidates) == 0) {
    return(rep(NA, nrow(data)))
  }
  normalized <- rg_normalize_col(names(data))
  candidate_norm <- rg_normalize_col(candidates)
  idx <- match(candidate_norm, normalized, nomatch = 0)
  idx <- idx[idx > 0]
  if (length(idx) == 0) {
    return(rep(NA, nrow(data)))
  }
  data[[idx[[1]]]]
}

rg_column_candidates <- function(x) {
  if (is.null(x)) {
    return(character())
  }
  x <- unlist(x, use.names = FALSE)
  x <- trimws(as.character(x))
  x[nzchar(x)]
}

rg_merge_column_mapping <- function(base, override = NULL) {
  if (is.null(override) || length(override) == 0) {
    return(base)
  }
  for (field in names(override)) {
    candidates <- rg_column_candidates(override[[field]])
    if (length(candidates) == 0) {
      next
    }
    base[[field]] <- unique(c(candidates, rg_column_candidates(base[[field]])))
  }
  base
}

rg_validation_column_mapping <- function(config = NULL, column_mapping = NULL) {
  mapping <- rg_default_validation_column_mapping()
  if (!is.null(config)) {
    mapping <- rg_merge_column_mapping(
      mapping,
      rg_config_value(config, c("validation", "column_mapping"), default = NULL)
    )
  }
  rg_merge_column_mapping(mapping, column_mapping)
}

rg_xlsx_col_index <- function(ref) {
  letters <- gsub("[0-9]+", "", ref)
  chars <- strsplit(toupper(letters), "", fixed = TRUE)[[1]]
  as.integer(sum((match(chars, LETTERS)) * (26 ^ rev(seq_along(chars) - 1))))
}

rg_read_xlsx_first_sheet <- function(path) {
  tmp <- tempfile("rg-xlsx-")
  fs::dir_create(tmp)
  utils::unzip(path, exdir = tmp)
  workbook_path <- fs::path(tmp, "xl", "workbook.xml")
  if (fs::file_exists(workbook_path)) {
    workbook_doc <- xml2::xml_ns_strip(xml2::read_xml(workbook_path))
    sheet_count <- length(xml2::xml_find_all(workbook_doc, ".//sheets/sheet"))
    if (sheet_count > 1) {
      stop(
        "The built-in XLSX fallback supports only single-sheet workbooks. Install readxl for multi-sheet XLSX handling.",
        call. = FALSE
      )
    }
  }
  sheet_path <- fs::path(tmp, "xl", "worksheets", "sheet1.xml")
  if (!fs::file_exists(sheet_path)) {
    stop("XLSX workbook does not contain xl/worksheets/sheet1.xml.", call. = FALSE)
  }
  shared_strings <- character()
  shared_path <- fs::path(tmp, "xl", "sharedStrings.xml")
  if (fs::file_exists(shared_path)) {
    shared_doc <- xml2::xml_ns_strip(xml2::read_xml(shared_path))
    shared_strings <- vapply(xml2::xml_find_all(shared_doc, ".//si"), xml2::xml_text, character(1))
  }
  sheet_doc <- xml2::xml_ns_strip(xml2::read_xml(sheet_path))
  if (length(xml2::xml_find_all(sheet_doc, ".//mergeCells|.//mergeCell")) > 0) {
    stop(
      "The built-in XLSX fallback does not support merged cells. Install readxl or export validation findings as flat CSV.",
      call. = FALSE
    )
  }
  if (length(xml2::xml_find_all(sheet_doc, ".//f")) > 0) {
    stop(
      "The built-in XLSX fallback does not support formula cells. Install readxl or export validation findings as flat CSV.",
      call. = FALSE
    )
  }
  rows <- xml2::xml_find_all(sheet_doc, ".//sheetData/row")
  if (length(rows) == 0) {
    return(tibble::tibble())
  }
  row_values <- lapply(rows, function(row) {
    cells <- xml2::xml_find_all(row, "./c")
    if (length(cells) == 0) {
      return(character())
    }
    values <- vector("list", length(cells))
    names(values) <- vapply(cells, function(cell) {
      rg_xlsx_col_index(xml2::xml_attr(cell, "r"))
    }, integer(1))
    for (i in seq_along(cells)) {
      cell <- cells[[i]]
      type <- xml2::xml_attr(cell, "t")
      value <- rg_xml_text_first(cell, "./v", NA_character_)
      if (identical(type, "s") && !is.na(value)) {
        value <- shared_strings[as.integer(value) + 1] %||% NA_character_
      } else if (identical(type, "inlineStr")) {
        value <- rg_xml_text_first(cell, ".//is/t", NA_character_)
      }
      values[[i]] <- value
    }
    values
  })
  max_col <- max(vapply(row_values, function(row) {
    if (length(row) == 0) 0L else max(as.integer(names(row)))
  }, integer(1)))
  matrix_values <- matrix(NA_character_, nrow = length(row_values), ncol = max_col)
  for (i in seq_along(row_values)) {
    row <- row_values[[i]]
    if (length(row) > 0) {
      matrix_values[i, as.integer(names(row))] <- unlist(row, use.names = FALSE)
    }
  }
  headers <- matrix_values[1, , drop = TRUE]
  headers[is.na(headers) | !nzchar(headers)] <- paste0("V", which(is.na(headers) | !nzchar(headers)))
  if (nrow(matrix_values) == 1) {
    out <- as.data.frame(matrix(ncol = length(headers), nrow = 0))
  } else {
    out <- as.data.frame(matrix_values[-1, , drop = FALSE], stringsAsFactors = FALSE)
  }
  names(out) <- headers
  tibble::as_tibble(out)
}

rg_read_validation_table <- function(path) {
  ext <- tolower(fs::path_ext(path))
  if (identical(ext, "csv")) {
    return(tibble::as_tibble(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("", "NA"))))
  }
  if (identical(ext, "xlsx")) {
    if (requireNamespace("readxl", quietly = TRUE)) {
      return(tibble::as_tibble(readxl::read_excel(path)))
    }
    return(rg_read_xlsx_first_sheet(path))
  }
  stop("Validation import supports only .csv and .xlsx files in the MVP.", call. = FALSE)
}

rg_extract_validation <- function(path, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"), column_mapping = NULL) {
  data_class <- match.arg(data_class)
  source_file <- rg_norm_path(path)
  if (!fs::file_exists(source_file)) {
    stop(sprintf("Validation file was not found: %s", source_file), call. = FALSE)
  }
  data_class <- rg_infer_data_class(source_file, data_class)
  raw <- rg_read_validation_table(source_file)
  if (nrow(raw) == 0) {
    return(rg_empty_tbl(rg_validation_columns()))
  }
  mapping <- rg_validation_column_mapping(column_mapping = column_mapping)

  out <- tibble::tibble(
    study_id = study_id %||% NA_character_,
    data_class = data_class,
    source_file = source_file,
    tool_name = as.character(rg_pick_col(raw, mapping$tool_name)),
    tool_version = as.character(rg_pick_col(raw, mapping$tool_version)),
    standard = as.character(rg_pick_col(raw, mapping$standard)),
    standard_version = as.character(rg_pick_col(raw, mapping$standard_version)),
    rule_id = as.character(rg_pick_col(raw, mapping$rule_id)),
    severity = as.character(rg_pick_col(raw, mapping$severity)),
    dataset_name = as.character(rg_pick_col(raw, mapping$dataset_name)),
    variable_name = as.character(rg_pick_col(raw, mapping$variable_name)),
    message = as.character(rg_pick_col(raw, mapping$message)),
    count = suppressWarnings(as.integer(rg_pick_col(raw, mapping$count))),
    sponsor_explanation = as.character(rg_pick_col(raw, mapping$sponsor_explanation)),
    status = as.character(rg_pick_col(raw, mapping$status))
  )
  out$evidence_id <- vapply(seq_len(nrow(out)), function(i) {
    locator <- paste(out$rule_id[[i]], out$dataset_name[[i]], out$variable_name[[i]], i, sep = "/")
    rg_make_evidence_id("VAL", source_file, locator, i)
  }, character(1))
  dplyr::select(out, dplyr::all_of(rg_validation_columns()))
}

rg_extract_metadata <- function(project_path, write = TRUE) {
  project_path <- rg_norm_path(project_path)
  config <- rg_read_config(project_path)
  study_id <- rg_project_study_id(project_path)
  manifest <- rg_read_manifest(project_path)
  if (nrow(manifest) == 0) {
    manifest <- rg_scan_sources(project_path, write = TRUE)
  }

  define_results <- lapply(seq_len(nrow(manifest)), function(i) {
    row <- manifest[i, ]
    if (!identical(row$source_type, "define")) {
      return(NULL)
    }
    rg_extract_define(row$file_path, study_id = study_id, data_class = row$data_class)
  })
  define_results <- Filter(Negate(is.null), define_results)

  validation_results <- lapply(seq_len(nrow(manifest)), function(i) {
    row <- manifest[i, ]
    if (!identical(row$source_type, "validation")) {
      return(NULL)
    }
    rg_extract_validation(
      row$file_path,
      study_id = study_id,
      data_class = row$data_class,
      column_mapping = rg_validation_column_mapping(config = config)
    )
  })
  validation_results <- Filter(Negate(is.null), validation_results)

  define_datasets <- rg_bind_or_empty(lapply(define_results, `[[`, "define_datasets"), rg_define_dataset_columns())
  define_variables <- rg_bind_or_empty(lapply(define_results, `[[`, "define_variables"), rg_define_variable_columns())
  define_codelists <- rg_bind_or_empty(lapply(define_results, `[[`, "define_codelists"), rg_define_codelist_columns())
  define_methods <- rg_bind_or_empty(lapply(define_results, `[[`, "define_methods"), rg_define_method_columns())
  define_valuelevel <- rg_bind_or_empty(lapply(define_results, `[[`, "define_valuelevel"), rg_define_valuelevel_columns())
  validation_findings <- rg_bind_or_empty(validation_results, rg_validation_columns())
  evidence_table <- rg_bind_or_empty(
    c(lapply(define_results, `[[`, "evidence_table"), list(rg_validation_evidence(validation_findings))),
    rg_evidence_columns()
  )

  if (write) {
    rg_write_csv(define_datasets, fs::path(project_path, "work", "extracted", "define_datasets.csv"))
    rg_write_csv(define_variables, fs::path(project_path, "work", "extracted", "define_variables.csv"))
    rg_write_csv(define_codelists, fs::path(project_path, "work", "extracted", "define_codelists.csv"))
    rg_write_csv(define_methods, fs::path(project_path, "work", "extracted", "define_methods.csv"))
    rg_write_csv(define_valuelevel, fs::path(project_path, "work", "extracted", "define_valuelevel.csv"))
    rg_write_csv(validation_findings, fs::path(project_path, "work", "extracted", "validation_findings.csv"))
    rg_write_csv(evidence_table, fs::path(project_path, "work", "evidence", "evidence_table.csv"))
  }

  list(
    define_datasets = define_datasets,
    define_variables = define_variables,
    define_codelists = define_codelists,
    define_methods = define_methods,
    define_valuelevel = define_valuelevel,
    validation_findings = validation_findings,
    evidence_table = evidence_table
  )
}
