rg_compact_table <- function(x, columns, max_rows = 25) {
  if (nrow(x) == 0) {
    return(tibble::tibble(Note = "No rows available."))
  }
  columns <- intersect(columns, names(x))
  dplyr::select(x, dplyr::all_of(columns)) |>
    utils::head(max_rows)
}

rg_flextable <- function(x) {
  flextable::flextable(x) |>
    flextable::theme_booktabs() |>
    flextable::set_table_properties(layout = "fixed", width = 1) |>
    flextable::fontsize(size = 9, part = "all") |>
    flextable::bold(part = "header") |>
    flextable::autofit()
}
