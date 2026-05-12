# Project Phases — Credit Assessment Agent
**Africa Business School, UM6P — Hackathon Capstone | May 2026**

---

## Overview

The project is split into two major parts delivered end-to-end within 24 hours.

```
Phase 0 → Repo Setup & Data Audit
Phase 1 → Data Cleaning & EDA
Phase 2 → Model Training (×3)
Phase 3 → Model Selection (AIC / BIC / HQIC / Log-loss)
Phase 4 → n8n Agent Build
Phase 5 → Integration & Demo Prep
```

---

## Phase 0 — Repository Setup & Data Audit
**Goal:** Establish reproducible project scaffold; confirm raw data integrity.

### Deliverables
- [x] `README.md` — project overview
- [x] `.github/copilot-instructions.md` — AI assistant conventions
- [x] `docs/plan/phase.md` — this file
- [x] `docs/dataset_reference.md` — variable dictionary
- [x] `docs/model_selection.md` — selection criteria rationale
- [x] `docs/agent_design.md` — n8n agent architecture
- [x] `models/` — R script stubs (01–06)
- [x] `agent/` — n8n workflow placeholder
- [x] `data/` — raw CSV in place

### Acceptance Criteria
- All directories exist and scripts are runnable (even if empty stubs)
- CSV row count = 30,000; column count = 25 (ID + 23 features + target)

---

## Phase 1 — Data Cleaning & Exploratory Data Analysis
**Goal:** Produce a clean, analysis-ready dataset and surface key patterns.

### Scripts
| File | Purpose |
|---|---|
| `models/01_data_cleaning.R` | Recode undocumented categories, cast factors, export clean CSV |
| `models/02_exploratory_analysis.R` | Distributions, correlations, class balance plots |

### Key Cleaning Steps
| Issue | Action |
|---|---|
| `EDUCATION` ∈ {0, 5, 6} | Recode → `4` (Others) |
| `MARRIAGE` = 0 | Recode → `3` (Others) |
| `PAY_*` = -2 | Recode → `-1` (paid duly) or separate factor level |
| All `PAY_*`, `SEX`, `EDUCATION`, `MARRIAGE` | Cast to `factor` |

### EDA Focus Areas
- Class imbalance visualization (22.1% default rate)
- `PAY_0`–`PAY_6` trend: consecutive delays as default predictor
- `LIMIT_BAL` vs default rate
- Correlation heatmap of bill/payment amounts
- Age and demographic breakdowns by default status

### Acceptance Criteria
- Clean dataset saved to `data/credit_clean.csv`
- No undocumented factor levels remain
- EDA plots exported to `docs/figures/`

---

## Phase 2 — Model Training
**Goal:** Train exactly three classifiers on the clean dataset using consistent pipelines.

### Train/Test Split
- 70% train / 30% test, **stratified** on `default.payment.next.month`
- `set.seed(42)` enforced globally
- SMOTE applied to training set only (not test set)

### Models
| Script | Model | Package |
|---|---|---|
| `models/03_model_logistic_regression.R` | Logistic Regression | `glm()` (base R) |
| `models/04_model_random_forest.R` | Random Forest | `randomForest` |
| `models/05_model_xgboost.R` | XGBoost | `xgboost` |

### Output per Model
Each script saves to `models/outputs/`:
- Fitted model object (`.rds`)
- Test-set predictions (`.csv`)
- Confusion matrix (`.txt`)
- ROC curve data (`.csv`)

### Acceptance Criteria
- All three models train without error
- AUC-ROC, Accuracy, F1, Precision, Recall computed for each
- For Logistic Regression: AIC, BIC, HQIC extracted from fitted object
- For RF/XGBoost: cross-validated log-loss computed as penalized criterion

---

## Phase 3 — Model Selection
**Goal:** Select the best-performing model using information-theoretic criteria — no assumption made in advance.

### Script
`models/06_model_comparison.R`

### Criteria
| Criterion | Formula | Use Case |
|---|---|---|
| AIC | $-2\ell + 2k$ | Favour predictive accuracy |
| BIC | $-2\ell + k \ln n$ | Favour parsimony |
| HQIC | $-2\ell + 2k \ln(\ln n)$ | Intermediate |
| CV Log-loss | $-\frac{1}{n}\sum \log \hat{p}_i$ | Tree models (no closed-form likelihood) |

### Selection Rule
The model with the **lowest penalized criterion** across majority of metrics wins. In case of tie, AUC-ROC is the tiebreaker.

### Deliverable
- `docs/model_selection.md` updated with actual results table
- Winner identified and justified

---

## Phase 4 — n8n Agent Build
**Goal:** Deploy a no-code LLM agent that accepts borrower data and returns a structured credit risk assessment.

### Script / File
`agent/n8n_workflow.json`

### Architecture
```
Webhook Trigger (POST /assess-credit)
      ↓
Set Node — parse & validate 23 input fields
      ↓
LLM Node (Claude / GPT)
— System prompt: credit risk reasoning framework
— User prompt: borrower JSON payload
      ↓
Output Parser — enforce JSON schema
      ↓
Respond to Webhook — return structured result
```

### Output Schema
```json
{
  "risk_level": "LOW | MEDIUM | HIGH",
  "default_probability": 0.0,
  "key_signals": ["signal_1", "signal_2"],
  "recommendation": "string"
}
```

### Acceptance Criteria
- Agent returns valid JSON for any valid 23-feature input
- Risk level correlates with ML model thresholds
- No API keys stored in workflow JSON

---

## Phase 5 — Integration & Demo Prep
**Goal:** Connect the full pipeline; prepare presentation materials.

### Tasks
- [ ] Update `README.md` results table with actual model metrics
- [ ] Export final model comparison summary to `docs/model_selection.md`
- [ ] Record a short demo of the n8n agent with a sample borrower
- [ ] Prepare slide deck (optional)

### Final Repo State
```
credit-assessment-agent/
├── .github/copilot-instructions.md
├── data/
│   ├── default_credit_card_clients.csv   (raw)
│   └── credit_clean.csv                  (after Phase 1)
├── models/
│   ├── 01_data_cleaning.R
│   ├── 02_exploratory_analysis.R
│   ├── 03_model_logistic_regression.R
│   ├── 04_model_random_forest.R
│   ├── 05_model_xgboost.R
│   ├── 06_model_comparison.R
│   └── outputs/
├── agent/
│   └── n8n_workflow.json
└── docs/
    ├── plan/phase.md
    ├── dataset_reference.md
    ├── model_selection.md
    ├── agent_design.md
    └── figures/
```
