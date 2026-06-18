test_that("rg_init_project creates expected folders and config.yml", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")

  expect_true(file.exists(file.path(proj, "config.yml")))
  expect_true(dir.exists(file.path(proj, "source", "analysis", "validation")))
  expect_true(dir.exists(file.path(proj, "source", "tabulation", "validation")))
  expect_true(dir.exists(file.path(proj, "work", "extracted")))
  expect_true(dir.exists(file.path(proj, "output")))
})
