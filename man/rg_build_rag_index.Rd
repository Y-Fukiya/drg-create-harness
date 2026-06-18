\name{rg_build_rag_index}
\alias{rg_build_rag_index}
\title{Build a RAG index}
\usage{
rg_build_rag_index(project_path, backend = c("none", "ragnar"))
}
\arguments{
\item{project_path}{Reviewer guide project path.}
\item{backend}{RAG backend.}
}
\description{
MVP RAG indexing integration point. \code{backend = "none"} is a no-op;
\code{"ragnar"} is guarded and requires the optional package.
}
\value{A status tibble for \code{"none"} or a guarded error for unavailable backends.}
