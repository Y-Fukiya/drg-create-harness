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
    study_id <- rg_xml_attr_any(xml2::xml_find_first(doc, ".//*[local-name()='GlobalVariables']/*[local-name()='StudyName']"), "OID", NA_character_)
    if (is.na(study_id)) {
      study_name <- rg_xml_text_first(doc, rg_xpath_anywhere("StudyName"), NA_character_)
      study_id <- study_name %||% NA_character_
    }
  }

  item_defs <- xml2::xml_find_all(doc, rg_xpath_anywhere("ItemDef"))
  names(item_defs) <- vapply(item_defs, rg_xml_attr_any, character(1), names = "OID")

  dataset_nodes <- xml2::xml_find_all(doc, rg_xpath_anywhere("ItemGroupDef"))
  dataset_rows <- vector("list", length(dataset_nodes))
  variable_rows <- list()
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
        origin <- if (!inherits(item, "xml_missing")) {
          origin_node <- xml2::xml_find_first(item, rg_xpath_anywhere("Origin"))
          if (inherits(origin_node, "xml_missing")) NA_character_ else rg_xml_attr_any(origin_node, "Type", xml2::xml_text(origin_node))
        } else {
          NA_character_
        }
        variable_evidence_id <- rg_make_evidence_id("DEFVAR", source_define, paste(dataset_oid, item_oid, sep = "/"), j)
        variable_rows[[length(variable_rows) + 1]] <- tibble::tibble(
          study_id = study_id %||% NA_character_,
          data_class = data_class,
          dataset_oid = dataset_oid,
          dataset_name = dataset_name,
          variable_oid = item_oid,
          variable_name = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Name") else NA_character_,
          variable_label = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Label") else NA_character_,
          variable_type = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "DataType") else NA_character_,
          length = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, "Length") else NA_character_,
          display_format = if (!inherits(item, "xml_missing")) rg_xml_attr_any(item, c("DisplayFormat", "SignificantDigits")) else NA_character_,
          mandatory = rg_xml_attr_any(ref, "Mandatory"),
          key_sequence = rg_xml_attr_any(ref, "KeySequence"),
          role = rg_xml_attr_any(ref, "Role"),
          origin = origin,
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

  unsupported_define_nodes <- c(
    as.list(xml2::xml_find_all(doc, rg_xpath_anywhere("ValueListDef"))),
    as.list(xml2::xml_find_all(doc, rg_xpath_anywhere("WhereClauseDef")))
  )
  for (i in seq_along(unsupported_define_nodes)) {
    node <- unsupported_define_nodes[[i]]
    node_name <- xml2::xml_name(node)
    oid <- rg_xml_attr_any(node, "OID")
    locator <- paste0(node_name, "[", oid %||% paste0("index=", i), "]")
    evidence_id <- rg_make_evidence_id("DEFUNS", source_define, locator, i)
    evidence_rows[[length(evidence_rows) + 1]] <- rg_new_evidence(
      evidence_id = evidence_id,
      study_id = study_id,
      source_file = source_define,
      source_type = "define",
      data_class = data_class,
      locator = locator,
      extracted_value = paste(node_name, "is present but is not expanded by the MVP define.xml parser."),
      extraction_method = "parser",
      confidence = 0.8,
      needs_human_review = TRUE
    )
  }

  list(
    define_datasets = rg_bind_or_empty(dataset_rows, rg_define_dataset_columns()),
    define_variables = rg_bind_or_empty(variable_rows, rg_define_variable_columns()),
    define_codelists = rg_bind_or_empty(codelist_rows, rg_define_codelist_columns()),
    define_methods = rg_bind_or_empty(method_rows, rg_define_method_columns()),
    evidence_table = rg_bind_or_empty(evidence_rows, rg_evidence_columns())
  )
}
