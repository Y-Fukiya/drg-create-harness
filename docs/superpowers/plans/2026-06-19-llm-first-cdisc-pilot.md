# LLM-First CDISC Pilot Mock Drafting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic mock LLM section drafting and optional CDISC Pilot external fixture support without requiring API keys, provider calls, or bundled CDISC data.

**Architecture:** Add a metadata-only LLM context collector, then route `mode = "mock"` drafting through a deterministic structured draft helper. CDISC Pilot support is an opt-in local external fixture that copies allowed metadata files into the project source area and annotates manifest rows with upstream attribution, commit, disclaimer, and hashes.

**Tech Stack:** R package code, testthat, fs, dplyr, jsonlite, yaml, existing harness CLI, existing officedown DOCX renderer.

---

## File Structure

- Create `R/llm_context.R`: metadata-only context collection and LLM context column definitions.
- Modify `R/llm.R`: deterministic mock drafting function plus existing `ellmer` guard.
- Modify `R/draft.R`: accept `mode = "mock"` and write mock structured fields into draft JSON sections.
- Create `R/external_examples.R`: CDISC Pilot path detection, local copy, and source attribution sidecar helpers.
- Modify `R/manifest.R`: add external source metadata columns and annotate manifest rows when sidecar metadata exists.
- Modify `R/utils.R`: add manifest column helper and keep empty manifest reads type-stable.
- Modify `scripts/run_harness.R`: add `--llm-mode`, `--external-example`, and `--external-source`.
- Modify `scripts/run_harness.ps1` and `scripts/run_harness.cmd`: pass new CLI arguments through.
- Modify `NAMESPACE`: export `rg_collect_llm_context()`, `rg_draft_section_mock()`, and `rg_prepare_external_example()`.
- Create `man/rg_collect_llm_context.Rd`, `man/rg_draft_section_mock.Rd`, and `man/rg_prepare_external_example.Rd`.
- Modify `tests/testthat/helper-fixtures.R`: add reusable fake CDISC Pilot fixture helper.
- Create `tests/testthat/test-llm-mock.R`: structured mock drafting tests.
- Create `tests/testthat/test-external-cdisc-pilot.R`: local fake CDISC Pilot external fixture tests.
- Modify `tests/testthat/test-harness-cli.R`: CLI tests for `--llm-mode mock` and external fixture setup.
- Modify `README.md`, `harness/README.md`, and `docs/post-mvp-roadmap.md`: document mock LLM and CDISC Pilot external fixture usage.

## Task 1: Add Failing Tests For Mock LLM Context And Structured Output

**Files:**
- Create: `tests/testthat/test-llm-mock.R`
- Read: `R/draft.R`
- Read: `R/llm.R`

- [ ] **Step 1: Write failing tests**

Add this file:

```r
test_that("rg_collect_llm_context returns metadata-only section context", {
  proj <- tempfile("rg-llm-context-")
  rg_init_project(proj, study_id = "LLM-001")
  copy_synthetic_sources(proj)
  writeLines("dataset records stay out of LLM context", file.path(proj, "source", "analysis", "adsl.xpt"))
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  context <- rg_collect_llm_context(proj, guide_type = "adrg", section_id = "dataset_inventory")

  expect_s3_class(context, "data.frame")
  expect_true(all(c(
    "context_id", "guide_type", "section_id", "context_type",
    "source_file", "text", "evidence_id", "include_in_llm"
  ) %in% names(context)))
  expect_true(nrow(context) > 0)
  expect_true(all(context$include_in_llm))
  expect_false(any(grepl("\\.xpt$", context$source_file, ignore.case = TRUE)))
  expect_true(any(nzchar(stats::na.omit(context$evidence_id))))
})

test_that("rg_draft_section_mock returns deterministic structured output", {
  proj <- tempfile("rg-llm-mock-")
  rg_init_project(proj, study_id = "LLM-002")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  first <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "dataset_inventory")
  second <- rg_draft_section_mock(proj, guide_type = "adrg", section_id = "dataset_inventory")

  expect_equal(first, second)
  expect_equal(first$guide_type, "adrg")
  expect_equal(first$section_id, "dataset_inventory")
  expect_equal(first$llm_mode, "mock")
  expect_equal(first$provider, "mock")
  expect_type(first$draft_text, "character")
  expect_true(nzchar(first$draft_text))
  expect_true(length(first$evidence_ids) > 0)
  expect_true(length(first$source_context_ids) > 0)
  expect_true(is.numeric(first$confidence))
  expect_true(first$confidence >= 0 && first$confidence <= 1)
  expect_false(isTRUE(first$needs_human_review))
})

test_that("rg_draft_guide mode mock writes mock metadata into sections", {
  proj <- tempfile("rg-llm-guide-")
  rg_init_project(proj, study_id = "LLM-003")
  copy_synthetic_sources(proj)
  rg_scan_sources(proj)
  rg_extract_metadata(proj)

  draft <- rg_draft_guide(proj, guide_type = "adrg", mode = "mock", sections = c("intro", "dataset_inventory"))

  expect_equal(draft$generated_by, "mock")
  expect_equal(length(draft$sections), 2)
  expect_true(all(vapply(draft$sections, function(section) identical(section$generated_by, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$llm_mode, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) identical(section$provider, "mock"), logical(1))))
  expect_true(all(vapply(draft$sections, function(section) length(section$source_context_ids) > 0, logical(1))))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "llm-mock", reporter = "summary")'
```

