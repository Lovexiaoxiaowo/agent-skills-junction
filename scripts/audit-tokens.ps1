<#
.SYNOPSIS
    Agent Skills Junction - Skill Token & Description Health Auditor
.DESCRIPTION
    Scans the SSOT skills directory (~/.agents/skills) to analyze each skill's frontmatter description.
    Flags overly verbose descriptions that bloat System Prompts across AI Agent harnesses (Antigravity, Codex, Pi, etc.).
.PARAMETER SSOT
    The Single Source of Truth path. Defaults to ~/.agents/skills.
.PARAMETER ThresholdChars
    Warning threshold in characters. Descriptions longer than this are flagged. Default: 160.
.PARAMETER Top
    Number of top heavy skills to display. Default: 20.
.EXAMPLE
    .\audit-tokens.ps1
.EXAMPLE
    .\audit-tokens.ps1 -ThresholdChars 120 -Top 10
#>

[CmdletBinding()]
param(
    [string]$SSOT = "$HOME\.agents\skills",
    [int]$ThresholdChars = 160,
    [int]$Top = 20
)

$ErrorActionPreference = "Stop"

function Resolve-HomePath([string]$PathStr) {
    if ($PathStr.StartsWith("~")) {
        return $PathStr.Replace("~", $HOME)
    }
    return [System.IO.Path]::GetFullPath($PathStr)
}

$ResolvedSSOT = Resolve-HomePath $SSOT

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "     Agent Skills Junction - Skill Description & Token Auditor  " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Central SSOT Repository: $ResolvedSSOT" -ForegroundColor White
Write-Host "Alert Threshold        : > $ThresholdChars characters" -ForegroundColor DarkGray
Write-Host ""

if (!(Test-Path $ResolvedSSOT)) {
    Write-Error "SSOT path not found: $ResolvedSSOT"
    exit 1
}

$skills = Get-ChildItem -Path $ResolvedSSOT -Directory | Where-Object { 
    $_.Name -ne ".system" -and $_.Name -ne "_scripts" -and $_.Name -ne ".agents" -and $_.Name -ne "__pycache__"
}

$results = @()
$totalChars = 0
$totalEstimatedTokens = 0

foreach ($dir in $skills) {
    $skillFile = Join-Path $dir.FullName "SKILL.md"
    if (Test-Path $skillFile) {
        $content = Get-Content -Path $skillFile -Raw -Encoding utf8
        
        # Match YAML frontmatter between ---
        if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
            $frontmatter = $matches[1]
            
            # Extract description
            if ($frontmatter -match '(?ms)^description:\s*([^\r\n]+(?:\r?\n[ \t]+[^\r\n]+)*)') {
                $rawDesc = $matches[1].Trim()
                # Clean up multiline indentation and quotes
                $cleanDesc = ($rawDesc -split '\r?\n' | ForEach-Object { $_.Trim() }) -join ' '
                $cleanDesc = $cleanDesc.Trim('"', "'")
                
                $chars = $cleanDesc.Length
                # Estimate tokens: ~3 chars per token for mixed bilingual content
                $estTokens = [Math]::Ceiling($chars / 3.0)
                
                $totalChars += $chars
                $totalEstimatedTokens += $estTokens

                $results += [PSCustomObject]@{
                    Name            = $dir.Name
                    Characters      = $chars
                    EstimatedTokens = $estTokens
                    IsBloated       = ($chars -gt $ThresholdChars)
                    Description     = $cleanDesc
                }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "[!] No valid SKILL.md with frontmatter found." -ForegroundColor Yellow
    exit 0
}

$sorted = $results | Sort-Object Characters -Descending
$bloatedCount = ($results | Where-Object { $_.IsBloated }).Count

Write-Host "--- Summary Metrics ---" -ForegroundColor Yellow
Write-Host "Total Registered Skills : $($results.Count)" -ForegroundColor White
Write-Host "Total Description Chars : $totalChars characters" -ForegroundColor White
Write-Host "Estimated Permanent Cost: ~$totalEstimatedTokens tokens injected into EVERY Prompt" -ForegroundColor $(if ($totalEstimatedTokens -gt 3000) { "Red" } else { "Green" })
Write-Host "Bloated Skills (> $ThresholdChars): $bloatedCount / $($results.Count)" -ForegroundColor $(if ($bloatedCount -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

Write-Host "--- Top $Top Heaviest Skill Descriptions ---" -ForegroundColor Yellow
$rank = 0
foreach ($item in ($sorted | Select-Object -First $Top)) {
    $rank++
    $color = if ($item.IsBloated) { "Red" } else { "Green" }
    $statusTag = if ($item.IsBloated) { "[BLOAT]" } else { "[OPTIMAL]" }
    
    Write-Host ("{0,2}. {1,-8} {2,-32} {3,5} chars | ~{4,4} tokens" -f $rank, $statusTag, $item.Name, $item.Characters, $item.EstimatedTokens) -ForegroundColor $color
    
    # Print preview if bloated
    if ($item.IsBloated) {
        $preview = if ($item.Description.Length -gt 100) { $item.Description.Substring(0, 97) + "..." } else { $item.Description }
        Write-Host "     Preview: $preview" -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($bloatedCount -gt 0) {
    Write-Host "[ADVICE] Recommend trimming [BLOAT] descriptions into concise, 1-2 sentence intent triggers." -ForegroundColor Cyan
    Write-Host "         Keep detailed instructions and examples in the body of SKILL.md, not in the frontmatter." -ForegroundColor Cyan
} else {
    Write-Host "[HEALTHY] All skill descriptions conform to the high-density token budget!" -ForegroundColor Green
}
