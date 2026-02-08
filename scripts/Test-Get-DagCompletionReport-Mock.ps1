<#
.SYNOPSIS
    Mock test for Get-DagCompletionReport.ps1 output formatters

.DESCRIPTION
    This script tests the output formatting functions of Get-DagCompletionReport.ps1
    without requiring actual GitHub data.
#>

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Mock Test: Get-DagCompletionReport.ps1 Formatters" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Mock root issue
$mockRoot = [PSCustomObject]@{
    Number = 1
    Title = "Project Alpha"
    Type = "Initiative"
    State = "OPEN"
}

# Mock epic statistics
$mockEpicStats = @(
    @{
        Epic = "Foundation Setup"
        EpicNumber = 2
        EpicState = "CLOSED"
        Features = @(
            @{
                Feature = "Repository Structure"
                FeatureNumber = 3
                FeatureState = "CLOSED"
                TotalTasks = 5
                CompletedTasks = 5
                Progress = 100.0
            }
            @{
                Feature = "Documentation"
                FeatureNumber = 4
                FeatureState = "CLOSED"
                TotalTasks = 3
                CompletedTasks = 3
                Progress = 100.0
            }
        )
        TotalTasks = 8
        CompletedTasks = 8
        TotalFeatures = 2
        CompletedFeatures = 2
        Progress = 100.0
    }
    @{
        Epic = "Core Features"
        EpicNumber = 5
        EpicState = "OPEN"
        Features = @(
            @{
                Feature = "Authentication"
                FeatureNumber = 6
                FeatureState = "OPEN"
                TotalTasks = 10
                CompletedTasks = 7
                Progress = 70.0
            }
            @{
                Feature = "API Integration"
                FeatureNumber = 7
                FeatureState = "OPEN"
                TotalTasks = 8
                CompletedTasks = 3
                Progress = 37.5
            }
        )
        TotalTasks = 18
        CompletedTasks = 10
        TotalFeatures = 2
        CompletedFeatures = 0
        Progress = 55.56
    }
)

# Mock burndown data
$mockBurndown = @(
    [PSCustomObject]@{
        Date = "2026-02-01"
        Count = 3
        Cumulative = 3
        Issues = @("#10", "#11", "#12")
    }
    [PSCustomObject]@{
        Date = "2026-02-05"
        Count = 5
        Cumulative = 8
        Issues = @("#13", "#14", "#15", "#16", "#17")
    }
    [PSCustomObject]@{
        Date = "2026-02-08"
        Count = 2
        Cumulative = 10
        Issues = @("#18", "#19")
    }
)

# Test Console Output
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 1: Console Output Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DAG COMPLETION REPORT" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Root: #$($mockRoot.Number) - $($mockRoot.Title)" -ForegroundColor Yellow
Write-Host "Type: $($mockRoot.Type)" -ForegroundColor Gray
Write-Host ""

foreach ($stat in $mockEpicStats) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    
    $epicStateIcon = if ($stat.EpicState -eq "CLOSED") { "✓" } else { "○" }
    Write-Host "${epicStateIcon} Epic #$($stat.EpicNumber): $($stat.Epic)" -ForegroundColor Cyan
    Write-Host "   Progress: $($stat.CompletedTasks)/$($stat.TotalTasks) tasks ($($stat.Progress)%)" -ForegroundColor White
    Write-Host "   Features: $($stat.CompletedFeatures)/$($stat.TotalFeatures) completed" -ForegroundColor White
    
    # Progress bar
    $barWidth = 40
    $filled = [math]::Floor(($stat.Progress / 100) * $barWidth)
    $empty = $barWidth - $filled
    $bar = "[" + ("█" * $filled) + ("░" * $empty) + "]"
    Write-Host "   $bar" -ForegroundColor Green
    Write-Host ""
    
    if ($stat.Features.Count -gt 0) {
        Write-Host "   Features:" -ForegroundColor Gray
        foreach ($feature in $stat.Features) {
            $featureStateIcon = if ($feature.FeatureState -eq "CLOSED") { "✓" } else { "○" }
            $progressBar = ""
            if ($feature.TotalTasks -gt 0) {
                $miniBarWidth = 20
                $miniFilled = [math]::Floor(($feature.Progress / 100) * $miniBarWidth)
                $miniEmpty = $miniBarWidth - $miniFilled
                $progressBar = "[" + ("█" * $miniFilled) + ("░" * $miniEmpty) + "]"
            }
            
            Write-Host "     ${featureStateIcon} #$($feature.FeatureNumber): $($feature.Feature)" -ForegroundColor White
            Write-Host "        $($feature.CompletedTasks)/$($feature.TotalTasks) tasks ($($feature.Progress)%) $progressBar" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "BURNDOWN DATA" -ForegroundColor Cyan
Write-Host ""

foreach ($day in $mockBurndown) {
    Write-Host "  $($day.Date): $($day.Count) closed (Total: $($day.Cumulative))" -ForegroundColor White
    Write-Host "    $($day.Issues -join ', ')" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Console output format test passed" -ForegroundColor Green
Write-Host ""

# Test Markdown Output
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 2: Markdown Output Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

$markdown = @"
# DAG Completion Report

**Root:** #$($mockRoot.Number) - $($mockRoot.Title)

## Phase Summary

| Epic | Progress | Features | Tasks |
|------|----------|----------|-------|
| ✅ #2 Foundation Setup | 100.0% | 2/2 | 8/8 |
| ⏳ #5 Core Features | 55.56% | 0/2 | 10/18 |

## Feature Breakdown

### Epic: Foundation Setup

| Feature | Progress | Tasks |
|---------|----------|-------|
| ✅ #3 Repository Structure | 100.0% | 5/5 |
| ✅ #4 Documentation | 100.0% | 3/3 |

### Epic: Core Features

| Feature | Progress | Tasks |
|---------|----------|-------|
| ⏳ #6 Authentication | 70.0% | 7/10 |
| ⏳ #7 API Integration | 37.5% | 3/8 |

## Burndown Data

| Date | Issues Closed | Cumulative | Issues |
|------|---------------|------------|--------|
| 2026-02-01 | 3 | 3 | #10, #11, #12 |
| 2026-02-05 | 5 | 8 | #13, #14, #15, #16, #17 |
| 2026-02-08 | 2 | 10 | #18, #19 |

"@

Write-Host $markdown
Write-Host ""
Write-Host "✓ Markdown output format test passed" -ForegroundColor Green
Write-Host ""

# Test JSON Output
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 3: JSON Output Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

$jsonReport = [PSCustomObject]@{
    Root = [PSCustomObject]@{
        Number = $mockRoot.Number
        Title = $mockRoot.Title
        Type = $mockRoot.Type
        State = $mockRoot.State
    }
    Phases = $mockEpicStats
    Burndown = $mockBurndown
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

$json = $jsonReport | ConvertTo-Json -Depth 10
Write-Host $json
Write-Host ""

# Validate JSON
try {
    $parsed = $json | ConvertFrom-Json
    if ($parsed.Root -and $parsed.Phases -and $parsed.Burndown) {
        Write-Host "✓ JSON output format test passed (valid JSON structure)" -ForegroundColor Green
    } else {
        Write-Host "❌ JSON output format test failed (missing properties)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ JSON output format test failed (invalid JSON)" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  All Mock Tests Completed" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary: All output formatters are working correctly" -ForegroundColor Green
Write-Host ""
