test_that("rg_init_project creates expected folders and config.yml", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  config <- yaml::read_yaml(file.path(proj, "config.yml"))

  expect_true(file.exists(file.path(proj, "config.yml")))
  expect_true(dir.exists(file.path(proj, "source", "analysis", "validation")))
  expect_true(dir.exists(file.path(proj, "source", "tabulation", "validation")))
  expect_true(dir.exists(file.path(proj, "work", "extracted")))
  expect_true(dir.exists(file.path(proj, "output")))
  expect_true(file.exists(file.path(proj, "templates", "reviewers-guide.Rmd")))
  expect_true(file.exists(file.path(proj, "templates", "word", "base.docx")))
  expect_equal(config$render$engine, "officedown")
  expect_equal(config$render$rmd, "templates/reviewers-guide.Rmd")
  expect_equal(config$render$reference_docx, "templates/word/base.docx")
})

test_that("rg_init_project respects overwrite and guide type flags", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001", guide_types = "adrg")
  config <- yaml::read_yaml(file.path(proj, "config.yml"))

  expect_true(config$guides$adrg$enabled)
  expect_false(config$guides$csdrg$enabled)
  expect_error(rg_init_project(proj, study_id = "TEST-002"), "overwrite = TRUE", fixed = TRUE)

  rg_init_project(proj, study_id = "TEST-002", overwrite = TRUE)
  updated <- yaml::read_yaml(file.path(proj, "config.yml"))
  expect_equal(updated$study$study_id, "TEST-002")
})

test_that("data class inference handles Windows path separators", {
  expect_equal(rg_infer_data_class("C:\\study\\source\\tabulation\\dm.xpt"), "sdtm")
  expect_equal(rg_infer_data_class("C:\\study\\source\\analysis\\adsl.xpt"), "adam")
})
