\name{rg_init_project}
\alias{rg_init_project}
\title{Initialize a reviewer guide project}
\usage{
rg_init_project(path, study_id, guide_types = c("adrg", "csdrg"), overwrite = FALSE)
}
\arguments{
\item{path}{Project directory path to create or update.}
\item{study_id}{Study identifier written to \code{config.yml}.}
\item{guide_types}{Guide types to enable, \code{"adrg"}, \code{"csdrg"}, or both.}
\item{overwrite}{Whether to overwrite an existing \code{config.yml}.}
}
\description{
Create the standard project directory tree and initial \code{config.yml}.
}
\value{Invisibly returns the normalized project path.}
