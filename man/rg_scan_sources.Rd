\name{rg_scan_sources}
\alias{rg_scan_sources}
\title{Scan project source files}
\usage{
rg_scan_sources(project_path, write = TRUE)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{write}{Whether to write \code{work/manifest.json}.}
}
\description{
Recursively scan \code{source/}, infer file types and guide scope, hash files,
and mark subject-level dataset files as ineligible for LLM/RAG paths.
}
\value{A tibble manifest.}
