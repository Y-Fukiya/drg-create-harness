\name{rg_render_docx}
\alias{rg_render_docx}
\title{Render a draft guide to DOCX}
\usage{
rg_render_docx(
  project_path,
  guide_type = c("adrg", "csdrg"),
  template = NULL,
  output = NULL,
  rmd = NULL,
  reference_docx = NULL,
  engine = NULL
)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{guide_type}{Guide type, \code{"adrg"} or \code{"csdrg"}.}
\item{template}{Optional backward-compatible alias for \code{reference_docx}.}
\item{output}{Optional output path.}
\item{rmd}{Optional R Markdown template path.}
\item{reference_docx}{Optional Word style base used by officedown.}
\item{engine}{Optional render engine, \code{"officedown"} or \code{"officer"}.}
}
\description{
Render section headings, section text, dataset inventory tables, and validation
finding tables to DOCX. The primary path renders an R Markdown template with
\code{officedown::rdocx_document()}, using \code{reference_docx} as the single
Word style base. The officer/flextable direct renderer remains available as an
explicit fallback via \code{engine = "officer"}. When available, value-level
define metadata and a compact QC summary table are appended to the draft. PDF
conversion is out of scope.
}
\value{Invisibly returns the output DOCX path.}
