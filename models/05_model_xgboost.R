# ============================================================
# 05_model_xgboost.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Train XGBoost classifier.
#          Use CV log-loss as penalized selection criterion.
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(caret))
suppressPackageStartupMessages(library(xgboost))
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
# 4. Train XGBoost directly via xgb.cv + grid search
#    caret's xgbTree integration crashes with twoClassSummary
#    on some data configurations. Use xgboost natively instead.
# ------------------------------------------------------------

# Clean column names (xgboost rejects brackets, commas, spaces)
clean_names <- function(x) gsub("[^A-Za-z0-9_]", "_", x)
names(train_smote) <- clean_names(names(train_smote))
train_features     <- setdiff(names(train_smote), "class")

X_train <- as.matrix(train_smote[, train_features])
y_train <- as.integer(train_smote$class == "Yes")

dtrain <- xgb.DMatrix(data = X_train, label = y_train)

# Grid search: 2 × 2 × 2 = 8 combos
xgb_grid <- expand.grid(
  nrounds   = c(100, 200),
  max_depth = c(4, 6),
  eta       = c(0.05, 0.1)
)

cat("Running xgb.cv grid search (", nrow(xgb_grid), "combos × 5 folds)...\n")

cv_results <- lapply(seq_len(nrow(xgb_grid)), function(i) {
  p <- xgb_grid[i, ]
  cv <- xgb.cv(
    params = list(
      objective        = "binary:logistic",
      eval_metric      = "auc",
      max_depth        = p$max_depth,
      eta              = p$eta,
      subsample        = 0.8,
      colsample_bytree = 0.8,
      min_child_weight = 1
    ),
    data       = dtrain,
    nrounds    = p$nrounds,
    nfold      = 5,
    verbose    = 0,
    early_stopping_rounds = 20
  )
  best_auc <- max(cv$evaluation_log$test_auc_mean)
  cat(sprintf("  nrounds=%d max_depth=%d eta=%.2f  -> CV AUC=%.4f\n",
              p$nrounds, p$max_depth, p$eta, best_auc))
  list(params = p, cv_auc = best_auc, best_iter = cv$best_iteration)
})

best_idx    <- which.max(sapply(cv_results, `[[`, "cv_auc"))
best_params <- cv_results[[best_idx]]$params
best_iter   <- max(cv_results[[best_idx]]$best_iter, 1)
cv_auc_best <- cv_results[[best_idx]]$cv_auc

cat(sprintf("\nBest: nrounds=%d max_depth=%d eta=%.2f  CV AUC=%.4f\n",
            best_params$nrounds, best_params$max_depth, best_params$eta, cv_auc_best))

# Fit final model on full SMOTE train
model_xgb <- xgb.train(
  params = list(
    objective        = "binary:logistic",
    eval_metric      = "auc",
    max_depth        = best_params$max_depth,
    eta              = best_params$eta,
    subsample        = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 1
  ),
  data    = dtrain,
  nrounds = best_iter,
  verbose = 0
)

cat("XGBoost final model trained.\n")

# CV log-loss: rerun best config with logloss metric
cv_ll <- xgb.cv(
  params = list(
    objective        = "binary:logistic",
    eval_metric      = "logloss",
    max_depth        = best_params$max_depth,
    eta              = best_params$eta,
    subsample        = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 1
  ),
  data    = dtrain,
  nrounds = best_iter,
  nfold   = 5,
  verbose = 0
)
cv_logloss_val <- cv_ll$evaluation_log$test_logloss_mean[best_iter]
cat(sprintf("CV Log-loss (best iter): %.4f\n", cv_logloss_val))

# Store cv_results table for plotting
cv_tbl <- bind_rows(lapply(cv_results, function(r) {
  tibble(nrounds = r$params$nrounds, max_depth = r$params$max_depth,
         eta = r$params$eta, cv_auc = r$cv_auc)
}))

# ------------------------------------------------------------
# 5. Variable importance (xgboost native)
# ------------------------------------------------------------
imp_mat <- xgb.importance(model = model_xgb)
var_imp <- as_tibble(imp_mat) |>
  rename(Feature = Feature, Overall = Gain) |>
  arrange(desc(Overall))

cat("\n=== Top 10 Variable Importances ===\n")
print(head(var_imp, 10))

write_csv(var_imp, file.path(OUTPUT_DIR, "xgb_variable_importance.csv"))

# ------------------------------------------------------------
# 6. Helper: build xgb DMatrix aligned to train columns
# ------------------------------------------------------------
make_xgb_matrix <- function(df, ref_cols) {
  mat <- model.matrix(default ~ . - 1, data = df) |> as.data.frame()
  names(mat) <- clean_names(names(mat))
  for (col in setdiff(ref_cols, names(mat))) mat[[col]] <- 0
  mat <- mat[, ref_cols, drop = FALSE]
  xgb.DMatrix(as.matrix(mat))
}

# ------------------------------------------------------------
# 7. Validation set — threshold sweep + best threshold
# ------------------------------------------------------------
dval     <- make_xgb_matrix(val_set, train_features)
val_prob <- predict(model_xgb, dval)
val_true <- val_set$default

sweep_thresholds <- seq(0.10, 0.90, by = 0.15)

