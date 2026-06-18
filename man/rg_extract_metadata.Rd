\name{rg_extract_metadata}
\alias{rg_extract_metadata}
\title{Extract project metadata}
\usage{
rg_extract_metadata(project_path, write = TRUE)
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{write}{Whether to write extracted CSV and evidence files.}
}
\description{
Read the project manifest, extract define.xml and validation metadata, and write
standard files under \code{work/extracted/} and \code{work/evidence/}.
}
\value{A list of extracted metadata tibbles.}
