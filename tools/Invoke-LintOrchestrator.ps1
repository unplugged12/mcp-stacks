<# ==================================================================================================
Invoke-LintOrchestrator.ps1
Purpose: Run the lint-cleanup plan in safe phases, per-branch, and (optionally) open PRs automatically.

Phases (in order):
  1) Agent-01: Fix assignment to automatic variables (e.g., $error)
  2) Agent-02: Rename unapproved verbs in smoke-test.ps1
  3) Agent-03: Replace Write-Host (pass 1: all except smoke-test.ps1)
  4) Agent-03: Replace Write-Host (pass 2: smoke-test.ps1 only) — runs after Phase 2
  5) Agent-04: Normalize file encoding where BOM rule trips
  6) Agent-05: Declared var hygiene (default: remove unused)

Each phase works in its own lint/* branch to minimize merge conflicts.

Usage examples:
  pwsh ./tools/Invoke-LintOrchestrator.ps1 -Apply -OpenPR -AutoMerge
  pwsh ./tools/Invoke-LintOrchestrator.ps1 -DryRun
================================================================================================== #>

[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply,              # When set, passes -Apply to agents and writes changes
  [switch]$DryRun,             # Forces agents to run without -Apply regardless (preview only)
  [switch]$OpenPR,             # Create PRs using gh (GitHub) or az devops (Azure DevOps)
  [switch]$AutoMerge,          # Attempt to auto-merge PRs after status checks succeed (GitHub only, requires permission)
  [ValidateSet('remove','use','suppress')]
  [string]$VarHygieneMode = 'remove',
  [string]$BaseBranch = 'main'
)

# ---- Config -----------------------------------------------------------------
$RepoRoot       = (git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) { throw "Not inside a git repository. Run from within MCP-Stacks repo." }
Set-Location $RepoRoot

$AgentsRoot     = Join-Path $RepoRoot 'tools\agents'
$Agent01        = Join-Path $AgentsRoot 'Agent01_FixAutomaticVars.ps1'
$Agent02        = Join-Path $AgentsRoot 'Agent02_RenameUnapprovedVerbs.ps1'
$Agent03        = Join-Path $AgentsRoot 'Agent03_RefactorWriteHost.ps1'
$Agent04        = Join-Path $AgentsRoot 'Agent04_NormalizeEncoding.ps1'
$Agent05        = Join-Path $AgentsRoot 'Agent05_VariableHygiene.ps1'

$Phases = @(
  @{ Name='Phase1-AutoVar';   Script=$Agent01; Args=@();                                     Branch='lint/auto-var-sanitizer' }
  @{ Name='Phase2-Approved';  Script=$Agent02; Args=@();                                     Branch='lint/approved-verbs' }
  @{ Name='Phase3-HostP1';    Script=$Agent03; Args=@();                                     Branch='lint/logging-refactor' }
  @{ Name='Phase4-HostP2';    Script=$Agent03; Args=@('-Include','*.ps1','-Exclude','');     Branch='lint/logging-refactor-smoke' }
  @{ Name='Phase5-Encoding';  Script=$Agent04; Args=@();                                     Branch='lint/encoding' }
  @{ Name='Phase6-Vars';      Script=$Agent05; Args=@('-Mode', $VarHygieneMode);             Branch='lint/var-hygiene' }
)

# ---- Helpers ----------------------------------------------------------------
function Test-Tool {
  param([Parameter(Mandatory)][string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-ProviderInfo {
  $remote = (git remote get-url origin)
  if ($remote -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^\.]+)') {
    return @{ Provider='github'; Owner=$Matches.owner; Repo=$Matches.repo }
  }
  elseif ($remote -match 'dev\.azure\.com/(?<org>[^/]+)/(?<project>[^/]+)/_git/(?<repo>[^/]+)') {
    return @{ Provider='azure'; Org=$Matches.org; Project=$Matches.project; Repo=$Matches.repo }
  }
  else {
    return @{ Provider='none' }
  }
}

function Ensure-CleanTree {
  $status = git status --porcelain
  if ($status) { throw "Working tree is dirty. Commit or stash before running the orchestrator." }
}

function Ensure-Base {
  git fetch --all --prune
  git checkout $BaseBranch
  git pull --ff-only
}

function Run-AgentPhase {
  param(
    [Parameter(Mandatory)][hashtable]$Phase,
    [hashtable]$Provider
  )
  $script = $Phase.Script
  if (-not (Test-Path $script)) {
    throw "Missing agent script: $script`nEnsure all 5 agent scripts exist under $AgentsRoot"
  }

  $branch = $Phase.Branch
  Write-Host "`n=== $($Phase.Name) -> $branch ===" -ForegroundColor Cyan

  # The agent scripts themselves create their branch; we just call them.
  $args = @()
  $args += $Phase.Args
  if ($DryRun -or -not $Apply) {
    # Force DryRun
  } else {
    $args += '-Apply'
  }

  Write-Host "Running: $script $($args -join ' ')" -ForegroundColor DarkGray
  & pwsh -NoProfile -File $script @args
  if ($LASTEXITCODE -ne 0) { throw "$($Phase.Name) failed (exit $LASTEXITCODE)." }

  # If nothing changed, the branch may not exist — detect
  $branchExists = (git branch --list $branch)
  if (-not $branchExists) {
    Write-Host "No changes produced by $($Phase.Name). Skipping PR step." -ForegroundColor Yellow
    return
  }

  # Push and optionally PR
  git push -u origin $branch

  if ($OpenPR) {
    New-LintPR -Phase $Phase -Provider $Provider
  }
}

function New-LintPR {
  param(
    [Parameter(Mandatory)][hashtable]$Phase,
    [Parameter(Mandatory)][hashtable]$Provider
  )
  $title = switch ($Phase.Name) {
    'Phase1-AutoVar' { "lint: avoid assignment to automatic variables (e.g., `$error)" }
    'Phase2-Approved' { "lint: use approved verbs in smoke-test.ps1" }
    'Phase3-HostP1' { "lint: replace Write-Host with Write-Status (pass 1)" }
    'Phase4-HostP2' { "lint: replace Write-Host with Write-Status (smoke-test pass)" }
    'Phase5-Encoding' { "lint: normalize encoding (UTF-8 BOM where non-ASCII)" }
    'Phase6-Vars' { "lint: resolve declared-but-unused variables ($VarHygieneMode)" }
    default { "lint: $($Phase.Name)" }
  }

  $body = @"
Automated lint cleanup — $($Phase.Name)

**Scope**
- Branch: `$($Phase.Branch)`
- Base: `$BaseBranch`

**Intent**
- Address specific PSScriptAnalyzer findings as per the lint plan.
- Safe, narrow edits to minimize merge conflicts.

**Validation**
- Local: `pwsh -File .\scripts\run-tests.ps1`
- Review: Focus on mechanical replacements only.

"@

  switch ($Provider.Provider) {
    'github' {
      if (-not (Test-Tool gh)) { Write-Host "gh CLI not found — skipping PR creation." -ForegroundColor Yellow; return }
      $prCmd = @('pr','create','--base', $BaseBranch,'--head',$Phase.Branch,'--title',$title,'--body',$body)
      if ($AutoMerge) { $prCmd += '--draft' }  # open as draft if we plan to auto-enable merge later
      & gh @prCmd
      if ($LASTEXITCODE -ne 0) { Write-Host "gh PR create failed." -ForegroundColor Yellow; return }

      if ($AutoMerge) {
        # Try enabling auto-merge once checks pass (best-effort)
        $prNum = (gh pr view --json number --jq .number)
        if ($prNum) {
          gh pr merge $prNum --auto --squash | Out-Null
          Write-Host "Auto-merge enabled for PR #$prNum (squash)." -ForegroundColor Green
        }
      }
    }
    'azure' {
      if (-not (Test-Tool az)) { Write-Host "az CLI not found — skipping PR creation." -ForegroundColor Yellow; return }
      # Assumes 'az devops configure --defaults organization=... project=...' has been set
      $result = az repos pr create `
        --title $title `
        --description $body `
        --source-branch $Phase.Branch `
        --target-branch $BaseBranch `
        --squash
      if ($LASTEXITCODE -ne 0) { Write-Host "az repos pr create failed." -ForegroundColor Yellow }
    }
    default {
      Write-Host "Remote provider not recognized; skipping PR creation." -ForegroundColor Yellow
    }
  }
}

# ---- Execution ---------------------------------------------------------------
try {
  Ensure-CleanTree
  Ensure-Base
  $provider = Get-ProviderInfo
  Write-Host "Remote provider: $($provider.Provider)" -ForegroundColor DarkGray

  # Phase 1
  Run-AgentPhase -Phase $Phases[0] -Provider $provider

  # Phase 2
  Run-AgentPhase -Phase $Phases[1] -Provider $provider

  # Phase 3 (Write-Host pass 1: excludes smoke-test by default agent config)
  Run-AgentPhase -Phase $Phases[2] -Provider $provider

  # Phase 4 (Write-Host pass 2: target smoke-test only by overriding Exclude to empty)
  Run-AgentPhase -Phase $Phases[3] -Provider $provider

  # Phase 5 (encoding)
  Run-AgentPhase -Phase $Phases[4] -Provider $provider

  # Phase 6 (var hygiene)
  Run-AgentPhase -Phase $Phases[5] -Provider $provider

  Write-Host "`nAll phases completed." -ForegroundColor Green
  if ($OpenPR) {
    Write-Host "PRs opened where changes existed. Merge in the sequence above to avoid conflicts." -ForegroundColor Green
  } else {
    Write-Host "No PRs opened (use -OpenPR to auto-create)." -ForegroundColor Yellow
  }
}
catch {
  Write-Error $_
  exit 1
}
