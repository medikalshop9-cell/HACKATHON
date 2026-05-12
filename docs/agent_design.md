# Agent Design — n8n Credit Risk Assessment Agent
**Credit Assessment Agent | Africa Business School, UM6P**

---

## Purpose

The agent accepts a borrower's profile (23 variables) via a JSON POST request and returns
a structured plain-language credit risk assessment — no code required from the end user.

It acts as the **explainability and decision layer** on top of the ML models trained in Part 1.

---

## Architecture

```
POST /webhook/assess-credit
        │
        ▼
┌───────────────────┐
│  Webhook Trigger  │  Receives raw borrower JSON
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│   Validation /    │  Set Node — normalize field names,
│   Set Node        │  check required fields, compute
│                   │  derived signals (e.g. payment ratio)
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│   LLM Node        │  Claude (claude-3-5-sonnet) or GPT-4o
│  (System Prompt)  │  — Credit risk reasoning framework
│  (User Prompt)    │  — Borrower JSON payload
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Output Parser    │  Enforce structured JSON schema
│  (JSON Schema)    │  — reject/retry if malformed
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│  Respond to       │  Return 200 with structured result
│  Webhook          │
└───────────────────┘
```

---

## Input Schema

The agent accepts all 23 feature variables used in the ML models as a flat JSON object.

```json
{
  "LIMIT_BAL": 120000,
  "SEX": 2,
  "EDUCATION": 2,
  "MARRIAGE": 1,
  "AGE": 35,
  "PAY_0": 2,
  "PAY_2": 0,
  "PAY_3": 0,
  "PAY_4": 0,
  "PAY_5": 0,
  "PAY_6": 0,
  "BILL_AMT1": 98000,
  "BILL_AMT2": 95000,
  "BILL_AMT3": 93000,
  "BILL_AMT4": 90000,
  "BILL_AMT5": 88000,
  "BILL_AMT6": 85000,
  "PAY_AMT1": 3000,
  "PAY_AMT2": 2500,
  "PAY_AMT3": 2000,
  "PAY_AMT4": 2000,
  "PAY_AMT5": 1500,
  "PAY_AMT6": 1500
}
```

### Field Validation Rules
| Field | Constraint |
|---|---|
| `LIMIT_BAL` | Integer > 0 |
| `SEX` | 1 or 2 |
| `EDUCATION` | 1–4 (after cleaning) |
| `MARRIAGE` | 1–3 (after cleaning) |
| `AGE` | Integer ≥ 18 |
| `PAY_*` | Integer -1 to 8 (after cleaning) |
| `BILL_AMT*` | Numeric (can be negative) |
| `PAY_AMT*` | Numeric ≥ 0 |

---

## Output Schema

```json
{
  "risk_level": "LOW | MEDIUM | HIGH",
  "default_probability": 0.72,
  "key_signals": [
    "3 consecutive months of delayed payments (PAY_0, PAY_2, PAY_3)",
    "Bill amount consistently exceeds 80% of credit limit",
    "Payment amounts well below minimum due"
  ],
  "recommendation": "Do not extend new credit. Flag for collections review."
}
```

### Risk Level Thresholds
| Risk Level | Default Probability Range | Recommended Action |
|---|---|---|
| LOW | < 0.30 | Approve credit |
| MEDIUM | 0.30 – 0.60 | Approve with conditions / reduce limit |
| HIGH | > 0.60 | Reject / escalate to collections |

---

## LLM System Prompt Design

The system prompt grounds the LLM in the domain logic of the dataset.

```
You are a credit risk analyst assistant. Your job is to assess the default risk
of a credit card client based on their borrower profile.

DATASET CONTEXT:
- Data sourced from Taiwan credit card clients (Apr–Sep 2005)
- Currency: New Taiwan Dollar (NTD)
- Target: probability of defaulting on next month's payment

VARIABLE GUIDE:
- LIMIT_BAL: credit limit in NTD
- PAY_0 to PAY_6: repayment delays (most recent = PAY_0)
  - -1 = paid duly, 0 = revolving credit, 1–8 = months delayed
- BILL_AMT1 to BILL_AMT6: monthly statement balances (NTD)
- PAY_AMT1 to PAY_AMT6: actual monthly payments made (NTD)

RISK SIGNALS TO WATCH:
1. Multiple consecutive PAY_* values ≥ 1 → severe risk indicator
2. BILL_AMT consistently close to LIMIT_BAL → near credit exhaustion
3. PAY_AMT much lower than BILL_AMT → minimum/no payment pattern
4. Increasing BILL_AMT trend with flat/declining PAY_AMT → debt spiral
5. High LIMIT_BAL alone does NOT reduce risk if payment behavior is poor

OUTPUT FORMAT (strict JSON, no prose outside the JSON block):
{
  "risk_level": "LOW | MEDIUM | HIGH",
  "default_probability": <float 0.0–1.0>,
  "key_signals": [<string>, ...],
  "recommendation": <string>
}
```

---

## n8n Workflow File

**Location:** `agent/n8n_workflow.json`

### Nodes
| Node | Type | Purpose |
|---|---|---|
| `Credit Assessment Webhook` | Webhook | Entry point — POST trigger |
| `Validate & Normalize` | Set | Normalize field names; compute derived features |
| `Assess Credit Risk` | LLM Chain (Claude/GPT) | Core reasoning |
| `Parse JSON Output` | Code / JSON Parser | Enforce output schema |
| `Respond` | Respond to Webhook | Return result |

### Environment Variables (n8n Credentials)
| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API key (stored in n8n Credentials, not in JSON) |
| `OPENAI_API_KEY` | GPT-4o API key (alternative — stored in n8n Credentials) |

> **Security:** API keys must never appear in `n8n_workflow.json`. Use n8n's built-in credential manager.

---

## Example Assessment

**Input:** Client with 3-month payment delay, 90%+ credit utilization, minimal payments.

**Output:**
```json
{
  "risk_level": "HIGH",
  "default_probability": 0.74,
  "key_signals": [
    "PAY_0=2, PAY_2=2, PAY_3=1 — 3 consecutive months of payment delays",
    "BILL_AMT1 (98,000) is 81.7% of LIMIT_BAL (120,000) — near credit exhaustion",
    "PAY_AMT1 (3,000) covers only 3.1% of BILL_AMT1 — well below minimum due",
    "Upward trend in bill amounts over 6 months with flat payments"
  ],
  "recommendation": "Do not extend new credit. Place account on watchlist. Recommend collections outreach if delay reaches 3 months."
}
```

---

## Integration with ML Models

The agent does **not** call the R models at inference time (they run offline). Instead:

1. ML models establish **probability thresholds** during Phase 3.
2. Thresholds are encoded into the LLM system prompt as reference anchors.
3. The LLM reasons from raw feature values + domain knowledge, guided by those thresholds.

This architecture is fully functional without a live R runtime.
