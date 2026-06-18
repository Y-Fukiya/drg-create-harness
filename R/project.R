rg_project_dirs <- function() {
  c(
    "source",
    "source/protocol",
    "source/sap",
    "source/csr",
    "source/acrf",
    "source/tabulation",
    "source/tabulation/specs",
    "source/tabulation/validation",
    "source/analysis",
    "source/analysis/specs",
    "source/analysis/validation",
    "source/analysis/programs",
    "source/other",
    "templates",
    "work",
    "work/extracted",
    "work/drafts",
    "work/evidence",
    "work/qc",
    "output"
  )
}

rg_init_project <- function(path, study_id, guide_types = c("adrg", "csdrg"), overwrite = FALSE) {
  if (missing(path) || missing(study_id)) {
    cli::cli_abort("Both path and study_id are required.")
  }
  guide_types <- unique(match.arg(guide_types, choices = c("adrg", "csdrg"), several.ok = TRUE))
  project_path <- rg_norm_path(path)

  if (fs::dir_exists(project_path) && length(fs::dir_ls(project_path, all = TRUE, fail = FALSE)) > 0 && !overwrite) {
    existing_config <- fs::path(project_path, "config.yml")
    if (fs::file_exists(existing_config)) {
      stop("Project already appears to exist. Use overwrite = TRUE to replace config.yml.", call. = FALSE)
    }
  }

  fs::dir_create(project_path)
  purrr::walk(fs::path(project_path, rg_project_dirs()), fs::dir_create)

  cfg <- rg_default_config(
    study_id = study_id,
    project_id = fs::path_file(project_path),
    guide_types = guide_types
  )
  rg_write_config(cfg, fs::path(project_path, "config.yml"), overwrite = overwrite)
  invisible(project_path)
}
