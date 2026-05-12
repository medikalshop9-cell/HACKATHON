# GitHub Copilot Instructions — Credit Assessment Agent

## Project Context

This is a 24-hour Hackathon Capstone project for **Africa Business School, UM6P (May 2026)**.
The goal is an end-to-end credit risk system:
- **Part 1 — Predictive Models (R):** Three ML classifiers trained on the UCI Credit Card Default dataset.
- **Part 2 — AI Agent (n8n):** An LLM-powered no-code agent that explains credit risk in plain language.

---

## Stack & Languages

| Layer | Technology |
|---|---|
| Modeling | R (tidyverse, caret, randomForest, xgboost, pROC, smotefamily) |
| Agent | n8n (self-hosted or cloud) |
| LLM | Anthropic Claude or OpenAI GPT via API |
| Data | CSV — UCI ML Repository (30,000 rows, 23 features) |

---

## Coding Conventions (R)

- Use `tidyverse` style: pipe (`|>`) preferred over nested calls.
- All categorical variables (`SEX`, `EDUCATION`, `MARRIAGE`, `PAY_*`) must be cast to **factors** before modeling.
- Data cleaning (recoding undocumented categories) lives exclusively in `models/01_data_cleaning.R`.
- No raw CSV path hardcoding — use a `config` or top-level `DATA_PATH` variable.
- Models are split: one script per model (`03_`, `04_`, `05_`), comparison in `06_`.
- Use `set.seed(42)` for all random operations to ensure reproducibility.

---

## Model Selection Philosophy

Model selection is **data-driven, not assumed**. The final model is chosen using information criteria:

- **AIC** (Akaike Information Criterion) — preferred when prediction accuracy matters most.
- **BIC** (Bayesian Information Criterion) — preferred when parsimony/generalizability matters.
- **HQIC** (Hannan-Quinn) — intermediate between AIC and BIC.

For tree-based models (Random Forest, XGBoost) where closed-form likelihood is unavailable, use cross-validated log-loss as the equivalent penalized criterion.

**Do not hard-code a "best" model.** The comparison script (`06_model_comparison.R`) decides the winner.

---

## Dataset

- **File:** `data/default_credit_card_clients.csv`
- **Target:** `default.payment.next.month` — binary (0 = no default, 1 = default)
- **Class imbalance:** ~22% positive class — handle via stratified split + SMOTE where needed.
- **Cleaning rules:**
  - `EDUCATION` values `{0, 5, 6}` → recode to `4` (Others)
  - `MARRIAGE` value `{0}` → recode to `3` (Others)
  - `PAY_*` value `-2` → recode or remove (undocumented)

---
 ## Performance Metrics for Managers
Do not just report Accuracy. Please provide a Performance Dashboard including:
*Hint: Calculate Profitability = (True Positives × Interest)- (False Positives × Loan Principal).
Metric
Model A Model B Model C
AUC-ROC
0.XX
False Positive Rate XX%
Profitability Index* $XXX
0.XX
XX%
$XXX
0.XX
XX%
$XXX

---
## n8n Agent

- Workflow file: `agent/n8n_workflow.json`
- Accepts all 23 feature variables as JSON input.
- Returns structured output: `risk_level`, `default_probability`, `key_signals[]`, `recommendation`.
- Prompt engineering references variable descriptions from `docs/dataset_reference.md`.

---

## What Copilot Should Help With

- Writing clean, idiomatic R code for preprocessing, EDA, and modeling.
- Structuring `caret` train/test pipelines.
- Computing AIC/BIC/HQIC from fitted model objects.
- Writing n8n-compatible JSON schemas.
- Drafting LLM system prompts grounded in the dataset's domain logic.

## What Copilot Should NOT Do

- Change the number of models (always exactly 3).
- Skip the data cleaning step before modeling.
- Assume one model will outperform — let the criteria decide.
- Hardcode API keys or credentials anywhere in the repo.
