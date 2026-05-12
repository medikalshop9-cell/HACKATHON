# ============================================================
# 03_model_logistic_regression.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Train Logistic Regression baseline classifier.
#          Extract AIC, BIC, HQIC. Save outputs.
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(caret))
suppressPackageStartupMessages(library(pROC))
suppressPackageStartupMessages(library(smotefamily))

set.seed(42)

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
OUTPUT_DIR  <- "models/outputs"
PLOTS_DIR   <- "models/outputs/plots"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(PLOTS_DIR,  recursive = TRUE, showWarnings = FALSE)

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

# ------------------------------------------------------------
# 1. Load pre-built splits (created by 01b_data_split.R)
#    NEVER re-split here — test set must stay completely locked
# ------------------------------------------------------------
if (!file.exists("data/split_train.csv")) {
  stop("Split files not found. Run models/01b_data_split.R first.")
}

train_raw <- load_split("data/split_train.csv")
val_set   <- load_split("data/split_validation.csv")
test_set  <- load_split("data/split_test.csv")

cat("Train:", nrow(train_raw), "| Validation:", nrow(val_set), "| Test:", nrow(test_set), "\n")

# ------------------------------------------------------------
# 3. SMOTE on training set only
# ------------------------------------------------------------
# caret requires numeric matrix for SMOTE — encode factors
train_encoded <- model.matrix(default ~ . - 1, data = train_raw) |> as.data.frame()
train_encoded$default <- as.integer(train_raw$default) - 1  # 0/1

smote_out   <- SMOTE(train_encoded[, -ncol(train_encoded)],
                     train_encoded$default, K = 5)
train_smote <- smote_out$data
train_smote$class <- factor(train_smote$class, levels = c(0, 1), labels = c("No", "Yes"))

cat("Post-SMOTE train size:", nrow(train_smote), "\n")
cat("Post-SMOTE class balance:\n")
print(table(train_smote$class))

# Record training feature columns so val/test can be aligned
train_features <- setdiff(names(train_smote), "class")

# Align an encoded matrix to training columns:
# add missing cols as 0, drop extra cols, fix column order
align_to_train <- function(mat, ref_cols) {
  for (col in setdiff(ref_cols, names(mat))) mat[[col]] <- 0
  mat[, ref_cols, drop = FALSE]
}

# ------------------------------------------------------------
# 4. Train logistic regression
# ------------------------------------------------------------
ctrl <- trainControl(
  method          = "cv",
  number          = 5,
  classProbs      = TRUE,
  summaryFunction = mnLogLoss,
  savePredictions = "final"
)

model_logit <- train(
  class ~ .,
  data      = train_smote,
  method    = "glm",
  family    = "binomial",
  trControl = ctrl,
  metric    = "logLoss"
)

cat("Logistic Regression trained.\n")
print(model_logit)

# ------------------------------------------------------------
# 5. Information criteria (AIC / BIC / HQIC)
# ------------------------------------------------------------
glm_fit  <- model_logit$finalModel
ll       <- as.numeric(logLik(glm_fit))
k        <- length(coef(glm_fit))
n        <- nrow(train_smote)

aic_val  <- AIC(glm_fit)
bic_val  <- BIC(glm_fit)
hqic_val <- -2 * ll + 2 * k * log(log(n))

cat("\n=== Information Criteria ===\n")
cat("AIC  :", round(aic_val,  2), "\n")
cat("BIC  :", round(bic_val,  2), "\n")
cat("HQIC :", round(hqic_val, 2), "\n")

# ------------------------------------------------------------
# 6. Validation set — threshold sweep (imbalanced data analysis)
#    Evaluate model performance across thresholds 0.10 – 0.90
#    step 0.15 to diagnose imbalance effect.
#    Then pick best threshold on val set for final test evaluation.
# ------------------------------------------------------------
val_encoded  <- model.matrix(default ~ . - 1, data = val_set) |> as.data.frame() |> align_to_train(train_features)
val_prob     <- predict(model_logit, newdata = val_encoded, type = "prob")[, "Yes"]
val_true     <- val_set$default

sweep_thresholds <- seq(0.10, 0.90, by = 0.15)

threshold_tbl <- do.call(rbind, lapply(sweep_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred, val_true, positive = "Yes")
  tibble(
    threshold  = t,
    accuracy   = round(cm_t$overall["Accuracy"],        4),
    recall     = round(cm_t$byClass["Sensitivity"],     4),  # = recall
    precision  = round(cm_t$byClass["Pos Pred Value"],  4),
    f1         = round(cm_t$byClass["F1"],              4),
    specificity= round(cm_t$byClass["Specificity"],     4),
    fpr        = round(1 - cm_t$byClass["Specificity"], 4)   # false positive rate
  )
}))

