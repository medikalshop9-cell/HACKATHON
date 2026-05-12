# ============================================================
# 03b_logistic_vif_analysis.R
# Multicollinearity diagnostics for Logistic Regression.
# Uses VIF (Variance Inflation Factor) on the TRAINING set.
# Then compares threshold sweep: full model vs. reduced model
# (dropping BILL_AMT2-6 which are highly correlated with BILL_AMT1).
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(car))       # vif()
suppressPackageStartupMessages(library(caret))
suppressPackageStartupMessages(library(pROC))
suppressPackageStartupMessages(library(smotefamily))

set.seed(42)

OUTPUT_DIR <- "models/outputs"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

PAY_COLS <- c("PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")

load_split <- function(path) {
  read_csv(path, show_col_types = FALSE) |>
    mutate(
      default   = factor(default,   levels = c("No", "Yes")),
      SEX       = factor(SEX),
      EDUCATION = factor(EDUCATION),
      MARRIAGE  = factor(MARRIAGE),
      across(all_of(PAY_COLS), factor)
    )
}

train_raw <- load_split("data/split_train.csv")
val_set   <- load_split("data/split_validation.csv")

# ============================================================
# 1. VIF — numeric predictors only
#    Factors (SEX, EDUCATION, MARRIAGE, PAY_*) are categorical
#    and do not need VIF. The multicollinearity concern is
#    BILL_AMT1-6 and PAY_AMT1-6 (continuous money amounts).
#    VIF_j = 1 / (1 - R^2) from regressing predictor j on all others.
# ============================================================
cat("=== VIF Analysis — Numeric Predictors (Full Model) ===\n\n")

num_vars <- c("LIMIT_BAL", "AGE",
              "BILL_AMT1","BILL_AMT2","BILL_AMT3","BILL_AMT4","BILL_AMT5","BILL_AMT6",
              "PAY_AMT1", "PAY_AMT2", "PAY_AMT3", "PAY_AMT4", "PAY_AMT5", "PAY_AMT6")

X_num <- as.matrix(train_raw[, num_vars])

# Compute VIF for each predictor via R^2 from OLS regression on all others
vif_numeric <- sapply(seq_along(num_vars), function(j) {
  y_j <- X_num[, j]
  X_j <- X_num[, -j]
  r2  <- summary(lm(y_j ~ X_j))$r.squared
  round(1 / (1 - r2), 2)
})
names(vif_numeric) <- num_vars

vif_tbl <- tibble(Feature = num_vars, VIF = vif_numeric) |>
  arrange(desc(VIF))

cat("--- Numeric predictor VIFs ---\n")
print(as.data.frame(vif_tbl), row.names = FALSE)

cat("\n  Rule of thumb: VIF > 5 = moderate concern | VIF > 10 = severe\n")

high_vif   <- vif_tbl |> filter(VIF > 5)
severe_vif <- vif_tbl |> filter(VIF > 10)

cat("\n--- Moderate multicollinearity (VIF > 5) ---\n")
if (nrow(high_vif) > 0) print(as.data.frame(high_vif), row.names = FALSE) else cat("None.\n")

cat("\n--- Severe multicollinearity (VIF > 10) ---\n")
if (nrow(severe_vif) > 0) print(as.data.frame(severe_vif), row.names = FALSE) else cat("None.\n")

write_csv(vif_tbl, file.path(OUTPUT_DIR, "logit_vif_full.csv"))
cat("\nSaved logit_vif_full.csv\n")

# Also print pairwise correlations for BILL_AMT block
cat("\n--- Pairwise correlations: BILL_AMT1-6 ---\n")
bill_cor <- cor(train_raw[, paste0("BILL_AMT", 1:6)])
print(round(bill_cor, 3))

cat("\n--- Pairwise correlations: PAY_AMT1-6 ---\n")
pay_cor <- cor(train_raw[, paste0("PAY_AMT", 1:6)])
print(round(pay_cor, 3))

# ============================================================
# 2. Reduced model VIF — drop BILL_AMT2–6 (keep only BILL_AMT1)
# ============================================================
cat("\n=== VIF Analysis — Reduced Model (BILL_AMT2–6 removed) ===\n\n")

num_vars_red <- c("LIMIT_BAL", "AGE",
                  "BILL_AMT1",
                  "PAY_AMT1","PAY_AMT2","PAY_AMT3","PAY_AMT4","PAY_AMT5","PAY_AMT6")

X_red_num <- as.matrix(train_raw[, num_vars_red])

vif_red_vals <- sapply(seq_along(num_vars_red), function(j) {
  y_j <- X_red_num[, j]
  X_j <- X_red_num[, -j]
  r2  <- summary(lm(y_j ~ X_j))$r.squared
  round(1 / (1 - r2), 2)
})
names(vif_red_vals) <- num_vars_red

vif_red_tbl <- tibble(Feature = num_vars_red, VIF = vif_red_vals) |> arrange(desc(VIF))

cat("--- Reduced model VIF (BILL_AMT2-6 removed) ---\n")
print(as.data.frame(vif_red_tbl), row.names = FALSE)

still_high <- vif_red_tbl |> filter(VIF > 5)
cat("\n--- Still high after reduction (VIF > 5) ---\n")
if (nrow(still_high) > 0) print(as.data.frame(still_high), row.names = FALSE) else cat("None — multicollinearity resolved.\n")

