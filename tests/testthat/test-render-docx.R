test_that("rg_render_docx creates docx and includes dataset inventory table content", {
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
})

test_that("rg_render_docx supports templates and cSDRG output", {
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
  expect_true(grepl("Template marker", document_xml))
  expect_true(grepl("DM", document_xml))
})

test_that("rg_render_docx continues when QC has failing rows", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)
  rg_draft_guide(proj, guide_type = "adrg", mode = "dry_run")

  qc <- rg_qc(proj, guide_type = "adrg")
  expect_true(any(qc$status == "fail"))

  out <- rg_render_docx(proj, guide_type = "adrg")

  expect_true(file.exists(out))
  xml_dir <- tempfile("docx-")
  dir.create(xml_dir)
  utils::unzip(out, files = "word/document.xml", exdir = xml_dir)
  document_xml <- paste(readLines(file.path(xml_dir, "word", "document.xml"), warn = FALSE), collapse = "\n")
  expect_true(grepl("ValueListDef", document_xml))
  expect_false(grepl("unsupported_define_metadata", document_xml))
})
