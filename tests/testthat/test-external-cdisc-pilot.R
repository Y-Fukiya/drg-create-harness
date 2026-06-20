test_that("rg_prepare_external_example copies metadata and writes attribution sidecar", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  source <- make_fake_cdisc_pilot(file.path(dirname(proj), "external", "cdisc-pilot"))
  expected_source <- as.character(rg_norm_path(source))
  expected_adam_source <- as.character(rg_norm_path(file.path(
    source,
    "updated-pilot-submission-package", "900172", "m5", "datasets",
    "cdiscpilot01", "analysis", "adam", "datasets", "define.xml"
  )))

  result <- rg_prepare_external_example(proj, upstream_commit = "abc123")

  expect_equal(result$example, "cdisc-pilot")
  expect_equal(result$source_path, expected_source)
  expect_true(file.exists(file.path(proj, "source", "tabulation", "define.xml")))
  expect_true(file.exists(file.path(proj, "source", "analysis", "define.xml")))

  sidecar_path <- file.path(proj, "work", "external_sources.json")
  expect_true(file.exists(sidecar_path))
  sidecar <- jsonlite::read_json(sidecar_path, simplifyVector = TRUE)
  expect_equal(sidecar$example, "cdisc-pilot")
  expect_equal(sidecar$source_path, expected_source)
  expect_true(nzchar(sidecar$upstream_url))
  expect_equal(sidecar$upstream_commit, "abc123")
  expect_true(grepl("CDISC Pilot", sidecar$attribution, fixed = TRUE))
  expect_equal(
    sidecar$disclaimer_source,
    as.character(rg_norm_path(
      file.path(source, "CDISC.Pilot Project Data.Website Disclaimer.v1.pdf")
    ))
  )
  expect_equal(nrow(sidecar$copied_files), 2)
  expect_setequal(sidecar$copied_files$data_class, c("sdtm", "adam"))
  expect_true(file.exists(expected_adam_source))
  adam_copied <- sidecar$copied_files[sidecar$copied_files$data_class == "adam", ]
  expect_equal(adam_copied$source_path, expected_adam_source)
  expect_setequal(
    normalizePath(sidecar$copied_files$project_path, mustWork = TRUE),
    normalizePath(
      c(
        file.path(proj, "source", "tabulation", "define.xml"),
        file.path(proj, "source", "analysis", "define.xml")
      ),
      mustWork = TRUE
    )
  )
})

test_that("rg_scan_sources annotates external define rows only", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  source <- make_fake_cdisc_pilot()
  rg_prepare_external_example(proj, source_path = source, upstream_commit = "abc123")
  writeLines("local notes", file.path(proj, "source", "other", "notes.txt"))

  manifest <- rg_scan_sources(proj)
  define_rows <- manifest[manifest$source_type == "define", ]

  expect_equal(nrow(define_rows), 2)
  expect_true(all(define_rows$external_origin == "cdisc-pilot"))
  expect_true(all(nzchar(define_rows$upstream_url)))
  expect_true(all(define_rows$upstream_commit == "abc123"))
  expect_true(all(grepl("CDISC Pilot", define_rows$attribution, fixed = TRUE)))
  expect_true(all(grepl("Disclaimer", define_rows$disclaimer_source, fixed = TRUE)))

  local_row <- manifest[manifest$file_name == "notes.txt", ]
  expect_equal(nrow(local_row), 1)
  expect_true(is.na(local_row$external_origin))
  expect_true(is.na(local_row$upstream_url))
  expect_true(is.na(local_row$upstream_commit))
  expect_true(is.na(local_row$attribution))
  expect_true(is.na(local_row$disclaimer_source))
})

test_that("rg_prepare_external_example does not copy XPT or PDF files into project source", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  source <- make_fake_cdisc_pilot()

  rg_prepare_external_example(proj, source_path = source)

  source_files <- list.files(file.path(proj, "source"), recursive = TRUE)
  expect_false(any(grepl("\\.(xpt|pdf)$", source_files, ignore.case = TRUE)))
  expect_setequal(
    source_files,
    c("analysis/define.xml", "tabulation/define.xml")
  )
})

test_that("rg_prepare_external_example detects commits only for fixture git repos", {
  proj <- tempfile("rg-project-")
  rg_init_project(proj, study_id = "TEST-001")
  source <- make_fake_cdisc_pilot()
  fake_commit <- "0123456789abcdef0123456789abcdef01234567"
  fake_bin <- tempfile("fake-git-bin-")
  dir.create(fake_bin, recursive = TRUE)
  fake_git <- file.path(fake_bin, "git")
  writeLines(c(
    "#!/bin/sh",
    paste0("printf '%s\\n' '", fake_commit, "'"),
    "exit 0"
  ), fake_git)
  Sys.chmod(fake_git, mode = "0755")
  old_path <- Sys.getenv("PATH")
  on.exit(Sys.setenv(PATH = old_path), add = TRUE)
  Sys.setenv(PATH = paste(fake_bin, old_path, sep = .Platform$path.sep))

  result <- rg_prepare_external_example(proj, source_path = source)

  expect_true(is.na(result$upstream_commit))

  git_proj <- tempfile("rg-project-")
  rg_init_project(git_proj, study_id = "TEST-001")
  dir.create(file.path(source, ".git"))
  git_result <- rg_prepare_external_example(git_proj, source_path = source)

  expect_equal(git_result$upstream_commit, fake_commit)
})
