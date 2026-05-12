# Model Selection — Criteria & Methodology
**Credit Assessment Agent | Africa Business School, UM6P**

---

## Philosophy

Model selection is **data-driven, not assumed**. We train exactly three classifiers and let
information-theoretic and cross-validation criteria determine the winner. No model is
declared "best" before the data speaks.

> "All models are wrong, but some are useful." — George Box

---

## The Three Candidate Models

| # | Model | Script | Rationale |
|---|---|---|---|
| 1 | Logistic Regression | `03_model_logistic_regression.R` | Linear baseline; interpretable coefficients; supports closed-form AIC/BIC/HQIC |
| 2 | Random Forest | `04_model_random_forest.R` | Non-parametric ensemble; handles feature interactions; outputs variable importance |
| 3 | XGBoost | `05_model_xgboost.R` | Gradient-boosted trees; typically top tabular performance; tunable via CV |

---

## Selection Criteria

### For Logistic Regression (parametric — closed-form likelihood available)

| Criterion | Formula | Penalizes | Prefer When |
|---|---|---|---|
| **AIC** | $-2\hat{\ell} + 2k$ | # parameters ($k$) | Prediction accuracy matters most |
| **BIC** | $-2\hat{\ell} + k \ln n$ | # parameters × $\ln n$ | Parsimony / generalizability matters |
| **HQIC** | $-2\hat{\ell} + 2k \ln(\ln n)$ | Intermediate penalty | Balance between AIC and BIC |

Where:
- $\hat{\ell}$ = maximized log-likelihood of the fitted model
- $k$ = number of estimated parameters
- $n$ = number of training observations

**Lower is better** for all three criteria.

#### R Extraction
```r
aic  <- AIC(model_logit)
bic  <- BIC(model_logit)
n    <- nobs(model_logit)
k    <- length(coef(model_logit))
hqic <- -2 * as.numeric(logLik(model_logit)) + 2 * k * log(log(n))
```

---

### For Random Forest & XGBoost (non-parametric — no closed-form likelihood)

Closed-form AIC/BIC/HQIC cannot be computed. We use **cross-validated log-loss** as
the equivalent penalized predictive criterion:

$$\text{CV Log-loss} = -\frac{1}{n} \sum_{i=1}^{n} \left[ y_i \log \hat{p}_i + (1 - y_i) \log (1 - \hat{p}_i) \right]$$

- Computed over $k=5$ stratified CV folds on the **training set only**
- Lower log-loss = better probabilistic calibration = more reliable predictions

#### R Extraction (caret)
```r
ctrl <- trainControl(
  method        = "cv",
  number        = 5,
  classProbs    = TRUE,
  summaryFunction = mnLogLoss,
  savePredictions = "final"
)
```

---

## Unified Comparison Table

The `06_model_comparison.R` script populates this table at runtime:

| Metric | Logistic Regression | Random Forest | XGBoost |
|---|---|---|---|
| AIC | — | N/A | N/A |
| BIC | — | N/A | N/A |
| HQIC | — | N/A | N/A |
| CV Log-loss | — | — | — |
| AUC-ROC (test) | — | — | — |
| Accuracy (test) | — | — | — |
| F1-Score (test) | — | — | — |
| Precision (test) | — | — | — |
| Recall (test) | — | — | — |

*Table populated after `source("models/06_model_comparison.R")` is run.*

---

## Selection Rule

1. **Primary:** Model with the lowest penalized criterion (AIC/BIC/HQIC for logistic;
   CV log-loss for tree models) across the **majority of applicable criteria**.
2. **Tiebreaker:** Highest AUC-ROC on the held-out test set.
3. **Override condition:** If the selected model has Recall < 0.50 for the positive class
   (defaults), escalate to the model with the best Recall — credit risk applications
   penalize missed defaults more than false alarms.

---

## Class Imbalance Handling

| Step | Action |
|---|---|
| Train/test split | Stratified on target (70/30) |
| Training set | SMOTE applied (`smotefamily::SMOTE`) |
| Test set | **No SMOTE** — must reflect real-world distribution |
| Threshold | Default 0.5; tune per model on validation fold |

---

## Results (To Be Filled)

**Winner:** TBD — determined by `06_model_comparison.R`

**Justification:** TBD

---

## References

- Akaike, H. (1974). A new look at the statistical model identification. *IEEE TAC*, 19(6), 716–723.
- Schwarz, G. (1978). Estimating the dimension of a model. *Annals of Statistics*, 6(2), 461–464.
- Hannan, E. J., & Quinn, B. G. (1979). The determination of the order of an autoregression. *JRSS-B*, 41(2), 190–195.
- Chawla, N. V. et al. (2002). SMOTE: Synthetic Minority Over-sampling Technique. *JAIR*, 16, 321–357.