Expected: FAIL because `rg_collect_llm_context()` and `rg_draft_section_mock()` do not exist, and `mode = "mock"` is not accepted.

- [ ] **Step 3: Commit the failing tests**

```sh
git add tests/testthat/test-llm-mock.R
git commit -m "test: describe mock llm drafting contract"
```

## Task 2: Implement Metadata-Only Context Collection And Mock Drafting

**Files:**
- Create: `R/llm_context.R`
- Modify: `R/llm.R`
- Modify: `R/draft.R`
- Modify: `NAMESPACE`
- Create: `man/rg_collect_llm_context.Rd`
- Create: `man/rg_draft_section_mock.Rd`
- Test: `tests/testthat/test-llm-mock.R`

- [ ] **Step 1: Add `R/llm_context.R`**

Create the file with this content:

```r
rg_llm_context_columns <- function() {
  c(
    "context_id", "study_id", "guide_type", "section_id", "context_type",
    "source_file", "text", "evidence_id", "include_in_llm"
  )
}

rg_context_row <- function(study_id, guide_type, section_id, context_type, source_file, text, evidence_id) {
  seed <- paste(study_id, guide_type, section_id, context_type, evidence_id, text, sep = "|")
  tibble::tibble(
    context_id = paste0("CTX-", substr(digest::digest(seed, algo = "xxhash64"), 1, 12)),
    study_id = as.character(study_id %||% NA_character_),
    guide_type = as.character(guide_type),
    section_id = as.character(section_id),
    context_type = as.character(context_type),
    source_file = as.character(source_file %||% NA_character_),
    text = as.character(text %||% NA_character_),
    evidence_id = as.character(evidence_id %||% NA_character_),
    include_in_llm = TRUE
  )
}

rg_collect_llm_context <- function(project_path, guide_type = c("adrg", "csdrg"), section_id, limit = 40) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)

  if (!fs::file_exists(fs::path(project_path, "work", "extracted", "define_datasets.csv"))) {
    rg_extract_metadata(project_path, write = TRUE)
  }

  manifest <- rg_read_manifest(project_path)
  disallowed <- manifest |>
    dplyr::filter(.data$source_type == "dataset" | tolower(.data$file_ext) %in% c("xpt", "sas7bdat", "parquet", "rds")) |>
    dplyr::filter(.data$include_in_llm %in% c(TRUE, "TRUE", "true", "1"))
  if (nrow(disallowed) > 0) {
    stop("Dataset-like files are marked include_in_llm=TRUE. Refusing to build LLM context.", call. = FALSE)
  }

  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)
  rows <- list()

  if (nrow(data$define_datasets) > 0 && grepl("intro|data_standards|dataset_inventory|unresolved", section_id)) {
    dataset_rows <- utils::head(data$define_datasets, limit)
    for (i in seq_len(nrow(dataset_rows))) {
      row <- dataset_rows[i, ]
      text <- paste(
        "Dataset", row$dataset_name,
        "label", row$dataset_label,
        "structure", row$structure,
        "purpose", row$purpose
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "define_dataset",
        row$source_define, text, row$evidence_id
      )
    }
  }

  if (nrow(data$define_variables) > 0 && grepl("dataset_inventory|unresolved", section_id)) {
    variable_rows <- utils::head(data$define_variables, limit)
    for (i in seq_len(nrow(variable_rows))) {
      row <- variable_rows[i, ]
      text <- paste(
        "Variable", row$dataset_name, row$variable_name,
        "label", row$variable_label,
        "type", row$variable_type,
        "origin", row$origin,
        "detail", row$origin_detail
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "define_variable",
        row$source_define, text, row$evidence_id
      )
    }
  }

  if (nrow(data$validation_findings) > 0 && grepl("conformance|unresolved", section_id)) {
    finding_rows <- utils::head(data$validation_findings, limit)
    for (i in seq_len(nrow(finding_rows))) {
      row <- finding_rows[i, ]
      text <- paste(
        "Validation", row$rule_id,
        "severity", row$severity,
        "dataset", row$dataset_name,
        "variable", row$variable_name,
        "message", row$message,
        "count", row$count
      )
      rows[[length(rows) + 1]] <- rg_context_row(
        study_id, guide_type, section_id, "validation_finding",
        row$source_file, text, row$evidence_id
      )
    }
  }

  out <- rg_bind_or_empty(rows, rg_llm_context_columns())
  out <- dplyr::filter(out, .data$include_in_llm %in% c(TRUE, "TRUE", "true", "1"))
  utils::head(out, limit)
}
```

