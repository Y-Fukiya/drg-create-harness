\name{rg_render_docx}
\alias{rg_render_docx}
\title{Render a draft guide to DOCX}
\usage{
rg_render_docx(project_path, guide_type = c("adrg", "csdrg"), template = NULL, output = NULL)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{template}{Optional DOCX template path.}
\item{output}{Optional output path.}
}
\description{
Render section headings, section text, dataset inventory tables, and validation
finding tables to DOCX using officer and flextable. When available, value-level
define metadata and a compact QC summary table are appended to the draft. PDF
conversion is out of scope.
}
\value{Invisibly returns the output DOCX path.}