write_csv(vif_red_tbl, file.path(OUTPUT_DIR, "logit_vif_reduced.csv"))
cat("\nSaved logit_vif_reduced.csv\n")

# Also prepare X_full and X_red for the comparison section (needed below)
X_full <- model.matrix(default ~ . - 1, data = train_raw)
nzv_idx <- caret::nearZeroVar(X_full)
if (length(nzv_idx) > 0) X_full <- X_full[, -nzv_idx]
lc <- caret::findLinearCombos(X_full)
if (!is.null(lc$remove)) X_full <- X_full[, -lc$remove]

train_reduced <- train_raw |> select(-BILL_AMT2, -BILL_AMT3, -BILL_AMT4, -BILL_AMT5, -BILL_AMT6)
val_reduced   <- val_set   |> select(-BILL_AMT2, -BILL_AMT3, -BILL_AMT4, -BILL_AMT5, -BILL_AMT6)

X_red <- model.matrix(default ~ . - 1, data = train_reduced)
nzv_r <- caret::nearZeroVar(X_red)
if (length(nzv_r) > 0) X_red <- X_red[, -nzv_r]
lc_r  <- caret::findLinearCombos(X_red)
if (!is.null(lc_r$remove)) X_red <- X_red[, -lc_r$remove]

# ============================================================
# 3. Threshold sweep: Full vs. Reduced (on val set, no SMOTE)
#    Use glm.fit on the cleaned matrices for prediction.
# ============================================================
cat("\n=== Threshold Sweep Comparison: Full vs. Reduced Model ===\n")
cat("(Validation set | no SMOTE)\n\n")

sweep <- seq(0.10, 0.90, by = 0.15)

# Fit glm.fit on clean training matrices
y_bin <- as.integer(train_raw$default) - 1   # 0/1

glm_full_fit    <- glm.fit(X_full, y_bin, family = binomial())
glm_reduced_fit <- glm.fit(X_red,  y_bin, family = binomial())

# Prediction helper: align val matrix to training cols, then predict
predict_glmfit <- function(fit, X_train_cols, val_data) {
  X_val <- model.matrix(default ~ . - 1, data = val_data)
  # align columns
  missing_cols <- setdiff(X_train_cols, colnames(X_val))
  if (length(missing_cols) > 0) {
    extra <- matrix(0, nrow = nrow(X_val), ncol = length(missing_cols),
                    dimnames = list(NULL, missing_cols))
    X_val <- cbind(X_val, extra)
  }
  X_val <- X_val[, X_train_cols, drop = FALSE]
  # linear predictor -> probabilities
  eta <- X_val %*% fit$coefficients
  as.vector(1 / (1 + exp(-eta)))
}

eval_sweep_mat <- function(fit, X_train, val_data, label) {
  prob  <- predict_glmfit(fit, colnames(X_train), val_data)
  truth <- val_data$default
  bind_rows(lapply(sweep, function(t) {
    pred <- factor(ifelse(prob >= t, "Yes", "No"), levels = c("No", "Yes"))
    cm   <- confusionMatrix(pred, truth, positive = "Yes")
    tibble(
      model     = label,
      threshold = t,
      accuracy  = round(cm$overall["Accuracy"],       4),
      recall    = round(cm$byClass["Sensitivity"],    4),
      precision = round(cm$byClass["Pos Pred Value"], 4),
      f1        = round(cm$byClass["F1"],             4),
      fpr       = round(1 - cm$byClass["Specificity"],4)
    )
  }))
}

full_sweep    <- eval_sweep_mat(glm_full_fit,    X_full, val_set,     "Full (all BILL_AMT)")
reduced_sweep <- eval_sweep_mat(glm_reduced_fit, X_red,  val_reduced, "Reduced (BILL_AMT1 only)")

cat("--- Full model ---\n")
print(as.data.frame(full_sweep    |> select(-model)), row.names = FALSE)
cat("\n--- Reduced model (BILL_AMT2-6 dropped) ---\n")
print(as.data.frame(reduced_sweep |> select(-model)), row.names = FALSE)

# AUC comparison — predict probabilities for each model, then compute AUC
prob_full    <- predict_glmfit(glm_full_fit,    colnames(X_full), val_set)
prob_reduced <- predict_glmfit(glm_reduced_fit, colnames(X_red),  val_reduced)

roc_full    <- pROC::roc(val_set$default,     prob_full,    levels = c("No","Yes"), quiet = TRUE)
roc_reduced <- pROC::roc(val_reduced$default, prob_reduced, levels = c("No","Yes"), quiet = TRUE)

auc_full    <- as.numeric(pROC::auc(roc_full))
auc_reduced <- as.numeric(pROC::auc(roc_reduced))

cat(sprintf("\nAUC-ROC  Full model   : %.4f\n", auc_full))
cat(sprintf("AUC-ROC  Reduced model: %.4f\n", auc_reduced))
cat(sprintf("AUC difference        : %+.4f\n", auc_reduced - auc_full))

comparison <- bind_rows(full_sweep, reduced_sweep) |> arrange(threshold, model)
write_csv(comparison, file.path(OUTPUT_DIR, "logit_vif_threshold_comparison.csv"))
cat("\nSaved logit_vif_threshold_comparison.csv\n")