- [ ] **Step 2: Add mock drafting to `R/llm.R`**

Append this function below `rg_draft_section_ellmer()`:

```r
rg_draft_section_mock <- function(project_path, guide_type = c("adrg", "csdrg"), section_id) {
  guide_type <- match.arg(guide_type)
  project_path <- rg_norm_path(project_path)
  study_id <- rg_project_study_id(project_path)
  data <- rg_filter_for_guide(rg_load_extracted(project_path), guide_type)
  context <- rg_collect_llm_context(project_path, guide_type = guide_type, section_id = section_id)
  evidence_ids <- unique(stats::na.omit(context$evidence_id))
  evidence_ids <- evidence_ids[nzchar(evidence_ids)]
  context_ids <- unique(stats::na.omit(context$context_id))

  datasets <- sort(unique(stats::na.omit(data$define_datasets$dataset_name)))
  findings <- data$validation_findings
  standard_name <- if (identical(guide_type, "adrg")) "ADaM" else "SDTM"
  dataset_summary <- if (length(datasets) > 0) {
    paste(utils::head(datasets, 12), collapse = ", ")
  } else {
    "no datasets extracted from define.xml"
  }

  draft_text <- if (identical(section_id, "intro")) {
    glue::glue(
      "This mock LLM draft summarizes the {standard_name} reviewer guide inputs for study {study_id}. ",
      "It is generated from metadata-only context and must be reviewed before use."
    )
  } else if (grepl("dataset_inventory$", section_id)) {
    glue::glue(
      "The {standard_name} metadata includes {length(datasets)} datasets. ",
      "Datasets identified in define.xml include {dataset_summary}."
    )
  } else if (grepl("conformance_findings$", section_id)) {
    glue::glue(
      "{nrow(findings)} validation findings were available in the metadata-only context for the {standard_name} package."
    )
  } else if (identical(section_id, "unresolved_items")) {
    "The mock LLM draft found no additional unresolved items beyond the structured QC signals. Human review remains required."
  } else {
    glue::glue(
      "The mock LLM draft prepared section {section_id} from metadata-only context for the {standard_name} package."
    )
  }

  needs_review <- length(evidence_ids) == 0 ||
    rg_has_unresolved_metadata(data) ||
    nrow(context) == 0

  list(
    guide_type = guide_type,
    section_id = section_id,
    draft_text = as.character(draft_text),
    evidence_ids = evidence_ids,
    source_context_ids = context_ids,
    confidence = if (isTRUE(needs_review)) 0.6 else 0.85,
    needs_human_review = needs_review,
    warnings = if (isTRUE(needs_review)) "Review required by structured metadata signals or missing context." else character(),
    llm_mode = "mock",
    provider = "mock"
  )
}
```

- [ ] **Step 3: Update `R/draft.R` mode handling**

Change the function signature and early mode branch:

```r
rg_draft_guide <- function(project_path, guide_type = c("adrg", "csdrg"), mode = c("dry_run", "mock", "ellmer"), sections = NULL, write = TRUE) {
```

Replace the `ellmer` branch with:

```r
  if (identical(mode, "ellmer")) {
    return(rg_draft_section_ellmer(project_path, guide_type = guide_type, section_id = sections[[1]] %||% "intro"))
  }
```

Inside the `draft_sections` loop, replace text/evidence generation with this pattern:

