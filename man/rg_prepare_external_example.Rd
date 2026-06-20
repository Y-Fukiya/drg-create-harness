\name{rg_prepare_external_example}
\alias{rg_prepare_external_example}
\title{Prepare an optional external example fixture}
\usage{
rg_prepare_external_example(
  project_path,
  example = c("cdisc-pilot"),
  source_path = NULL,
  upstream_commit = NA_character_
)
}
\arguments{
\item{project_path}{Reviewer guide project path created by \code{rg_init_project()}.}
\item{example}{External example to prepare. Currently only \code{"cdisc-pilot"} is supported.}
\item{source_path}{Local path to the external fixture. When \code{NULL}, defaults to
\code{file.path(dirname(project_path), "external", "cdisc-pilot")}.}
\item{upstream_commit}{Optional upstream commit identifier. When omitted or \code{NA}
and \code{source_path} is a git repository, the current \code{HEAD} is detected.}
}
\description{
Copies allowed metadata files from a local CDISC Pilot fixture into a reviewer
guide project and records attribution in \code{work/external_sources.json}.
Only \code{define.xml} metadata is copied into \code{source/}; XPT datasets and
PDF disclaimer contents are not copied into the project source tree.
}
\value{
Invisibly returns the sidecar list written to \code{work/external_sources.json}.
}