cat("\n=== Threshold Sweep on Validation Set (Logistic Regression) ===\n")
cat("AUC-ROC  :", round(auc(roc(val_true, val_prob, levels = c("No","Yes"), quiet=TRUE)), 4), "\n")
cat("CV LogLoss:", round(min(model_logit$results$logLoss), 4), "\n")
cat("AIC      :", round(aic_val, 2), "  BIC:", round(bic_val, 2), "  HQIC:", round(hqic_val, 2), "\n\n")
print(as.data.frame(threshold_tbl), row.names = FALSE)

# Auto-select threshold that maximises F1 on validation set
fine_thresholds <- seq(0.10, 0.90, by = 0.01)
fine_f1 <- sapply(fine_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred, val_true, positive = "Yes")
  cm_t$byClass["F1"]
})
best_threshold <- fine_thresholds[which.max(fine_f1)]
cat(sprintf("\nAuto-selected threshold (best val F1): %.2f  (F1 = %.4f)\n",
            best_threshold, max(fine_f1, na.rm = TRUE)))

# Grey zone counts on validation set
grey_n <- sum(val_prob >= 0.40 & val_prob <= 0.60)
cat(sprintf("Grey zone cases on val set (40-60%%): %d (%.1f%%)\n",
            grey_n, grey_n / length(val_prob) * 100))

# ------------------------------------------------------------
# 7. Test set evaluation (FINAL — use best_threshold from val)
# ------------------------------------------------------------
test_encoded <- model.matrix(default ~ . - 1, data = test_set) |> as.data.frame() |> align_to_train(train_features)

pred_prob  <- predict(model_logit, newdata = test_encoded, type = "prob")[, "Yes"]
pred_class <- factor(ifelse(pred_prob >= best_threshold, "Yes", "No"), levels = c("No", "Yes"))
true_class <- test_set$default

cm      <- confusionMatrix(pred_class, true_class, positive = "Yes")
roc_obj <- roc(true_class, pred_prob, levels = c("No", "Yes"))

cat("\n=== Test Set Performance (threshold =", best_threshold, ") ===\n")
print(cm)
cat("AUC-ROC:", round(auc(roc_obj), 4), "\n")

# ------------------------------------------------------------
# 7. Save outputs
# ------------------------------------------------------------
saveRDS(model_logit, file.path(OUTPUT_DIR, "logit_model.rds"))

# ------------------------------------------------------------
# 8. Save plots
# ------------------------------------------------------------

# ROC curve
png(file.path(PLOTS_DIR, "logit_roc_curve.png"), width = 700, height = 600)
plot(roc_obj, col = "#2166ac", lwd = 2,
     main = sprintf("Logistic Regression — ROC Curve (AUC = %.4f)", auc(roc_obj)))
abline(a = 0, b = 1, lty = 2, col = "grey60")
dev.off()

# Confusion matrix heatmap
cm_tbl <- as.data.frame(cm$table)
names(cm_tbl) <- c("Predicted", "Actual", "Freq")
p_cm <- ggplot(cm_tbl, aes(x = Predicted, y = Actual, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), size = 7, fontface = "bold") +
  scale_fill_gradient(low = "#d1e5f0", high = "#2166ac") +
  labs(title = "Logistic Regression — Confusion Matrix",
       x = "Predicted", y = "Actual") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none")
ggsave(file.path(PLOTS_DIR, "logit_confusion_matrix.png"), p_cm, width = 5, height = 4)

# Coefficient plot (top 20 by absolute value)
coef_df <- broom::tidy(glm_fit) |>
  filter(term != "(Intercept)") |>
  arrange(desc(abs(estimate))) |>
  slice_head(n = 20)
p_coef <- ggplot(coef_df, aes(x = reorder(term, estimate), y = estimate,
                              fill = estimate > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_fill_manual(values = c("#d73027", "#4575b4")) +
  labs(title = "Logistic Regression — Top 20 Coefficients",
       x = NULL, y = "Coefficient") +
  theme_minimal()
ggsave(file.path(PLOTS_DIR, "logit_coefficients.png"), p_coef, width = 8, height = 6)

cat("Plots saved to:", PLOTS_DIR, "\n")

results_logit <- tibble(
  model     = "Logistic Regression",
  aic       = round(aic_val,  2),
  bic       = round(bic_val,  2),
  hqic      = round(hqic_val, 2),
  cv_logloss = round(min(model_logit$results$logLoss), 4),
  auc_roc   = round(auc(roc_obj), 4),
  threshold  = best_threshold,
  accuracy  = round(cm$overall["Accuracy"], 4),
  f1        = round(cm$byClass["F1"], 4),
  precision = round(cm$byClass["Precision"], 4),
  recall    = round(cm$byClass["Recall"], 4)
)

write_csv(results_logit, file.path(OUTPUT_DIR, "logit_results.csv"))

# Save full threshold sweep to CSV for reporting
threshold_tbl$model <- "Logistic Regression"
write_csv(threshold_tbl, file.path(OUTPUT_DIR, "logit_threshold_sweep.csv"))

cat("Saved logit_model.rds, logit_results.csv, logit_threshold_sweep.csv\n")