```r
    if (identical(mode, "mock")) {
      mock <- rg_draft_section_mock(project_path, guide_type = guide_type, section_id = section_id)
      text <- mock$draft_text
      evidence_ids <- mock$evidence_ids
      source_context_ids <- mock$source_context_ids
      confidence <- mock$confidence
      needs_human_review <- mock$needs_human_review
      generated_by <- "mock"
      llm_mode <- mock$llm_mode
      provider <- mock$provider
      warnings <- mock$warnings
    } else {
      text <- as.character(rg_draft_text_for_section(section_id, spec$title[[i]], guide_type, study_id, data))
      evidence_ids <- switch(
        section_id,
        intro = rg_section_evidence(data$define_datasets$evidence_id, data$validation_findings$evidence_id, limit = 25),
        unresolved_items = rg_unresolved_evidence_ids(data),
        rg_section_evidence(
          if (grepl("conformance", section_id)) data$validation_findings$evidence_id else NULL,
          if (grepl("dataset|standards", section_id)) data$define_datasets$evidence_id else NULL,
          if (grepl("dataset", section_id)) data$define_variables$evidence_id else NULL
        )
      )
      source_context_ids <- character()
      confidence <- NA_real_
      needs_human_review <- rg_section_needs_human_review(section_id, text, evidence_ids, data)
      generated_by <- "dry_run"
      llm_mode <- NA_character_
      provider <- NA_character_
      warnings <- character()
    }
```

In the section list, set these fields:

```r
      generated_by = generated_by,
      generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      needs_human_review = needs_human_review,
      source_context_ids = source_context_ids,
      confidence = confidence,
      llm_mode = llm_mode,
      provider = provider,
      warnings = warnings
```

Set the top-level draft generator:

```r
    generated_by = mode,
```

- [ ] **Step 4: Export and document public functions**

Add to `NAMESPACE`:

```r
export(rg_collect_llm_context)
export(rg_draft_section_mock)
```

Create `man/rg_collect_llm_context.Rd`:

```r
\name{rg_collect_llm_context}
\alias{rg_collect_llm_context}
\title{Collect Metadata-Only LLM Context}
\usage{
rg_collect_llm_context(project_path, guide_type = c("adrg", "csdrg"), section_id, limit = 40)
}
\arguments{
\item{project_path}{Harness project path.}
\item{guide_type}{Reviewer guide type, either \code{"adrg"} or \code{"csdrg"}.}
\item{section_id}{Section identifier to collect context for.}
\item{limit}{Maximum number of context rows to return.}
}
\description{
Builds deterministic, metadata-only context rows for mock or future LLM drafting.
Dataset records and XPT contents are excluded by policy.
}
```

Create `man/rg_draft_section_mock.Rd`:

```r
\name{rg_draft_section_mock}
\alias{rg_draft_section_mock}
\title{Draft A Reviewer Guide Section With The Deterministic Mock LLM}
\usage{
rg_draft_section_mock(project_path, guide_type = c("adrg", "csdrg"), section_id)
}
\arguments{
\item{project_path}{Harness project path.}
\item{guide_type}{Reviewer guide type, either \code{"adrg"} or \code{"csdrg"}.}
\item{section_id}{Section identifier to draft.}
}
\description{
Returns a deterministic structured mock LLM result with draft text, evidence IDs,
context IDs, confidence, provider metadata, and human-review flags.
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "llm-mock", reporter = "summary")'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add R/llm_context.R R/llm.R R/draft.R NAMESPACE man/rg_collect_llm_context.Rd man/rg_draft_section_mock.Rd tests/testthat/test-llm-mock.R
git commit -m "feat: add deterministic mock llm drafting"
```

## Task 3: Add CDISC Pilot External Fixture Sidecar And Manifest Annotation

**Files:**
- Create: `R/external_examples.R`
- Modify: `R/manifest.R`
- Modify: `R/utils.R`
- Modify: `NAMESPACE`
- Create: `man/rg_prepare_external_example.Rd`
- Modify: `tests/testthat/helper-fixtures.R`
- Create: `tests/testthat/test-external-cdisc-pilot.R`

- [ ] **Step 1: Write failing external fixture tests**

Append this helper to `tests/testthat/helper-fixtures.R`:

```r
make_fake_cdisc_pilot <- function() {
  root <- tempfile("fake-cdisc-pilot-")
  sdtm <- file.path(root, "updated-pilot-submission-package", "900172", "m5", "datasets", "cdiscpilot01", "tabulations", "sdtm")
  adam <- file.path(root, "updated-pilot-submission-package", "900172", "m5", "datasets", "cdiscpilot01", "analysis", "adam")
  dir.create(sdtm, recursive = TRUE, showWarnings = FALSE)
  dir.create(adam, recursive = TRUE, showWarnings = FALSE)
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "tabulation", "define.xml"),
    file.path(sdtm, "define.xml")
  )
  file.copy(
    rg_fixture("extdata", "synthetic_study", "source", "analysis", "define.xml"),
    file.path(adam, "define.xml")
  )
  writeLines("CDISC disclaimer text", file.path(root, "CDISC.Pilot Project Data.Website Disclaimer.v1.pdf"))
  root
}
```

Add `tests/testthat/test-external-cdisc-pilot.R`:

