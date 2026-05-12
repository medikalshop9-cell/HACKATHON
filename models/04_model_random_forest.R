# ============================================================
# 04_model_random_forest.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Train Random Forest classifier.
#          Use CV log-loss as penalized selection criterion.
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(caret))
suppressPackageStartupMessages(library(randomForest))
suppressPackageStartupMessages(library(pROC))
suppressPackageStartupMessages(library(smotefamily))

set.seed(42)

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
OUTPUT_DIR <- "models/outputs"
PLOTS_DIR  <- "models/outputs/plots"
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
train_encoded <- model.matrix(default ~ . - 1, data = train_raw) |> as.data.frame()
train_encoded$default <- as.integer(train_raw$default) - 1

smote_out   <- SMOTE(train_encoded[, -ncol(train_encoded)],
                     train_encoded$default, K = 5)
train_smote <- smote_out$data
train_smote$class <- factor(train_smote$class, levels = c(0, 1), labels = c("No", "Yes"))

cat("Post-SMOTE train size:", nrow(train_smote), "\n")

train_features <- setdiff(names(train_smote), "class")

align_to_train <- function(mat, ref_cols) {
  for (col in setdiff(ref_cols, names(mat))) mat[[col]] <- 0
  mat[, ref_cols, drop = FALSE]
}

# ------------------------------------------------------------
# 4. Train Random Forest with CV log-loss
# ------------------------------------------------------------
ctrl <- trainControl(
  method          = "cv",
  number          = 5,
  classProbs      = TRUE,
  summaryFunction = mnLogLoss,
  savePredictions = "final"
)

rf_grid <- expand.grid(mtry = c(4, 6, 8, 10))

model_rf <- train(
  class ~ .,
  data      = train_smote,
  method    = "rf",
  ntree     = 300,
  tuneGrid  = rf_grid,
  trControl = ctrl,
  metric    = "logLoss"
)

cat("Random Forest trained.\n")
print(model_rf)
cat("Best mtry:", model_rf$bestTune$mtry, "\n")

# ------------------------------------------------------------
# 5. Variable importance
# ------------------------------------------------------------
var_imp <- varImp(model_rf)$importance |>
  rownames_to_column("Feature") |>
  arrange(desc(Overall))

cat("\n=== Top 10 Variable Importances ===\n")
print(head(var_imp, 10))

write_csv(var_imp, file.path(OUTPUT_DIR, "rf_variable_importance.csv"))

# ------------------------------------------------------------
# 6. Validation set — threshold sweep (imbalanced data analysis)
# ------------------------------------------------------------
val_encoded <- model.matrix(default ~ . - 1, data = val_set) |> as.data.frame() |> align_to_train(train_features)
val_prob    <- predict(model_rf, newdata = val_encoded, type = "prob")[, "Yes"]
val_true    <- val_set$default

sweep_thresholds <- seq(0.10, 0.90, by = 0.15)

threshold_tbl <- do.call(rbind, lapply(sweep_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred, val_true, positive = "Yes")
  tibble(
    threshold   = t,
    accuracy    = round(cm_t$overall["Accuracy"],       4),
    recall      = round(cm_t$byClass["Sensitivity"],    4),
    precision   = round(cm_t$byClass["Pos Pred Value"], 4),
    f1          = round(cm_t$byClass["F1"],             4),
    specificity = round(cm_t$byClass["Specificity"],    4),
    fpr         = round(1 - cm_t$byClass["Specificity"],4)
  )
}))

cat("\n=== Threshold Sweep on Validation Set (Random Forest) ===\n")
cat("CV LogLoss:", round(min(model_rf$results$logLoss), 4), "\n\n")
print(as.data.frame(threshold_tbl), row.names = FALSE)

# Auto-select threshold maximising F1
fine_thresholds <- seq(0.10, 0.90, by = 0.01)
fine_f1 <- sapply(fine_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred, val_true, positive = "Yes")
  cm_t$byClass["F1"]
})
best_threshold <- fine_thresholds[which.max(fine_f1)]
cat(sprintf("\nAuto-selected threshold (best val F1): %.2f  (F1 = %.4f)\n",
            best_threshold, max(fine_f1, na.rm = TRUE)))