threshold_tbl <- do.call(rbind, lapply(sweep_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  cm_t <- confusionMatrix(pred, val_true, positive = "Yes")
  data.frame(
    threshold = t,
    accuracy  = round(cm_t$overall["Accuracy"],        4),
    recall    = round(cm_t$byClass["Sensitivity"],     4),
    precision = round(cm_t$byClass["Pos Pred Value"],  4),
    f1        = round(cm_t$byClass["F1"],              4),
    specificity = round(cm_t$byClass["Specificity"],   4),
    fpr       = round(1 - cm_t$byClass["Specificity"], 4)
  )
}))

cat("\n=== Threshold Sweep (Validation Set) ===\n")
print(threshold_tbl, row.names = FALSE)

write_csv(threshold_tbl |> mutate(model = "XGBoost"),
          file.path(OUTPUT_DIR, "xgb_threshold_sweep.csv"))

# Auto-select best F1 threshold from fine sweep
fine_thresholds <- seq(0.20, 0.70, by = 0.01)
f1_scores  <- sapply(fine_thresholds, function(t) {
  pred <- factor(ifelse(val_prob >= t, "Yes", "No"), levels = c("No", "Yes"))
  confusionMatrix(pred, val_true, positive = "Yes")$byClass["F1"]
})
best_threshold <- fine_thresholds[which.max(f1_scores)]
cat(sprintf("\nOptimal threshold (val F1): %.2f  (F1 = %.4f)\n",
            best_threshold, max(f1_scores, na.rm = TRUE)))

# ------------------------------------------------------------
# 8. Test set evaluation (FINAL)
# ------------------------------------------------------------
dtest      <- make_xgb_matrix(test_set, train_features)
pred_prob  <- predict(model_xgb, dtest)
pred_class <- factor(ifelse(pred_prob >= best_threshold, "Yes", "No"), levels = c("No", "Yes"))
true_class <- test_set$default

cm      <- confusionMatrix(pred_class, true_class, positive = "Yes")
roc_obj <- roc(true_class, pred_prob, levels = c("No", "Yes"))

cat("\n=== Test Set Performance (threshold =", best_threshold, ") ===\n")
print(cm)
cat("AUC-ROC:", round(auc(roc_obj), 4), "\n")

# ------------------------------------------------------------
# 9. Save model + results
# ------------------------------------------------------------
xgb.save(model_xgb, file.path(OUTPUT_DIR, "xgb_model.bin"))
saveRDS(list(model = model_xgb, train_features = train_features,
             best_threshold = best_threshold),
        file.path(OUTPUT_DIR, "xgb_model.rds"))

results_xgb <- tibble(
  model      = "XGBoost",
  aic        = NA_real_,
  bic        = NA_real_,
  hqic       = NA_real_,
  cv_logloss = round(cv_logloss_val, 4),
  auc_roc    = round(auc(roc_obj), 4),
  accuracy   = round(cm$overall["Accuracy"],       4),
  f1         = round(cm$byClass["F1"],             4),
  precision  = round(cm$byClass["Pos Pred Value"], 4),
  recall     = round(cm$byClass["Sensitivity"],    4),
  threshold  = best_threshold
)

write_csv(results_xgb, file.path(OUTPUT_DIR, "xgb_results.csv"))
cat("Saved xgb_model.rds and xgb_results.csv\n")

# ------------------------------------------------------------
# 10. Plots
# ------------------------------------------------------------

# ROC curve
png(file.path(PLOTS_DIR, "xgb_roc_curve.png"), width = 700, height = 600)
plot(roc_obj, col = "#d73027", lwd = 2,
     main = sprintf("XGBoost — ROC Curve (AUC = %.4f)", auc(roc_obj)))
abline(a = 0, b = 1, lty = 2, col = "grey60")
dev.off()

# Confusion matrix heatmap
cm_df <- as.data.frame(cm$table)
names(cm_df) <- c("Predicted", "Actual", "Freq")
p_cm <- ggplot(cm_df, aes(x = Predicted, y = Actual, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), size = 7, fontface = "bold") +
  scale_fill_gradient(low = "#fde0d0", high = "#d73027") +
  labs(title = "XGBoost — Confusion Matrix", x = "Predicted", y = "Actual") +
  theme_minimal(base_size = 14) + theme(legend.position = "none")
ggsave(file.path(PLOTS_DIR, "xgb_confusion_matrix.png"), p_cm, width = 5, height = 4)

# Variable importance plot
p_imp <- var_imp |>
  slice_head(n = 20) |>
  ggplot(aes(x = reorder(Feature, Overall), y = Overall)) +
  geom_col(fill = "#d73027") + coord_flip() +
  labs(title = "XGBoost — Top 20 Variable Importances", x = NULL, y = "Gain") +
  theme_minimal()
ggsave(file.path(PLOTS_DIR, "xgb_variable_importance.png"), p_imp, width = 8, height = 6)

# CV tuning surface
p_tune <- ggplot(cv_tbl, aes(x = factor(nrounds), y = cv_auc,
                              color = factor(max_depth), group = factor(max_depth))) +
  geom_line(linewidth = 1) + geom_point(size = 3) +
  facet_wrap(~ eta, labeller = label_both) +
  labs(title = "XGBoost — CV AUC Grid Search",
       x = "nrounds", y = "CV AUC-ROC", color = "max_depth") +
  theme_minimal()
ggsave(file.path(PLOTS_DIR, "xgb_tuning_surface.png"), p_tune, width = 8, height = 5)

cat("Plots saved to:", PLOTS_DIR, "\n")
