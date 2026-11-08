<#
.SYNOPSIS
    Agent Skills Junction - Multi-Harness Sync Engine (Windows)
.DESCRIPTION
    Consolidates AI Agent skills into a Single Source of Truth (~/.agents/skills)
    and transparently projects them into multiple Agent harnesses via NTFS Directory Junctions.
.PARAMETER SSOT
    The Single Source of Truth path. Defaults to ~/.agents/skills.
.PARAMETER ConfigFile
    Path to custom harnesses.json. Defaults to ../config/harnesses.json.
.PARAMETER DryRun
    Simulates actions without making any filesystem modifications.
.EXAMPLE
    .\sync.ps1
.EXAMPLE
    .\sync.ps1 -DryRun
.EXAMPLE
    .\sync.ps1 -SSOT "D:\MySkills"
#>

[CmdletBinding()]
param(
    [string]$SSOT = "$HOME\.agents\skills",
    [string]$ConfigFile = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $ConfigFile = Join-Path $PSScriptRoot "..\config\harnesses.json"
}

function Resolve-HomePath([string]$PathStr) {
    if ($PathStr.StartsWith("~")) {
        $PathStr = $PathStr -replace "^~", $HOME
    }
    return [System.IO.Path]::GetFullPath($PathStr)
}

function Test-Excluded([string]$Name, [string[]]$Patterns) {
    foreach ($p in $Patterns) {
        if ($Name -like $p) { return $true }
    }
    return $false
}

$ResolvedSSOT = Resolve-HomePath $SSOT

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "          Agent Skills Junction - Sync Engine (Windows)        " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Central SSOT Repository: $ResolvedSSOT" -ForegroundColor White
if ($DryRun) {
    Write-Host "[DRY-RUN MODE] No filesystem modifications will be performed." -ForegroundColor Magenta
}
Write-Host ""

# Ensure SSOT exists
if (!(Test-Path $ResolvedSSOT)) {
    if (!$DryRun) {
        New-Item -ItemType Directory -Path $ResolvedSSOT -Force | Out-Null
        Write-Host "[+] Initialized central SSOT directory: $ResolvedSSOT" -ForegroundColor Green
    } else {
        Write-Host "[DryRun] Would initialize SSOT directory: $ResolvedSSOT" -ForegroundColor Yellow
    }
}

# Dynamic exclusion pipeline: Base defaults -> harnesses.json -> .gitignore
$Patterns = @(".*", "_*", "*cache*")

# Load harnesses configuration
$Targets = @()
if (Test-Path $ConfigFile) {
    try {
        $cfgJson = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        if ($cfgJson.exclude) { $Patterns += $cfgJson.exclude }
        foreach ($entry in $cfgJson.targets) {
            if ($entry.enabled -and $entry.path_windows) {
                $Targets += [PSCustomObject]@{
                    Name = $entry.name
                    Path = Resolve-HomePath $entry.path_windows
                }
            }
        }
        Write-Host "[OK] Loaded $($Targets.Count) active targets from config file." -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Failed to parse config file: $_. Falling back to built-in presets." -ForegroundColor Yellow
    }
}

$GitIgnoreFile = Join-Path $ResolvedSSOT ".gitignore"
if (Test-Path $GitIgnoreFile) {
    $ignored = Get-Content -Path $GitIgnoreFile | Where-Object { 
        $_ -and -not $_.StartsWith("#") -and -not $_.StartsWith("!") 
    } | ForEach-Object { $_.Trim().TrimEnd('/') }
    $Patterns += $ignored
}

$ActivePatterns = $Patterns | Select-Object -Unique

