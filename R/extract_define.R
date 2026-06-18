rg_xml_attr_any <- function(node, names, default = NA_character_) {
  attrs <- xml2::xml_attrs(node)
  if (length(attrs) == 0) {
    return(default)
  }
  attr_names <- names(attrs)
  local_attr_names <- sub("^.*:", "", attr_names)
  for (name in names) {
    idx <- which(attr_names == name | local_attr_names == name)
    if (length(idx) > 0) {
      value <- unname(attrs[[idx[[1]]]])
      return(value %||% default)
    }
  }
  default
}

rg_xml_text_first <- function(node, xpath, default = NA_character_) {
  found <- xml2::xml_find_first(node, xpath)
  if (inherits(found, "xml_missing")) {
    return(default)
  }
  value <- trimws(xml2::xml_text(found))
  if (!nzchar(value)) default else value
}

rg_xpath_anywhere <- function(name) {
  paste0(".//*[local-name()='", name, "']")
}

rg_xpath_child <- function(name) {
  paste0("./*[local-name()='", name, "']")
}

rg_origin_info <- function(item) {
  origin_node <- xml2::xml_find_first(item, rg_xpath_anywhere("Origin"))
  if (inherits(origin_node, "xml_missing")) {
    return(list(type = NA_character_, detail = NA_character_))
  }
  origin_type <- rg_xml_attr_any(origin_node, "Type", NA_character_)
  origin_detail <- rg_xml_text_first(origin_node, ".//*[local-name()='Description']/*[local-name()='TranslatedText']", NA_character_)
  if (is.na(origin_detail)) {
    origin_detail <- rg_xml_text_first(origin_node, ".//*[local-name()='TranslatedText']", NA_character_)
  }
  if (is.na(origin_detail)) {
    text <- trimws(xml2::xml_text(origin_node))
    origin_detail <- if (nzchar(text) && !identical(text, origin_type)) text else NA_character_
  }
  list(type = origin_type, detail = origin_detail)
}

rg_needs_review_valuelevel <- function(...) {
  any(as.logical(unlist(list(...), use.names = FALSE)), na.rm = TRUE)
}

