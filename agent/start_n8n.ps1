# ============================================================
# start_n8n.ps1 — Launch n8n locally for Credit Assessment Agent
# Africa Business School, UM6P — Hackathon 2026
#
# Usage: Right-click → "Run with PowerShell"  OR  .\agent\start_n8n.ps1
# Then open: http://localhost:5678
# ============================================================

# Load Gemini API key from .env file
$envFile = Join-Path $PSScriptRoot "..\\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+?)\s*=\s*(.+)\s*$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
    Write-Host "Loaded .env variables." -ForegroundColor Green
} else {
    Write-Host "WARNING: .env file not found at $envFile" -ForegroundColor Yellow
}

# Set n8n data directory inside the project (keeps data portable)
$env:N8N_USER_FOLDER = Join-Path $PSScriptRoot "n8n_data"

# Disable n8n telemetry (optional but cleaner for local dev)
$env:N8N_DIAGNOSTICS_ENABLED = "false"
$env:N8N_VERSION_NOTIFICATIONS_ENABLED = "false"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Credit Assessment Agent — n8n Local" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:5678" -ForegroundColor Cyan
Write-Host "  Press Ctrl+C to stop" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "After n8n opens:" -ForegroundColor Yellow
Write-Host "  1. Click 'Add workflow' -> Import from file" -ForegroundColor Yellow
Write-Host "     -> Select: agent\n8n_workflow.json" -ForegroundColor Yellow
Write-Host "  2. Click 'Gemini Flash' node -> set your Google Gemini API credential" -ForegroundColor Yellow
Write-Host "  3. Click 'Activate' toggle (top right)" -ForegroundColor Yellow
Write-Host ""

n8n start