# Fallback default presets if config is empty or missing
if ($Targets.Count -eq 0) {
    $defaultPaths = @(
        [PSCustomObject]@{ Name = "Pi / ThinkRail"; Path = "$HOME\.pi\agent\skills" },
        [PSCustomObject]@{ Name = "Codex CLI"; Path = "$HOME\.codex\skills" },
        [PSCustomObject]@{ Name = "Gemini Config / Antigravity"; Path = "$HOME\.gemini\config\skills" },
        [PSCustomObject]@{ Name = "Gemini Antigravity CLI"; Path = "$HOME\.gemini\antigravity-cli\skills" },
        [PSCustomObject]@{ Name = "Claude Desktop / Claude Code"; Path = "$HOME\.claude\skills" },
        [PSCustomObject]@{ Name = "Continue.dev"; Path = "$HOME\.continue\skills" },
        [PSCustomObject]@{ Name = "OpenHands"; Path = "$HOME\.openhands\skills" },
        [PSCustomObject]@{ Name = "Cursor Agent"; Path = "$HOME\.cursor\skills" }
    )
    $Targets = $defaultPaths
}

$processed = 0
$linked = 0
$mergedSkills = 0

foreach ($t in $Targets) {
    $processed++
    $tName = $t.Name
    $tPath = $t.Path
    Write-Host "[$processed/$($Targets.Count)] Processing: $tName ($tPath)" -ForegroundColor White

    # Skip if target equals SSOT
    if ($tPath.TrimEnd('\') -eq $ResolvedSSOT.TrimEnd('\')) {
        Write-Host "   -> Skipping: Target is SSOT itself." -ForegroundColor DarkGray
        continue
    }

    $parentDir = Split-Path -Parent $tPath
    if (!(Test-Path $parentDir)) {
        if (!$DryRun) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
    }

    if (Test-Path $tPath) {
        $item = Get-Item $tPath -Force
        $isReparse = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

        if ($isReparse) {
            $currentTarget = $item.Target
            Write-Host "   -> [OK] Already a junction: $tPath ==> $currentTarget" -ForegroundColor Green
            $linked++
            continue
        } else {
            # Physical folder: merge uncommitted unique skills into SSOT
            Write-Host "   -> [MERGE] Physical folder found. Consolidating unique skills into SSOT..." -ForegroundColor Yellow
            $subItems = Get-ChildItem -Path $tPath -Directory
            foreach ($sub in $subItems) {
                if (Test-Excluded $sub.Name $ActivePatterns) { continue }
                $destPath = Join-Path $ResolvedSSOT $sub.Name
                if (!(Test-Path $destPath)) {
                    if (!$DryRun) {
                        Copy-Item -Path $sub.FullName -Destination $destPath -Recurse -Force
                    }
                    Write-Host "      + Merged unique skill: $($sub.Name)" -ForegroundColor Cyan
                    $mergedSkills++
                }
            }

            # Backup original physical folder safely (never delete immediately)
            if (!$DryRun) {
                $bak = "$tPath.bak_" + (Get-Date -Format "yyyyMMddHHmmss")
                Rename-Item -Path $tPath -NewName (Split-Path -Leaf $bak) -Force
                Write-Host "      [BACKUP] Preserved original folder as: $bak" -ForegroundColor DarkGray
            } else {
                Write-Host "      [DryRun] Would backup and replace physical folder with Junction." -ForegroundColor Yellow
            }
        }
    }

    # Create Directory Junction
    if (!$DryRun) {
        cmd /c mklink /J "$tPath" "$ResolvedSSOT" | Out-Null
        if (Test-Path $tPath) {
            Write-Host "   -> [SUCCESS] Junction created: $tPath ==> $ResolvedSSOT" -ForegroundColor Green
            $linked++
        } else {
            Write-Host "   -> [ERROR] Failed to create junction for: $tPath" -ForegroundColor Red
        }
    } else {
        Write-Host "   -> [DryRun] Would execute: mklink /J `"$tPath`" `"$ResolvedSSOT`"" -ForegroundColor Yellow
        $linked++
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                      Execution Summary                         " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Total Target Harnesses : $($Targets.Count)" -ForegroundColor White
Write-Host "Active Junctions       : $linked" -ForegroundColor Green
Write-Host "Merged Unique Skills   : $mergedSkills" -ForegroundColor Cyan
Write-Host "Status                 : All systems unified with zero storage overhead." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