```r
test_that("rg_prepare_external_example copies metadata files and writes attribution sidecar", {
  proj <- tempfile("rg-cdisc-project-")
  rg_init_project(proj, study_id = "CDISC-001")
  root <- make_fake_cdisc_pilot()

  result <- rg_prepare_external_example(
    proj,
    example = "cdisc-pilot",
    source_path = root,
    upstream_commit = "test-commit-sha"
  )

  expect_equal(result$example, "cdisc-pilot")
  expect_true(file.exists(file.path(proj, "source", "tabulation", "define.xml")))
  expect_true(file.exists(file.path(proj, "source", "analysis", "define.xml")))
  expect_true(file.exists(file.path(proj, "work", "external_sources.json")))

  sidecar <- jsonlite::read_json(file.path(proj, "work", "external_sources.json"), simplifyVector = TRUE)
  expect_equal(sidecar$example, "cdisc-pilot")
  expect_equal(sidecar$upstream_commit, "test-commit-sha")
  expect_match(sidecar$upstream_url, "cdisc-org/sdtm-adam-pilot-project")
  expect_match(sidecar$attribution, "CDISC")
})

test_that("rg_scan_sources annotates manifest rows from external source sidecar", {
  proj <- tempfile("rg-cdisc-manifest-")
  rg_init_project(proj, study_id = "CDISC-002")
  root <- make_fake_cdisc_pilot()
  rg_prepare_external_example(proj, example = "cdisc-pilot", source_path = root, upstream_commit = "test-commit-sha")

  manifest <- rg_scan_sources(proj)

  expect_true(all(c("external_origin", "upstream_url", "upstream_commit", "attribution", "disclaimer_source") %in% names(manifest)))
  define_rows <- manifest[manifest$source_type == "define", ]
  expect_true(nrow(define_rows) >= 2)
  expect_true(all(define_rows$external_origin == "cdisc-pilot"))
  expect_true(all(define_rows$upstream_commit == "test-commit-sha"))
  expect_true(all(grepl("CDISC", define_rows$attribution)))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "external-cdisc-pilot", reporter = "summary")'
```

Expected: FAIL because `rg_prepare_external_example()` and manifest external columns do not exist.

- [ ] **Step 3: Implement `R/external_examples.R`**

Create this file:

```r
rg_external_sources_path <- function(project_path) {
  fs::path(project_path, "work", "external_sources.json")
}

rg_cdisc_pilot_relative_paths <- function() {
  list(
    sdtm_define = fs::path("updated-pilot-submission-package", "900172", "m5", "datasets", "cdiscpilot01", "tabulations", "sdtm", "define.xml"),
    adam_define = fs::path("updated-pilot-submission-package", "900172", "m5", "datasets", "cdiscpilot01", "analysis", "adam", "define.xml"),
    disclaimer = "CDISC.Pilot Project Data.Website Disclaimer.v1.pdf"
  )
}

rg_default_cdisc_pilot_source <- function(project_path) {
  fs::path(fs::path_dir(project_path), "external", "cdisc-pilot")
}

rg_write_external_source_metadata <- function(project_path, metadata) {
  path <- rg_external_sources_path(project_path)
  fs::dir_create(fs::path_dir(path))
  jsonlite::write_json(metadata, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

rg_read_external_source_metadata <- function(project_path) {
  path <- rg_external_sources_path(project_path)
  if (!fs::file_exists(path)) {
    return(list())
  }
  jsonlite::read_json(path, simplifyVector = TRUE)
}

rg_copy_if_exists <- function(from, to) {
  if (!fs::file_exists(from)) {
    return(FALSE)
  }
  fs::dir_create(fs::path_dir(to))
  ok <- file.copy(from, to, overwrite = TRUE)
  isTRUE(ok)
}

rg_detect_git_commit <- function(path) {
  if (!fs::dir_exists(fs::path(path, ".git"))) {
    return(NA_character_)
  }
  out <- tryCatch(
    system2("git", c("-C", path, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_
  )
  out <- out[[1]] %||% NA_character_
  if (!nzchar(out)) NA_character_ else out
}

rg_prepare_external_example <- function(project_path, example = c("cdisc-pilot"), source_path = NULL, upstream_commit = NA_character_) {
  example <- match.arg(example)
  project_path <- rg_norm_path(project_path)
  source_path <- rg_norm_path(source_path %||% rg_default_cdisc_pilot_source(project_path))
  if (!fs::dir_exists(source_path)) {
    stop("CDISC Pilot external source was not found. Clone or download it under .harness/external/cdisc-pilot or pass --external-source.", call. = FALSE)
  }

  paths <- rg_cdisc_pilot_relative_paths()
  copied <- c(
    sdtm_define = rg_copy_if_exists(fs::path(source_path, paths$sdtm_define), fs::path(project_path, "source", "tabulation", "define.xml")),
    adam_define = rg_copy_if_exists(fs::path(source_path, paths$adam_define), fs::path(project_path, "source", "analysis", "define.xml"))
  )
  if (!any(copied)) {
    stop("No CDISC Pilot define.xml files were found in the expected SDTM or ADaM paths.", call. = FALSE)
  }
  upstream_commit <- upstream_commit %||% rg_detect_git_commit(source_path)

  metadata <- list(
    example = example,
    local_source_path = source_path,
    upstream_url = "https://github.com/cdisc-org/sdtm-adam-pilot-project",
    upstream_commit = upstream_commit,
    attribution = "Contains metadata copied from the CDISC SDTM/ADaM Pilot Project for local harness evaluation.",
    disclaimer_source = fs::path(source_path, paths$disclaimer),
    copied_files = names(copied)[copied]
  )
  rg_write_external_source_metadata(project_path, metadata)
  metadata
}
```