grey_n <- sum(val_prob >= 0.40 & val_prob <= 0.60)
cat(sprintf("Grey zone cases on val set (40-60%%): %d (%.1f%%)\n",
            grey_n, grey_n / length(val_prob) * 100))

# ------------------------------------------------------------
# 7. Test set evaluation (FINAL — use best_threshold from val)
# ------------------------------------------------------------
test_encoded <- model.matrix(default ~ . - 1, data = test_set) |> as.data.frame() |> align_to_train(train_features)

pred_prob  <- predict(model_rf, newdata = test_encoded, type = "prob")[, "Yes"]
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
saveRDS(model_rf, file.path(OUTPUT_DIR, "rf_model.rds"))

# ------------------------------------------------------------
# 8. Save plots
# ------------------------------------------------------------

# ROC curve
png(file.path(PLOTS_DIR, "rf_roc_curve.png"), width = 700, height = 600)
plot(roc_obj, col = "#1a9641", lwd = 2,
     main = sprintf("Random Forest — ROC Curve (AUC = %.4f)", auc(roc_obj)))
abline(a = 0, b = 1, lty = 2, col = "grey60")
dev.off()

# Confusion matrix heatmap
cm_tbl <- as.data.frame(cm$table)
names(cm_tbl) <- c("Predicted", "Actual", "Freq")
p_cm <- ggplot(cm_tbl, aes(x = Predicted, y = Actual, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), size = 7, fontface = "bold") +
  scale_fill_gradient(low = "#d4f1d4", high = "#1a9641") +
  labs(title = "Random Forest — Confusion Matrix",
       x = "Predicted", y = "Actual") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "none")
ggsave(file.path(PLOTS_DIR, "rf_confusion_matrix.png"), p_cm, width = 5, height = 4)

# Variable importance
p_imp <- var_imp |>
  slice_head(n = 20) |>
  ggplot(aes(x = reorder(Feature, Overall), y = Overall)) +
  geom_col(fill = "#1a9641") +
  coord_flip() +
  labs(title = "Random Forest — Top 20 Variable Importances",
       x = NULL, y = "Importance (Mean Decrease Gini)") +
  theme_minimal()
ggsave(file.path(PLOTS_DIR, "rf_variable_importance.png"), p_imp, width = 8, height = 6)

# mtry tuning curve
p_tune <- ggplot(model_rf$results, aes(x = mtry, y = logLoss)) +
  geom_line(color = "#1a9641", linewidth = 1) +
  geom_point(color = "#1a9641", size = 3) +
  labs(title = "Random Forest — CV Log-loss by mtry",
       x = "mtry", y = "CV Log-loss") +
  theme_minimal()
ggsave(file.path(PLOTS_DIR, "rf_mtry_tuning.png"), p_tune, width = 6, height = 4)

cat("Plots saved to:", PLOTS_DIR, "\n")

results_rf <- tibble(
  model      = "Random Forest",
  aic        = NA_real_,
  bic        = NA_real_,
  hqic       = NA_real_,
  cv_logloss = round(min(model_rf$results$logLoss), 4),
  auc_roc    = round(auc(roc_obj), 4),
  threshold  = best_threshold,
  accuracy   = round(cm$overall["Accuracy"], 4),
  f1         = round(cm$byClass["F1"], 4),
  precision  = round(cm$byClass["Precision"], 4),
  recall     = round(cm$byClass["Recall"], 4)
)

write_csv(results_rf, file.path(OUTPUT_DIR, "rf_results.csv"))

threshold_tbl$model <- "Random Forest"
write_csv(threshold_tbl, file.path(OUTPUT_DIR, "rf_threshold_sweep.csv"))

cat("Saved rf_model.rds, rf_results.csv, rf_threshold_sweep.csv\n")
