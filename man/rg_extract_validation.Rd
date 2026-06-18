\name{rg_extract_validation}
\alias{rg_extract_validation}
\title{Import validation findings}
\usage{
rg_extract_validation(path, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"))
}
\arguments{
\item{path}{Path to a validation CSV or XLSX file.}
\item{study_id}{Optional study identifier.}
\item{data_class}{Data class: \code{"auto"}, \code{"sdtm"}, \code{"adam"}, or \code{"unknown"}.}
}
\description{
Read validation findings from CSV or simple XLSX workbooks and normalize common
column names into the package validation finding schema.
}
\value{A validation findings tibble with evidence identifiers.}