- [ ] **Step 4: Add manifest external columns**

In `R/utils.R`, add:

```r
rg_manifest_columns <- function() {
  c(
    "doc_id", "study_id", "file_path", "file_name", "file_ext",
    "source_type", "data_class", "guide_scope", "file_hash",
    "modified_time", "include_in_llm", "include_in_rag", "status", "notes",
    "external_origin", "upstream_url", "upstream_commit", "attribution",
    "disclaimer_source"
  )
}
```

In `R/manifest.R`, update empty manifest construction to use the new helper:

```r
    manifest <- rg_empty_tbl(rg_manifest_columns())
```

Before creating each manifest row, read external metadata once:

```r
  external <- rg_read_external_source_metadata(project_path)
```

Inside each row tibble, add:

```r
        external_origin = external$example %||% NA_character_,
        upstream_url = external$upstream_url %||% NA_character_,
        upstream_commit = external$upstream_commit %||% NA_character_,
        attribution = external$attribution %||% NA_character_,
        disclaimer_source = external$disclaimer_source %||% NA_character_
```

After binding rows, enforce column order:

```r
    manifest <- dplyr::select(manifest, dplyr::all_of(rg_manifest_columns()))
```

- [ ] **Step 5: Export and document**

Add to `NAMESPACE`:

```r
export(rg_prepare_external_example)
```

Create `man/rg_prepare_external_example.Rd`:

```r
\name{rg_prepare_external_example}
\alias{rg_prepare_external_example}
\title{Prepare An Optional External Harness Example}
\usage{
rg_prepare_external_example(project_path, example = c("cdisc-pilot"), source_path = NULL, upstream_commit = NA_character_)
}
\arguments{
\item{project_path}{Harness project path.}
\item{example}{External example name. Currently only \code{"cdisc-pilot"}.}
\item{source_path}{Local path to the downloaded or cloned external source.}
\item{upstream_commit}{Source commit SHA recorded in the manifest sidecar.}
}
\description{
Copies allowed CDISC Pilot metadata files into the harness project and records
source attribution in \code{work/external_sources.json}. Downloaded CDISC data
remain outside the package repository.
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "external-cdisc-pilot", reporter = "summary")'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add R/external_examples.R R/manifest.R R/utils.R NAMESPACE man/rg_prepare_external_example.Rd tests/testthat/helper-fixtures.R tests/testthat/test-external-cdisc-pilot.R
git commit -m "feat: support cdisc pilot external fixture metadata"
```

## Task 4: Add CLI Support For Mock LLM Mode And External Fixtures

**Files:**
- Modify: `scripts/run_harness.R`
- Modify: `scripts/run_harness.ps1`
- Modify: `scripts/run_harness.cmd`
- Modify: `tests/testthat/test-harness-cli.R`

- [ ] **Step 1: Add failing CLI tests**

Append to `tests/testthat/test-harness-cli.R`:

```r
test_that("harness CLI accepts mock llm mode", {
  candidates <- c(
    file.path("scripts", "run_harness.R"),
    file.path("..", "..", "scripts", "run_harness.R")
  )
  found <- candidates[file.exists(candidates)]
  script <- if (length(found) > 0) found[[1]] else candidates[[1]]
  script <- normalizePath(script, winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(script), "harness CLI script is not available in this check context")

  project <- tempfile("rg-harness-mock-")
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(
    rscript,
    c(
      script,
      "--project", project,
      "--study-id", "HARNESS-MOCK-001",
      "--guide", "adrg",
      "--copy-example", "synthetic",
      "--llm-mode", "mock"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
  draft <- jsonlite::read_json(file.path(project, "work", "drafts", "adrg_draft.json"), simplifyVector = FALSE)
  expect_equal(draft$generated_by, "mock")
  expect_true(all(vapply(draft$sections, function(section) identical(section$llm_mode, "mock"), logical(1))))
})

test_that("harness CLI prepares cdisc pilot external example from local source", {
  candidates <- c(
    file.path("scripts", "run_harness.R"),
    file.path("..", "..", "scripts", "run_harness.R")
  )
  found <- candidates[file.exists(candidates)]
  script <- if (length(found) > 0) found[[1]] else candidates[[1]]
  script <- normalizePath(script, winslash = "/", mustWork = FALSE)
  skip_if_not(file.exists(script), "harness CLI script is not available in this check context")

  source_root <- make_fake_cdisc_pilot()
  project <- tempfile("rg-harness-cdisc-")
  rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  output <- system2(
    rscript,
    c(
      script,
      "--project", project,
      "--study-id", "HARNESS-CDISC-001",
      "--guide", "both",
      "--external-example", "cdisc-pilot",
      "--external-source", source_root,
      "--llm-mode", "mock"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(output, "status")
  if (is.null(status)) {
    status <- 0L
  }

  expect_equal(status, 0L, info = paste(output, collapse = "\n"))
  expect_true(file.exists(file.path(project, "work", "external_sources.json")))
  expect_true(file.exists(file.path(project, "output", "adrg_draft.docx")))
  expect_true(file.exists(file.path(project, "output", "csdrg_draft.docx")))
})
```

- [ ] **Step 2: Run CLI tests to verify they fail**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "harness-cli", reporter = "summary")'
```

Expected: FAIL because CLI arguments are not accepted.

- [ ] **Step 3: Update `scripts/run_harness.R` usage**

Add options:

```r
    "  --llm-mode dry_run|mock|ellmer  Drafting mode override. Default: dry_run.",
    "  --external-example NAME         Prepare optional external example: cdisc-pilot or none.",
    "  --external-source PATH          Local path to the external example source.",
```

- [ ] **Step 4: Parse new CLI options**

After `mode <- arg_value(args, "--mode", "dry_run")`, add:

```r
  llm_mode <- arg_value(args, "--llm-mode", mode)
  external_example <- arg_value(args, "--external-example", "none")
  external_source <- arg_value(args, "--external-source", NULL)
  if (!is.null(external_source) && nzchar(external_source)) {
    external_source <- normalize_cli_path(external_source)
  }
  mode <- llm_mode
```

Update validation:

```r
  if (!mode %in% c("dry_run", "mock", "ellmer")) {
    stop("--llm-mode/--mode must be one of: dry_run, mock, ellmer", call. = FALSE)
  }
  if (!external_example %in% c("none", "cdisc-pilot")) {
    stop("--external-example must be one of: cdisc-pilot, none", call. = FALSE)
  }
```

After `copy_fixture(copy_example, project_path, root)`, add:

```r
  if (!identical(external_example, "none")) {
    rg_prepare_external_example(
      project_path,
      example = external_example,
      source_path = external_source
    )
  }
```

In `summary <- list(...)`, add:

```r
    external_example = external_example,
