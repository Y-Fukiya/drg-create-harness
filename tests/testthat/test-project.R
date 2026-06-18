test_that("rg_init_project creates expected folders and config.yml", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")

  expect_true(file.exists(file.path(proj, "config.yml")))
  expect_true(dir.exists(file.path(proj, "source", "analysis", "validation")))
  expect_true(dir.exists(file.path(proj, "source", "tabulation", "validation")))
  expect_true(dir.exists(file.path(proj, "work", "extracted")))
  expect_true(dir.exists(file.path(proj, "output")))
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
