---
title: Credit Assessment API
emoji: 💳
colorFrom: blue
colorTo: green
sdk: docker
app_port: 7860
pinned: false
---

# Credit Assessment API

AI-powered credit risk assessment using Gemini 2.0 Flash.

## Endpoint

**GET** `/assess-credit` — pass all 23 borrower features as query parameters.

### Required parameters

| Parameter | Description |
|---|---|
| LIMIT_BAL | Credit limit (NTD) |
| SEX | 1=Male, 2=Female |
| EDUCATION | 1=Grad, 2=Uni, 3=HS, 4=Other |
| MARRIAGE | 1=Married, 2=Single, 3=Other |
| AGE | Age in years |
| PAY_0–PAY_6 | Repayment status (-1=duly paid, 0=revolving, 1-8=months delay) |
| BILL_AMT1–6 | Monthly bill statements (NTD) |
| PAY_AMT1–6 | Monthly payment amounts (NTD) |

### Example

```
GET /assess-credit?LIMIT_BAL=50000&SEX=2&EDUCATION=2&MARRIAGE=2&AGE=35&PAY_0=0&PAY_2=0&PAY_3=0&PAY_4=0&PAY_5=0&PAY_6=0&BILL_AMT1=10000&BILL_AMT2=9000&BILL_AMT3=8000&BILL_AMT4=7000&BILL_AMT5=6000&BILL_AMT6=5000&PAY_AMT1=2000&PAY_AMT2=2000&PAY_AMT3=2000&PAY_AMT4=2000&PAY_AMT5=2000&PAY_AMT6=2000
```

### Response

```json
{
  "risk_level": "LOW",
  "default_probability": 0.12,
  "key_signals": ["Consistent on-time payments", "Low credit utilization"],
  "recommendation": "Approve credit application.",
  "derived_signals": {
    "bill_to_limit_ratio": 0.2,
    "payment_coverage_ratio": 0.2,
    "consecutive_delays": 0,
    "bill_trend": 5000
  }
}
```

## Environment variable

Set `GEMINI_API_KEY` as a Space secret in the HF Spaces settings.