```

- [ ] **Step 5: Update Windows wrappers**

In `scripts/run_harness.ps1`, ensure the wrapper passes unknown args through to `Rscript scripts/run_harness.R`. If the wrapper enumerates fixed parameters, add:

```powershell
[string]$LlmMode = "dry_run",
[string]$ExternalExample = "none",
[string]$ExternalSource = ""
```

and include:

```powershell
"--llm-mode", $LlmMode,
"--external-example", $ExternalExample
```

Only include `--external-source` when `$ExternalSource` is not empty.

In `scripts/run_harness.cmd`, ensure `%*` is passed through. If it already passes `%*`, no code change is needed.

- [ ] **Step 6: Run CLI tests to verify they pass**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "harness-cli", reporter = "summary")'
```

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add scripts/run_harness.R scripts/run_harness.ps1 scripts/run_harness.cmd tests/testthat/test-harness-cli.R
git commit -m "feat: add mock llm and external fixture cli flags"
```

## Task 5: Update Documentation And Roadmap

**Files:**
- Modify: `README.md`
- Modify: `harness/README.md`
- Modify: `docs/post-mvp-roadmap.md`

- [ ] **Step 1: Add README section**

Add a section named `Mock LLM drafting` to `README.md`:

````md
## Mock LLM drafting

The harness can run deterministic mock LLM drafting without API keys or provider
calls:

```sh
Rscript scripts/run_harness.R --project .harness/rg-demo --copy-example anonymous --llm-mode mock
```

Mock drafting uses metadata-only context from define.xml and validation finding
files. XPT contents and dataset records are excluded from LLM context by policy.
The generated DOCX is still a draft and requires human review.
````

Add a section named `CDISC Pilot external fixture`:

````md
## CDISC Pilot external fixture

The CDISC SDTM/ADaM Pilot Project can be used as an optional local fixture for
manual evaluation. Keep the downloaded repository outside tracked package files,
for example:

```sh
git clone https://github.com/cdisc-org/sdtm-adam-pilot-project .harness/external/cdisc-pilot
Rscript scripts/run_harness.R --project .harness/rg-cdisc-pilot --external-example cdisc-pilot --llm-mode mock
```

The harness records the upstream URL, optional commit SHA, attribution,
disclaimer source, and local file hashes in the project work area. CDISC Pilot
data are not bundled in this package.
````

- [ ] **Step 2: Update `harness/README.md`**

Add Windows and macOS/Linux examples:

````md
### macOS/Linux

```sh
git clone https://github.com/cdisc-org/sdtm-adam-pilot-project .harness/external/cdisc-pilot
Rscript scripts/run_harness.R --project .harness/rg-cdisc-pilot --external-example cdisc-pilot --llm-mode mock
```

### Windows PowerShell

```powershell
git clone https://github.com/cdisc-org/sdtm-adam-pilot-project .\.harness\external\cdisc-pilot
.\scripts\run_harness.ps1 -Project .\.harness\rg-cdisc-pilot -ExternalExample cdisc-pilot -LlmMode mock
```
````

- [ ] **Step 3: Update roadmap**

In `docs/post-mvp-roadmap.md`, change the ellmer section to say:

````md
## ellmer

- Current next step: deterministic mock structured output before real providers.
- Keep `ellmer` in `Suggests`.
- Keep tests free of external provider calls and API keys.
- Context sent to LLMs must remain metadata-only. XPT files and dataset records
  stay excluded from LLM paths.
- Real provider support should be added only after mock output validation is
  stable.
````

Add a CDISC Pilot note:

````md
## CDISC Pilot External Fixture

- Treat the CDISC SDTM/ADaM Pilot Project as an optional local external fixture.
- Do not bundle CDISC Pilot files or generated subsets in `inst/extdata/`.
- Record upstream URL, commit SHA when available, attribution, disclaimer source,
  and file hashes in the local harness work area.
- CI must not require downloading CDISC content.
````

- [ ] **Step 4: Commit docs**

```sh
git add README.md harness/README.md docs/post-mvp-roadmap.md
git commit -m "docs: explain mock llm and cdisc pilot fixture"
```

## Task 6: Full Verification And Branch Handoff

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run targeted tests**

Run:

```sh
Rscript -e 'testthat::test_local(filter = "llm-mock", reporter = "summary")'
Rscript -e 'testthat::test_local(filter = "external-cdisc-pilot", reporter = "summary")'
Rscript -e 'testthat::test_local(filter = "harness-cli", reporter = "summary")'
```

Expected: all PASS.

- [ ] **Step 2: Run full local tests**

Run:

```sh
Rscript -e 'testthat::test_local(reporter = "summary")'
```

Expected: all PASS.

- [ ] **Step 3: Run package check**

Run:

```sh
R CMD build .
_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --no-build-vignettes reviewerguideR_*.tar.gz
```

Expected: check completes without errors or warnings.

- [ ] **Step 4: Run manual harness smoke test**

Run:

```sh
Rscript scripts/run_harness.R --project .harness/rg-mock-smoke --copy-example anonymous --llm-mode mock
```

Expected:

- `.harness/rg-mock-smoke/output/adrg_draft.docx` exists.
- `.harness/rg-mock-smoke/output/csdrg_draft.docx` exists.
- `.harness/rg-mock-smoke/work/drafts/adrg_draft.json` has `generated_by = "mock"`.
- Draft sections have `source_context_ids`.

- [ ] **Step 5: Inspect git diff**

Run:

```sh
git diff --stat main...HEAD
git diff --check
```

Expected: no whitespace errors and the diff is limited to LLM mock drafting, CDISC external fixture handling, CLI, tests, docs, and Rd files.

- [ ] **Step 6: Push and open PR**

Run:

```sh
git push -u origin codex/llm-first-cdisc-pilot-design
gh pr create --draft --title "Add deterministic mock LLM drafting with CDISC Pilot external fixture support" --body "Adds metadata-only mock LLM drafting and opt-in CDISC Pilot external fixture handling. Keeps real provider calls fail-closed and excludes dataset records from LLM context."
```

Expected: draft PR is created and CI starts.
