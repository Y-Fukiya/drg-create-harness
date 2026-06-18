\name{rg_qc_summary}
\alias{rg_qc_summary}
\title{Summarize reviewer guide QC results}
\usage{
rg_qc_summary(
  project_path,
  guide_type = c("adrg", "csdrg"),
  qc = NULL,
  write = TRUE
)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{qc}{Optional QC report tibble. When omitted, the function reads the
guide-specific QC report from \code{work/qc/}.}
\item{write}{Whether to write guide-specific and combined QC summary CSV files.}
}
\description{
Create a one-row summary of row-oriented QC results, including overall status,
fail counts, warning/error fail counts, review-required rows, manifest drift,
and missing-evidence counts.
}
\value{A one-row QC summary tibble.}
