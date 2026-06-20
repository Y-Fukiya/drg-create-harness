rg_fixture <- function(...) {
  local_path <- file.path("inst", ...)
  if (file.exists(local_path)) {
    return(normalizePath(local_path, mustWork = TRUE))
  }
  path <- system.file(..., package = "reviewerguideR")
  if (!nzchar(path)) {
    path <- local_path
  }
  normalizePath(path, mustWork = TRUE)
}

copy_synthetic_sources <- function(project_path) {
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "analysis", "define.xml"),
    file.path(project_path, "source", "analysis", "define.xml"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "analysis", "validation", "adam_validation.csv"),
    file.path(project_path, "source", "analysis", "validation", "adam_validation.csv"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "tabulation", "define.xml"),
    file.path(project_path, "source", "tabulation", "define.xml"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "tabulation", "validation", "sdtm_validation.csv"),
    file.path(project_path, "source", "tabulation", "validation", "sdtm_validation.csv"),
    overwrite = TRUE
  )
}

copy_anonymous_sources <- function(project_path) {
  file.copy(
    rg_fixture("extdata", "anonymous_study", "source", "analysis", "define.xml"),
    file.path(project_path, "source", "analysis", "define.xml"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "anonymous_study", "source", "analysis", "validation", "adam_validation.csv"),
    file.path(project_path, "source", "analysis", "validation", "adam_validation.csv"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "anonymous_study", "source", "tabulation", "define.xml"),
    file.path(project_path, "source", "tabulation", "define.xml"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "anonymous_study", "source", "tabulation", "validation", "sdtm_validation.csv"),
    file.path(project_path, "source", "tabulation", "validation", "sdtm_validation.csv"),
    overwrite = TRUE
  )
}

make_fake_cdisc_pilot <- function(source_path = tempfile("fake-cdisc-pilot-")) {
  source_path <- normalizePath(source_path, mustWork = FALSE)
  sdtm_dir <- file.path(
    source_path,
    "updated-pilot-submission-package", "900172", "m5", "datasets",
    "cdiscpilot01", "tabulations", "sdtm"
  )
  adam_dir <- file.path(
    source_path,
    "updated-pilot-submission-package", "900172", "m5", "datasets",
    "cdiscpilot01", "analysis", "adam"
  )

  dir.create(sdtm_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(adam_dir, recursive = TRUE, showWarnings = FALSE)
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "tabulation", "define.xml"),
    file.path(sdtm_dir, "define.xml"),
    overwrite = TRUE
  )
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "analysis", "define.xml"),
    file.path(adam_dir, "define.xml"),
    overwrite = TRUE
  )
  writeLines("fake xpt content", file.path(sdtm_dir, "dm.xpt"))
  writeLines("fake xpt content", file.path(adam_dir, "adsl.xpt"))
  writeLines(
    "fake disclaimer placeholder",
    file.path(source_path, "CDISC.Pilot Project Data.Website Disclaimer.v1.pdf")
  )

  as.character(rg_norm_path(source_path))
}

xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

write_minimal_xlsx <- function(path, data, extra_sheet = FALSE, merged_cells = FALSE) {
  dir <- tempfile("xlsx-fixture-")
  dir.create(dir, recursive = TRUE)
  dir.create(file.path(dir, "_rels"))
  dir.create(file.path(dir, "xl", "_rels"), recursive = TRUE)
  dir.create(file.path(dir, "xl", "worksheets"), recursive = TRUE)

  writeLines('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>', file.path(dir, "[Content_Types].xml"))
  writeLines('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>', file.path(dir, "_rels", ".rels"))
  sheets_xml <- '<sheet name="Sheet1" sheetId="1" r:id="rId1"/>'
  if (isTRUE(extra_sheet)) {
    sheets_xml <- paste0(sheets_xml, '<sheet name="Sheet2" sheetId="2" r:id="rId2"/>')
  }
  writeLines(paste0('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>', sheets_xml, '</sheets></workbook>'), file.path(dir, "xl", "workbook.xml"))
  writeLines('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>', file.path(dir, "xl", "_rels", "workbook.xml.rels"))

  data <- as.data.frame(data, stringsAsFactors = FALSE)
  rows <- rbind(names(data), as.matrix(data))
  row_xml <- character(nrow(rows))
  for (i in seq_len(nrow(rows))) {
    cells <- character(ncol(rows))
    for (j in seq_len(ncol(rows))) {
      ref <- paste0(LETTERS[j], i)
      value <- xml_escape(rows[i, j])
      cells[[j]] <- paste0('<c r="', ref, '" t="inlineStr"><is><t>', value, "</t></is></c>")
    }
    row_xml[[i]] <- paste0('<row r="', i, '">', paste(cells, collapse = ""), "</row>")
  }
  merge_xml <- if (isTRUE(merged_cells)) '<mergeCells count="1"><mergeCell ref="A1:B1"/></mergeCells>' else ''
  sheet <- paste0(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    paste(row_xml, collapse = ""),
    "</sheetData>",
    merge_xml,
    "</worksheet>"
  )
  writeLines(sheet, file.path(dir, "xl", "worksheets", "sheet1.xml"))

  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(dir)
  utils::zip(zipfile = path, files = list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE), flags = "-q")
  invisible(path)
}
