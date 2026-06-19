test_that("rg_render_docx creates docx and includes dataset inventory table content", {
  skip_if_not_installed("officedown")
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  out <- rg_render_docx(proj, guide_type = "adrg")

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_true(grepl("ADSL", document_xml))
  expect_true(grepl("officedown harness", document_xml))
})

test_that("rg_render_docx supports reference_docx and cSDRG output", {
  skip_if_not_installed("officedown")
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "csdrg", mode = "dry_run")

  template <- file.path(proj, "templates", "custom_csdrg_template.docx")
  print(officer::body_add_par(officer::read_docx(), "Template marker", style = "Normal"), target = template)

  out <- rg_render_docx(proj, guide_type = "csdrg", template = template)

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_false(grepl("Template marker", document_xml))
  expect_true(grepl("DM", document_xml))
})

test_that("rg_render_docx treats Rmd as the editable document source", {
  skip_if_not_installed("officedown")
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  custom_rmd <- file.path(proj, "templates", "custom-reviewers-guide.Rmd")
  writeLines(c(
    "---",
    "title: \"Custom Reviewer Guide\"",
    "output:",
    "  officedown::rdocx_document:",
    "    reference_docx: \"word/base.docx\"",
    "---",
    "",
    "# Custom Rmd Marker",
    "",
    "`r rg_render_context$title`",
    "",
    "Study: `r rg_render_context$study_id`"
  ), custom_rmd, useBytes = TRUE)

  out <- rg_render_docx(proj, guide_type = "adrg", rmd = custom_rmd)

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_true(grepl("Custom Rmd Marker", document_xml))
  expect_true(grepl("Analysis Data Reviewer", document_xml))
})

test_that("rg_render_docx continues when QC has failing rows", {
  skip_if_not_installed("officedown")
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")
  draft$sections[[1]]$draft_markdown <- "TBD: draft content requires targeted review."
  draft$sections[[1]]$needs_human_review <- TRUE
  draft$sections[[1]]$status <- "needs_review"
  jsonlite::write_json(draft, file.path(proj, "work", "drafts", "adrg_draft.json"), pretty = TRUE, auto_unbox = TRUE)

  qc <- rg_qc(proj, guide_type = "adrg")
  expect_true(any(qc$status == "fail"))

  out <- rg_render_docx(proj, guide_type = "adrg")

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_true(grepl("Value-Level Metadata", document_xml))
  expect_true(grepl("VL.ADAE.AEDECOD", document_xml))
  expect_true(grepl("QC Summary", document_xml))
  expect_false(grepl("unsupported_define_metadata", document_xml))
})

test_that("rg_render_docx can use the officer fallback explicitly", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  out <- rg_render_docx(proj, guide_type = "adrg", engine = "officer")

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_true(grepl("officer fallback", document_xml))
  expect_true(grepl("ADSL", document_xml))
})
