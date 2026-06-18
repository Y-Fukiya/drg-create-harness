\name{rg_extract_validation}
\alias{rg_extract_validation}
\title{Import validation findings}
\usage{
rg_extract_validation(
  path,
  study_id = NULL,
  data_class = c("auto", "sdtm", "adam", "unknown"),
  column_mapping = NULL
)
}
\arguments{
\item{path}{Path to a validation CSV or XLSX file.}
\item{study_id}{Optional study identifier.}
\item{data_class}{Data class: \code{"auto"}, \code{"sdtm"}, \code{"adam"}, or \code{"unknown"}.}
\item{column_mapping}{Optional named list mapping normalized validation fields
to one or more source column names. Entries are tried before the built-in
defaults.}
}
\description{
Read validation findings from CSV or simple XLSX workbooks and normalize common
column names into the package validation finding schema. Project-level mapping
can also be set in \code{config.yml} under \code{validation.column_mapping}.
}
\value{A validation findings tibble with evidence identifiers.}
