\name{rg_qc}
\alias{rg_qc}
\title{Run reviewer guide QC checks}
\usage{
rg_qc(project_path, guide_type = c("adrg", "csdrg"), level = c("basic", "strict"), write = TRUE)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{level}{QC level.}
\item{write}{Whether to write \code{work/qc/qc_report.csv}.}
}
\description{
Run row-oriented QC checks for draft presence, required sections, dataset
inventory, evidence ids, validation reflection, unsupported define metadata, and
manifest hash drift.
}
\value{A QC report tibble.}
