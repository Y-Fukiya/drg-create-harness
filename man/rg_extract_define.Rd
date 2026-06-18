\name{rg_extract_define}
\alias{rg_extract_define}
\title{Extract basic define.xml metadata}
\usage{
rg_extract_define(define_xml, study_id = NULL, data_class = c("auto", "sdtm", "adam", "unknown"))
}
\arguments{
\item{define_xml}{Path to a \code{define.xml} file.}
\item{study_id}{Optional study identifier.}
\item{data_class}{Data class: \code{"auto"}, \code{"sdtm"}, \code{"adam"}, or \code{"unknown"}.}
}
\description{
Extract basic dataset, variable, codelist, method, and evidence metadata from
\code{define.xml}. The parser is intentionally basic and does not fully expand
ValueListDef or WhereClauseDef metadata.
}
\value{A list of tibbles: \code{define_datasets}, \code{define_variables},
\code{define_codelists}, \code{define_methods}, and \code{evidence_table}.}
