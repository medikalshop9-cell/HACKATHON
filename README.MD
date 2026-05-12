# 🏦 Credit Assessment Agent
**Africa Business School, UM6P — Capstone Hackathon | May 2026**

> An end-to-end credit risk system combining three machine learning models trained in R with an AI-powered no-code agent built in n8n — all delivered in 24 hours.

---

## 📌 Project Overview

This project has two interconnected components:

1. **Predictive Modeling (R)** — Three ML classifiers trained on real-world credit card data to predict payment default.
2. **AI Credit Assessment Agent (n8n)** — A no-code LLM-powered agent that takes a new borrower's profile as input and returns a structured credit risk assessment in plain language.

Together, they form a complete pipeline from raw data to actionable lending decisions.

---

## 📂 Repository Structure

```
credit-assessment-agent/
│
├── data/
│   └── default_credit_card_clients.csv   # Source dataset (UCI ML Repository)
│
├── models/
│   ├── 01_data_cleaning.R                # Preprocessing & encoding fixes
│   ├── 02_exploratory_analysis.R         # EDA & visualizations
│   └── 06_model_comparison.R            # Performance benchmarking
│
├── agent/
│   └── n8n_workflow.json                 # Exported n8n agent workflow
│
├── docs/
│   └── dataset_reference.md              # Variable descriptions & encoding notes
│
└── README.md
```

---

## 🗃️ Dataset

| Field | Details |
|---|---|
| **Name** | Default of Credit Card Clients |
| **Source** | [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/350) |
| **Authors** | I-Cheng Yeh & Che-hui Lien (2009) |
| **DOI** | 10.24432/C55S3H |
| **Observations** | 30,000 credit card clients (Taiwan, Apr–Sep 2005) |
| **Features** | 23 input variables + 1 binary target |
| **Missing Values** | None |
| **License** | CC BY 4.0 |

### Target Variable

`default.payment.next.month`
- `1` → Client **defaulted** (failed to pay next month)
- `0` → Client **did not default**

### Key Feature Groups

| Group | Variables | Description |
|---|---|---|
| Demographics | `LIMIT_BAL`, `SEX`, `EDUCATION`, `MARRIAGE`, `AGE` | Client profile |
| Repayment Status | `PAY_0` → `PAY_6` | Monthly payment delays (Sep → Apr 2005) |
| Bill Amounts | `BILL_AMT1` → `BILL_AMT6` | Monthly statement balances |
| Payment Amounts | `PAY_AMT1` → `PAY_AMT6` | Monthly payments made |

### ⚠️ Data Cleaning Notes

Before modeling, the following must be addressed:

- **`EDUCATION`**: Values `0`, `5`, `6` are undocumented → recode to `4` (Others)
- **`MARRIAGE`**: Value `0` is undocumented → recode to `3` (Others)
- **`PAY_0–PAY_6`**: Value `-2` is undocumented → remove or recode
- All categorical variables are stored as integers; treat them as **factors**, not numeric

---

## 🤖 Part 1 — Predictive Models (R)

Three supervised classification models are trained and compared:

### Model 1: Logistic Regression
A baseline linear classifier. Interpretable coefficients make it useful for understanding which features drive default risk most strongly.

### Model 2: Random Forest
An ensemble of decision trees. Captures non-linear relationships and feature interactions. Outputs variable importance scores.

### Model 3: XGBoost
Gradient-boosted trees. Typically highest performance on tabular data. Tuned using cross-validation.

### Evaluation Metrics

All models are evaluated on a held-out test set using:
- Accuracy
- AUC-ROC
- Precision, Recall, F1-Score
- Confusion Matrix

> Class imbalance is handled via stratified splitting and, where necessary, class weighting or SMOTE.

---

## 🧠 Part 2 — AI Credit Assessment Agent (n8n)

### What It Does

The agent accepts a new borrower's information and returns a **plain-language credit risk assessment** — no code required from the end user.

### How It Works

```
User Input (borrower profile)
        ↓
  n8n Workflow Trigger
        ↓
  LLM Node (Claude / GPT)
  — Receives borrower data
  — Applies credit risk reasoning
  — References model logic & thresholds
        ↓
  Structured Risk Output
  — Risk level: Low / Medium / High
  — Key risk flags
  — Recommended decision
```

### Agent Inputs

The agent accepts the same 23 variables used in the ML models:

```
Credit limit, Age, Sex, Education, Marital status,
6 months of repayment history,
6 months of bill statement amounts,
6 months of payment amounts
```

### Agent Output (Example)

```
Risk Level     : HIGH
Default Probability : ~72%

Key Risk Signals:
  • 3 consecutive months of delayed payments (PAY_0, PAY_2, PAY_3)
  • Bill amount consistently exceeds 90% of credit limit
  • Payment amounts well below minimum due

Recommendation : Do not extend new credit. Flag for collections review.
```

### Built With
- **[n8n](https://n8n.io/)** — No-code workflow automation
- **Anthropic Claude** (via API) — LLM reasoning engine
- Prompt engineering based on model thresholds and variable reference documentation

---

## 🚀 Getting Started

### Prerequisites

**For the R models:**
```r
install.packages(c("tidyverse", "caret", "randomForest", "xgboost", "pROC", "smotefamily"))
```

**For the n8n agent:**
- n8n instance (self-hosted or cloud)
- Anthropic or OpenAI API key
- Import `agent/n8n_workflow.json` into your n8n workspace

### Running the Models

```r
# Step 1 — Clean the data
source("models/01_data_cleaning.R")

# Step 2 — Explore
source("models/02_exploratory_analysis.R")

# Step 3 — Train all three models
source("models/03_model_logistic_regression.R")
source("models/04_model_random_forest.R")
source("models/05_model_xgboost.R")

# Step 4 — Compare results
source("models/06_model_comparison.R")
```

---

## 📊 Results Summary

| Model | Accuracy | AUC-ROC | F1-Score |
|---|---|---|---|
| Logistic Regression | TBD | TBD | TBD |
| Random Forest | TBD | TBD | TBD |
| XGBoost | TBD | TBD | TBD |

*Results to be populated after training.*

---

## 📚 References

> Yeh, I-C., & Lien, C. (2009). The comparisons of data mining techniques for the predictive accuracy of probability of default of credit card clients. *Expert Systems with Applications*, 36(2), 2473–2480. https://doi.org/10.24432/C55S3H

---

## 👤 Author

**[Your Name]**
Africa Business School, Mohammed VI Polytechnic University (UM6P)
Hackathon Capstone Project — May 2026