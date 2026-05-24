# autonomous-sprint-loop.ps1
#
# Runs /sprint-execute in a loop until either:
#   - $MaxIterations reached
#   - .claude/state/autonomous-loop-stop.marker is created (graceful stop)
#   - sprint reports no open tickets ("Backlog empty" sentinel in log)
#
# Each iteration is a fresh `claude -p` process => clean context, no /clear needed.
# Permission prompts are bypassed (--permission-mode bypassPermissions).
#
# Designed for Claude Max subscription users (NOT API billing):
#   - No --max-budget-usd flag (API-only, ignored on Max).
#   - On 5-hour quota exhaustion, loop sleeps -RateLimitCooldownMin then resumes.
#   - Set -RateLimitCooldownMin 0 to hard-stop on first quota hit.
#
# Usage:
#   pwsh tools/autonomous-sprint-loop.ps1                       # defaults
#   pwsh tools/autonomous-sprint-loop.ps1 -MaxIterations 30
#   pwsh tools/autonomous-sprint-loop.ps1 -BatchSize 4
#   pwsh tools/autonomous-sprint-loop.ps1 -RateLimitCooldownMin 0   # stop on quota hit
#
# Stop gracefully from another terminal:
#   New-Item -ItemType File -Path .claude/state/autonomous-loop-stop.marker

[CmdletBinding()]
param(
    [int]$MaxIterations        = 20,
    [int]$BatchSize            = 6,
    [int]$SleepBetweenSec      = 20,
    [int]$RateLimitCooldownMin = 300,   # 5h matches Claude Max quota window
    [string]$Focus             = ""
)

$ErrorActionPreference = "Stop"
$repoRoot   = Split-Path -Parent $PSScriptRoot
$logDir     = Join-Path $repoRoot "logs\autonomous-loop"
$stateDir   = Join-Path $repoRoot ".claude\state"
$stopMarker = Join-Path $stateDir "autonomous-loop-stop.marker"
$runLog     = Join-Path $logDir  ("run-{0}.log" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))

New-Item -ItemType Directory -Force -Path $logDir   | Out-Null
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Write-Both([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $runLog -Value $line
}

# Build the prompt once
$promptArgs = @("$BatchSize")
if ($Focus -ne "") { $promptArgs += "--focus"; $promptArgs += $Focus }
$prompt = "/sprint-execute " + ($promptArgs -join " ")

Write-Both "=== Autonomous sprint loop starting ==="
Write-Both "Repo:                 $repoRoot"
Write-Both "Prompt:               $prompt"
Write-Both "Max iter:             $MaxIterations"
Write-Both "Rate-limit cooldown:  $RateLimitCooldownMin min (0 = stop on hit)"
Write-Both "Stop marker:          $stopMarker  (touch it to stop after current iter)"
Write-Both "Run log:              $runLog"
Write-Both ""

# Termination & rate-limit sentinel patterns -----------------------------------
$emptyPatterns = @(
    "No open tickets",
    "Backlog is empty",
    "0 tickets selected",
    "Nothing to do"
)
# Common Claude Max / Anthropic rate-limit phrases. Add more if you spot them
# in your iter logs.
$rateLimitPatterns = @(
    "rate limit",
    "rate-limit",
    "usage limit",
    "quota exceeded",
    "Too many requests",
    "approaching your weekly",
    "5-hour limit reached"
)

for ($i = 1; $i -le $MaxIterations; $i++) {

    if (Test-Path $stopMarker) {
        Write-Both "Stop marker found before iter $i -- removing and exiting."
        Remove-Item $stopMarker -Force
        break
    }

    $stamp   = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $iterLog = Join-Path $logDir ("iter-{0:D3}-{1}.log" -f $i, $stamp)
    Write-Both "--- Iteration $i / $MaxIterations -- log: $iterLog ---"

    $iterStart = Get-Date

    # Run claude non-interactively. --no-session-persistence keeps a clean slate.
    & claude `
        -p $prompt `
        --permission-mode bypassPermissions `
        --output-format text `
        --no-session-persistence `
        --include-hook-events `
        *> $iterLog

    $exit       = $LASTEXITCODE
    $iterDurSec = [int]((Get-Date) - $iterStart).TotalSeconds
    Write-Both "Iter $i exit=$exit  duration=${iterDurSec}s"

    # Rate-limit detection -----------------------------------------------------
    $hitRateLimit = $false
    foreach ($pat in $rateLimitPatterns) {
        if (Select-String -Path $iterLog -Pattern $pat -Quiet -SimpleMatch) {
            Write-Both "Rate-limit signal in iter log (matched '$pat')."
            $hitRateLimit = $true
            break
        }
    }
    if ($hitRateLimit) {
        if ($RateLimitCooldownMin -le 0) {
            Write-Both "RateLimitCooldownMin=$RateLimitCooldownMin -- stopping."
            break
        }
        $resumeAt = (Get-Date).AddMinutes($RateLimitCooldownMin)
        Write-Both ("Sleeping {0} min; will resume around {1:HH:mm}." -f `
            $RateLimitCooldownMin, $resumeAt)
        Start-Sleep -Seconds ($RateLimitCooldownMin * 60)
        Write-Both "Cooldown over -- retrying same iteration index."
        $i-- ; continue  # re-run this iteration after quota reset
    }

    # Backlog-empty detection --------------------------------------------------
    $sprintReportsEmpty = $false
    foreach ($pat in $emptyPatterns) {
        if (Select-String -Path $iterLog -Pattern $pat -Quiet -SimpleMatch) {
            Write-Both "Sprint reports backlog empty (matched '$pat') -- stopping."
            $sprintReportsEmpty = $true
            break
        }
    }
    if ($sprintReportsEmpty) { break }

    if ($exit -ne 0) {
        Write-Both "Iter $i returned non-zero exit. Continuing, but inspect $iterLog."
    }

    if ($i -lt $MaxIterations) {
        Write-Both "Sleeping ${SleepBetweenSec}s before next iter..."
        Start-Sleep -Seconds $SleepBetweenSec
    }
}

Write-Both ""
Write-Both "=== Autonomous sprint loop finished ==="
Write-Both "See per-iteration logs under: $logDir"