rg_extract_define <- function(define_xml, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown")) {
  data_class <- match.arg(data_class)
  source_define <- rg_norm_path(define_xml)
  if (!fs::file_exists(source_define)) {
    stop(sprintf("define.xml was not found: %s", source_define), call. = FALSE)
  }
  data_class <- rg_infer_data_class(source_define, data_class)
  doc <- xml2::read_xml(source_define)
  doc <- xml2::xml_ns_strip(doc)

  if (is.null(study_id)) {
    study_name <- rg_xml_text_first(doc, rg_xpath_anywhere("StudyName"), NA_character_)
    study_id <- study_name %||% NA_character_
  }

  item_defs <- xml2::xml_find_all(doc, rg_xpath_anywhere("ItemDef"))
  names(item_defs) <- vapply(item_defs, rg_xml_attr_any, character(1), names = "OID")

  dataset_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("ItemGroupDef"))
  dataset_rows <- vector("list", length(dataset_nodes))
  variable_rows <- list()
  item_context <- list()
  evidence_rows <- list()

  for (i in seq_along(dataset_nodes)) {
    node <- dataset_nodes[[i]]
    dataset_oid <- rg_xml_attr_any(node, "OID")
    dataset_name <- rg_xml_attr_any(node, "Name")
    dataset_label <- rg_xml_attr_any(node, "Label")
    dataset_location <- rg_xml_attr_any(xml2::xml_find_first(node, rg_xpath_anywhere("leaf")), c("href", "xlink:href"), NA_character_)
    if (is.na(dataset_location)) {
      dataset_location <- rg_xml_text_first(node, ".//*[local-name()='leaf']/*[local-name()='title']", NA_character_)
    }
    evidence_id <- rg_make_evidence_id("DEFDS", source_define, dataset_oid, i)
    dataset_rows[[i]] <- tibble::tibble(
      study_id = study_id %||% NA_character_,
      data_class = data_class,
      dataset_oid = dataset_oid,
      dataset_name = dataset_name,
      dataset_label = dataset_label,
      dataset_location = dataset_location,
      structure = rg_xml_attr_any(node, "Structure"),
      purpose = rg_xml_attr_any(node, "Purpose"),
      class = rg_xml_attr_any(node, "Class"),
      repeating = rg_xml_attr_any(node, "Repeating"),
      is_reference_data = rg_xml_attr_any(node, "IsReferenceData"),
      source_define = source_define,
      evidence_id = evidence_id
    )
    evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
      evidence_id = evidence_id,
      study_id = study_id,
      source_file = source_define,
      source_type = "define",
      data_class = data_class,
      locator = paste0("ItemGroupDef[", dataset_oid, "]"),
      extracted_value = paste(stats::na.omit(c(dataset_name, dataset_label)), collapse = " - "),
      extraction_method = "parser",
      confidence = 0.9
    )

    refs <- xml2::xml_find_all(node, rg_xpath_child("ItemRef"))
    if (length(refs) > 0) {
      for (j in seq_along(refs)) {
        ref <- refs[[j]]
        item_oid <- rg_xml_attr_any(ref, "ItemOID")
        item <- item_defs[[item_oid]]
        if (is.null(item)) {
          item <- xml2::xml_missing()
        }
        codelist_ref <- if (!inherits(item, "xml_missing")) {
          rg_xml_attr_any(xml2::xml_find_first(item, rg_xpath_anywhere("CodeListRef")), "CodeListOID", NA_character_)
        } else {
          NA_character_
        }
        origin_info <- if (!inherits(item, "xml_missing")) rg_origin_info(item) else list(type = NA_character_, detail = NA_character_)
        variable_evidence_id <- rg_make_evidence_id("DEFVAR", source_define, paste(dataset_oid, item_oid, sep = "/"), j)
        variable_name <- if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Name") else NA_character_
        item_context[[item_oid]] <- list(
          dataset_oid = dataset_oid,
          dataset_name = dataset_name,
          variable_oid = item_oid,
          variable_name = variable_name
        )
        variable_rows[[length(variable_rows) + 1]] <- tibble::tibble(
          study_id = study_id %||% NA_character_,
          data_class = data_class,
          dataset_oid = dataset_oid,
          dataset_name = dataset_name,
          variable_oid = item_oid,
          variable_name = variable_name,
          variable_label = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Label") else NA_character_,
          variable_type = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "DataType") else NA_character_,
          length = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Length") else NA_character_,
          display_format = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, c("DisplayFormat", "SignificantDigits")) else NA_character_,
          mandatory = rg_xml_attr_any(ref, "Mandatory"),
          key_sequence = rg_xml_attr_any(ref, "KeySequence"),
          role = rg_xml_attr_any(ref, "Role"),
          origin = origin_info$type,
          origin_detail = origin_info$detail,
          method_oid = rg_xml_attr_any(ref, "MethodOID"),
          codelist_oid = codelist_ref,
          source_define = source_define,
          evidence_id = variable_evidence_id
        )
        evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
          evidence_id = variable_evidence_id,
          study_id = study_id,
          source_file = source_define,
          source_type = "define",
          data_class = data_class,
          locator = paste0("ItemGroupDef[", dataset_oid, "]/ItemRef[", item_oid, "]"),
          extracted_value = paste(stats::na.omit(c(dataset_name, if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Name") else NA_character_)), collapse = "."),
          extraction_method = "parser",
          confidence = if (inherits(item, "xml_missing")) 0.5 else 0.9,
          needs_human_review = inherits(item, "xml_missing")
        )
      }
    }
  }

  codelist_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("CodeList"))
  codelist_rows <- list()
  for (i in seq_along(codelist_nodes)) {
    node <- codelist_nodes[[i]]
    codelist_oid <- rg_xml_attr_any(node, "OID")
    external_node <- xml2::xml_find_first(node, rg_xpath_child("ExternalCodeList"))
    external_dictionary <- if (inherits(external_node, "xml_missing")) {
      NA_character_
    } else {
      rg_xml_attr_any(external_node, c("Dictionary", "Name"))
    }
    external_version <- if (inherits(external_node, "xml_missing")) {
      NA_character_
    } else {
      rg_xml_attr_any(external_node, "Version")
    }
    item_nodes <- xml2::xml_find_all(node, "./*[local-name()='CodeListItem' or local-name()='EnumeratedItem']")
    if (length(item_nodes) == 0) {
      item_nodes <- list(xml2::xml_missing())
    }
    for (j in seq_along(item_nodes)) {
      item <- item_nodes[[j]]
      coded_value <- if (inherits(item, "xml_missing")) NA_character_ else rg_xml_attr_any(item, "CodedValue")
      decode <- if (inherits(item, "xml_missing")) {
        NA_character_
      } else {
        rg_xml_text_first(item, ".//*[local-name()='Decode']/*[local-name()='TranslatedText']", NA_character_)
      }
      evidence_id <- rg_make_evidence_id("DEFCL", source_define, paste(codelist_oid, coded_value, sep = "/"), j)
      codelist_rows[[length(codelist_rows) + 1]] <- tibble::tibble(
        study_id = study_id %||% NA_character_,
        codelist_oid = codelist_oid,
        codelist_name = rg_xml_attr_any(node, "Name"),
        data_type = rg_xml_attr_any(node, "DataType"),
        coded_value = coded_value,
        decode = decode,
        external_dictionary = external_dictionary,
        external_version = external_version,
        source_define = source_define,
        evidence_id = evidence_id
      )
      evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
        evidence_id = evidence_id,
        study_id = study_id,
        source_file = source_define,
        source_type = "define",
        data_class = data_class,
        locator = paste0("CodeList[", codelist_oid, "]"),
        extracted_value = paste(stats::na.omit(c(coded_value, decode)), collapse = " = "),
        extraction_method = "parser",
        confidence = 0.85
      )
    }
  }

  method_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("MethodDef"))
  method_rows <- vector("list", length(method_nodes))
  for (i in seq_along(method_nodes)) {
    node <- method_nodes[[i]]
    method_oid <- rg_xml_attr_any(node, "OID")
    method_text <- rg_xml_text_first(node, ".//*[local-name()='Description']/*[local-name()='TranslatedText']", NA_character_)
    if (is.na(method_text)) {
      method_text <- rg_xml_text_first(node, rg_xpath_anywhere("FormalExpression"), NA_character_)
    }
    if (is.na(method_text)) {
      method_text <- trimws(xml2::xml_text(node))
      if (!nzchar(method_text)) method_text <- NA_character_
    }
    evidence_id <- rg_make_evidence_id("DEFMT", source_define, method_oid, i)
    method_rows[[i]] <- tibble::tibble(
      study_id = study_id %||% NA_character_,
      method_oid = method_oid,
      method_name = rg_xml_attr_any(node, "Name"),
      method_type = rg_xml_attr_any(node, "Type"),
      method_text = method_text,
      source_define = source_define,
      evidence_id = evidence_id
    )
    evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
      evidence_id = evidence_id,
      study_id = study_id,
      source_file = source_define,
      source_type = "define",
      data_class = data_class,
      locator = paste0("MethodDef[", method_oid, "]"),
      extracted_value = method_text,
      extraction_method = "parser",
      confidence = 0.85
    )
  }

  valuelevel_rows <- list()
  where_clause_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("WhereClauseDef"))
  where_clause_oids <- vapply(where_clause_nodes, rg_xml_attr_any, character(1), names = "OID")
  value_list_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("ValueListDef"))
  for (i in seq_along(value_list_nodes)) {
    node <- value_list_nodes[[i]]
    value_list_oid <- rg_xml_attr_any(node, "OID")
    refs <- xml2::xml_find_all(node, rg_xpath_child("ItemRef"))
    if (length(refs) == 0) {
      refs <- list(xml2::xml_missing())
    }
    for (j in seq_along(refs)) {
      ref <- refs[[j]]
      item_oid <- if (inherits(ref, "xml_missing")) NA_character_ else rg_xml_attr_any(ref, "ItemOID")
      where_ref <- if (inherits(ref, "xml_missing")) {
        NA_character_
      } else {
        where_oid <- rg_xml_attr_any(ref, "WhereClauseOID", NA_character_)
        if (is.na(where_oid)) {
          where_oid <- rg_xml_attr_any(xml2::xml_find_first(ref, rg_xpath_anywhere("WhereClauseRef")), "WhereClauseOID", NA_character_)
        }
        where_oid
      }
      context <- if (!is.na(item_oid) && item_oid %in% names(item_context)) item_context[[item_oid]] else list()
      item <- if (!is.na(item_oid) && item_oid %in% names(item_defs)) item_defs[[item_oid]] else NULL
      variable_name <- context$variable_name %||% if (!is.null(item) && !inherits(item, "xml_missing")) rg_xml_attr_any(item, "Name") else NA_character_
      locator <- paste0("ValueListDef[", value_list_oid, "]/ItemRef[", item_oid, "]")
      evidence_id <- rg_make_evidence_id("DEFVL", source_define, locator, j)
      needs_review <- rg_needs_review_valuelevel(
        inherits(ref, "xml_missing"),
        is.na(item_oid),
        !is.na(item_oid) && !item_oid %in% names(item_defs),
        !is.na(item_oid) && !item_oid %in% names(item_context),
        !is.na(where_ref) && !where_ref %in% where_clause_oids
      )
      valuelevel_rows[[length(valuelevel_rows) + 1]] <- tibble::tibble(
        study_id = study_id %||% NA_character_,
        data_class = data_class,
        value_list_oid = value_list_oid,
        where_clause_oid = where_ref,
        dataset_oid = context$dataset_oid %||% NA_character_,
        dataset_name = context$dataset_name %||% NA_character_,
        variable_oid = item_oid,
        variable_name = variable_name,
        mandatory = if (inherits(ref, "xml_missing")) NA_character_ else rg_xml_attr_any(ref, "Mandatory"),
        method_oid = if (inherits(ref, "xml_missing")) NA_character_ else rg_xml_attr_any(ref, "MethodOID"),
        where_item_oid = NA_character_,
        where_variable_name = NA_character_,
        comparator = NA_character_,
        check_value = NA_character_,
        soft_hard = NA_character_,
        source_define = source_define,
        evidence_id = evidence_id,
        needs_human_review = needs_review
      )
      evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
        evidence_id = evidence_id,
        study_id = study_id,
        source_file = source_define,
        source_type = "define",
        data_class = data_class,
        locator = locator,
        extracted_value = paste(stats::na.omit(c(value_list_oid, variable_name)), collapse = " - "),
        extraction_method = "parser",
        confidence = if (needs_review) 0.55 else 0.8,
        needs_human_review = needs_review
      )
    }
  }

  for (i in seq_along(where_clause_nodes)) {
    node <- where_clause_nodes[[i]]
    where_clause_oid <- rg_xml_attr_any(node, "OID")
    range_checks <- xml2::xml_find_all(node, rg_xpath_child("RangeCheck"))
    multiple_range_checks <- length(range_checks) > 1
    if (length(range_checks) == 0) {
      range_checks <- list(xml2::xml_missing())
    }
    for (j in seq_along(range_checks)) {
      range_check <- range_checks[[j]]
      item_oid <- if (inherits(range_check, "xml_missing")) NA_character_ else rg_xml_attr_any(range_check, "ItemOID")
      context <- if (!is.na(item_oid) && item_oid %in% names(item_context)) item_context[[item_oid]] else list()
      item <- if (!is.na(item_oid) && item_oid %in% names(item_defs)) item_defs[[item_oid]] else NULL
      variable_name <- context$variable_name %||% if (!is.null(item) && !inherits(item, "xml_missing")) rg_xml_attr_any(item, "Name") else NA_character_
      check_value <- if (inherits(range_check, "xml_missing")) {
        NA_character_
      } else {
        paste(xml2::xml_text(xml2::xml_find_all(range_check, rg_xpath_child("CheckValue"))), collapse = "; ")
      }
      if (!nzchar(check_value)) {
        check_value <- NA_character_
      }
      locator <- paste0("WhereClauseDef[", where_clause_oid, "]/RangeCheck[", item_oid, "]")
      evidence_id <- rg_make_evidence_id("DEFWC", source_define, locator, j)
      comparator <- if (inherits(range_check, "xml_missing")) NA_character_ else rg_xml_attr_any(range_check, "Comparator")
      soft_hard <- if (inherits(range_check, "xml_missing")) NA_character_ else rg_xml_attr_any(range_check, "SoftHard")
      needs_review <- rg_needs_review_valuelevel(
        inherits(range_check, "xml_missing"),
        multiple_range_checks,
        is.na(item_oid),
        !is.na(item_oid) && !item_oid %in% names(item_defs),
        !is.na(item_oid) && !item_oid %in% names(item_context),
        is.na(comparator),
        is.na(check_value)
      )
      valuelevel_rows[[length(valuelevel_rows) + 1]] <- tibble::tibble(
        study_id = study_id %||% NA_character_,
        data_class = data_class,
        value_list_oid = NA_character_,
        where_clause_oid = where_clause_oid,
        dataset_oid = context$dataset_oid %||% NA_character_,
        dataset_name = context$dataset_name %||% NA_character_,
        variable_oid = NA_character_,
        variable_name = NA_character_,
        mandatory = NA_character_,
        method_oid = NA_character_,
        where_item_oid = item_oid,
        where_variable_name = variable_name,
        comparator = comparator,
        check_value = check_value,
        soft_hard = soft_hard,
        source_define = source_define,
        evidence_id = evidence_id,
        needs_human_review = needs_review
      )
      evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
        evidence_id = evidence_id,
        study_id = study_id,
        source_file = source_define,
        source_type = "define",
        data_class = data_class,
        locator = locator,
        extracted_value = paste(stats::na.omit(c(where_clause_oid, variable_name, check_value)), collapse = " - "),
        extraction_method = "parser",
        confidence = if (needs_review) 0.55 else 0.8,
        needs_human_review = needs_review
      )
    }
  }

  list(
    define_datasets = rg_bind_or_empty(dataset_rows, rg_define_dataset_columns()),
    define_variables = rg_bind_or_empty(variable_rows, rg_define_variable_columns()),
    define_codelists = rg_bind_or_empty(codelist_rows, rg_define_codelist_columns()),
    define_methods = rg_bind_or_empty(method_rows, rg_define_method_columns()),
    define_valuelevel = rg_bind_or_empty(valuelevel_rows, rg_define_valuelevel_columns()),
    evidence_table = rg_bind_or_empty(evidence_rows, rg_evidence_columns())
  )
}
