# ============================================================
# test_agent.ps1 — Send a test borrower profile to the local agent
# Usage: .\agent\test_agent.ps1
# Requires n8n running (start_n8n.ps1) and workflow ACTIVATED
# ============================================================

# HIGH RISK borrower (3 consecutive delays, 90% credit utilization)
$highRisk = @{
    LIMIT_BAL = 50000
    SEX       = 1
    EDUCATION = 2
    MARRIAGE  = 1
    AGE       = 35
    PAY_0     = 2; PAY_2 = 2; PAY_3 = 1; PAY_4 = 0; PAY_5 = 0; PAY_6 = 0
    BILL_AMT1 = 45000; BILL_AMT2 = 43000; BILL_AMT3 = 41000
    BILL_AMT4 = 39000; BILL_AMT5 = 37000; BILL_AMT6 = 35000
    PAY_AMT1  = 500;   PAY_AMT2  = 500;   PAY_AMT3  = 500
    PAY_AMT4  = 1000;  PAY_AMT5  = 1000;  PAY_AMT6  = 1000
} | ConvertTo-Json

# LOW RISK borrower (always pays duly, 20% utilization)
$lowRisk = @{
    LIMIT_BAL = 200000
    SEX       = 2
    EDUCATION = 1
    MARRIAGE  = 2
    AGE       = 42
    PAY_0     = -1; PAY_2 = -1; PAY_3 = -1; PAY_4 = -1; PAY_5 = -1; PAY_6 = -1
    BILL_AMT1 = 40000; BILL_AMT2 = 38000; BILL_AMT3 = 37000
    BILL_AMT4 = 36000; BILL_AMT5 = 35000; BILL_AMT6 = 34000
    PAY_AMT1  = 40000; PAY_AMT2  = 38000; PAY_AMT3  = 37000
    PAY_AMT4  = 36000; PAY_AMT5  = 35000; PAY_AMT6  = 34000
} | ConvertTo-Json

$url = "http://localhost:5678/webhook/assess-credit"

Write-Host "=== TEST 1: HIGH RISK BORROWER ===" -ForegroundColor Red
try {
    $r1 = Invoke-RestMethod -Uri $url -Method POST -Body $highRisk -ContentType "application/json"
    $r1 | ConvertTo-Json -Depth 5
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure n8n is running and the workflow is ACTIVATED (not just saved)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== TEST 2: LOW RISK BORROWER ===" -ForegroundColor Green
try {
    $r2 = Invoke-RestMethod -Uri $url -Method POST -Body $lowRisk -ContentType "application/json"
    $r2 | ConvertTo-Json -Depth 5
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
