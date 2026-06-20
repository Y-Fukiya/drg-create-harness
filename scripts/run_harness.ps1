param(
  [Parameter(Mandatory = $true)]
  [string]$Project,

  [string]$StudyId = "STUDY-001",

  [ValidateSet("both", "adrg", "csdrg")]
  [string]$Guide = "both",

  [ValidateSet("dry_run", "mock", "ellmer")]
  [string]$Mode = "dry_run",

  [ValidateSet("", "dry_run", "mock", "ellmer")]
  [string]$LlmMode = "",

  [ValidateSet("basic", "strict")]
  [string]$QcLevel = "basic",

  [ValidateSet("none", "synthetic", "anonymous")]
  [string]$CopyExample = "none",

  [ValidateSet("none", "cdisc-pilot")]
  [string]$ExternalExample = "none",

  [string]$ExternalSource = "",

  [string]$Summary = "",

  [switch]$Init,
  [switch]$NoRun,
  [switch]$Interactive,
  [switch]$FailOnQc
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $scriptDir "run_harness.R"

$runnerArgs = @(
  $runner,
  "--project", $Project,
  "--study-id", $StudyId,
  "--guide", $Guide,
  "--mode", $Mode,
  "--qc-level", $QcLevel
)

if ($CopyExample -ne "none") {
  $runnerArgs += @("--copy-example", $CopyExample)
}
if ($LlmMode -ne "") {
  $runnerArgs += @("--llm-mode", $LlmMode)
}
if ($ExternalExample -ne "none") {
  $runnerArgs += @("--external-example", $ExternalExample)
  if ($ExternalSource -ne "") {
    $runnerArgs += @("--external-source", $ExternalSource)
  }
}
if ($Summary -ne "") {
  $runnerArgs += @("--summary", $Summary)
}
if ($Init) {
  $runnerArgs += "--init"
}
if ($NoRun) {
  $runnerArgs += "--no-run"
}
if ($Interactive) {
  $runnerArgs += "--interactive"
}
if ($FailOnQc) {
  $runnerArgs += "--fail-on-qc"
}

& Rscript @runnerArgs
exit $LASTEXITCODE
