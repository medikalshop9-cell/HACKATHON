# ============================================================
# 06_model_comparison.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Load all model result CSVs, build unified comparison
#          table, apply selection criteria, declare winner.
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(pROC))

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
OUTPUT_DIR <- "models/outputs"
PLOTS_DIR  <- "models/outputs/plots"
DOCS_DIR   <- "docs"
dir.create(PLOTS_DIR, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Load individual model results
# ------------------------------------------------------------
results <- bind_rows(
  read_csv(file.path(OUTPUT_DIR, "logit_results.csv"), show_col_types = FALSE),
  read_csv(file.path(OUTPUT_DIR, "rf_results.csv"),    show_col_types = FALSE),
  read_csv(file.path(OUTPUT_DIR, "xgb_results.csv"),   show_col_types = FALSE)
)

cat("=== Unified Model Comparison ===\n")
print(results)

# ------------------------------------------------------------
# 2. Rank models per criterion (lower = better for all criteria)
# ------------------------------------------------------------

# For parametric (logistic): rank by AIC, BIC, HQIC
# For all: rank by CV log-loss and AUC-ROC (AUC: higher = better)

results <- results |>
  mutate(
    rank_aic       = rank(aic,        na.last = "keep", ties.method = "min"),
    rank_bic       = rank(bic,        na.last = "keep", ties.method = "min"),
    rank_hqic      = rank(hqic,       na.last = "keep", ties.method = "min"),
    rank_logloss   = rank(cv_logloss, na.last = "keep", ties.method = "min"),
    rank_auc       = rank(-auc_roc,   na.last = "keep", ties.method = "min"),   # negate: higher AUC = lower rank
    rank_f1        = rank(-f1,        na.last = "keep", ties.method = "min")
  )

# Composite rank (average of available ranks per model)
results <- results |>
  rowwise() |>
  mutate(
    composite_rank = mean(c(rank_logloss, rank_auc, rank_f1), na.rm = TRUE)
  ) |>
  ungroup()

# ------------------------------------------------------------
# 3. Apply selection rule
# ------------------------------------------------------------
winner <- results |>
  arrange(composite_rank) |>
  slice(1) |>
  pull(model)

cat("\n=== SELECTION RESULT ===\n")
cat("Winner:", winner, "\n\n")
cat("Full ranking:\n")
results |>
  select(model, cv_logloss, auc_roc, f1, composite_rank) |>
  arrange(composite_rank) |>
  print()

# ------------------------------------------------------------
# 4. Override check — Recall safety net
# ------------------------------------------------------------
recall_threshold <- 0.50

low_recall <- results |> filter(recall < recall_threshold)
if (nrow(low_recall) > 0) {
  cat("\nWARNING: The following models have Recall <", recall_threshold, ":\n")
  print(low_recall |> select(model, recall))
  cat("Consider selecting by best Recall for credit risk applications.\n")
}

# ------------------------------------------------------------
# 5. Save comparison table
# ------------------------------------------------------------
write_csv(results, file.path(OUTPUT_DIR, "model_comparison.csv"))
cat("\nSaved model_comparison.csv to", OUTPUT_DIR, "\n")

# ------------------------------------------------------------
# 6. Comparison plots
# ------------------------------------------------------------

# Metric bar chart (AUC, F1, Accuracy, Recall)
metrics_long <- results |>
  select(model, auc_roc, f1, accuracy, recall, precision) |>
  pivot_longer(-model, names_to = "metric", values_to = "value")

p_metrics <- ggplot(metrics_long, aes(x = metric, y = value, fill = model)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("Logistic Regression" = "#2166ac",
                               "Random Forest"       = "#1a9641",
                               "XGBoost"             = "#d73027")) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(title = "Model Comparison — Classification Metrics",
       x = NULL, y = "Score", fill = "Model") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

ggsave(file.path(PLOTS_DIR, "comparison_metrics.png"), p_metrics, width = 9, height = 5)

# CV Log-loss bar chart
p_logloss <- ggplot(results, aes(x = reorder(model, cv_logloss), y = cv_logloss, fill = model)) +
  geom_col(show.legend = FALSE, width = 0.5) +
  geom_text(aes(label = round(cv_logloss, 4)), vjust = -0.5, size = 4) +
  scale_fill_manual(values = c("Logistic Regression" = "#2166ac",
                               "Random Forest"       = "#1a9641",
                               "XGBoost"             = "#d73027")) +
  labs(title = "Model Comparison — CV Log-loss (lower = better)",
       x = NULL, y = "CV Log-loss") +
  theme_minimal(base_size = 13)

ggsave(file.path(PLOTS_DIR, "comparison_logloss.png"), p_logloss, width = 7, height = 5)

# Composite rank lollipop
p_rank <- ggplot(results, aes(x = reorder(model, composite_rank), y = composite_rank)) +
  geom_segment(aes(xend = model, y = 0, yend = composite_rank), linewidth = 1.2, color = "grey50") +
  geom_point(aes(color = model), size = 6, show.legend = FALSE) +
  geom_text(aes(label = round(composite_rank, 2)), vjust = -1, size = 4) +
  scale_color_manual(values = c("Logistic Regression" = "#2166ac",
                                "Random Forest"       = "#1a9641",
                                "XGBoost"             = "#d73027")) +
  labs(title = "Model Comparison — Composite Rank (lower = better)",
       x = NULL, y = "Composite Rank") +
  theme_minimal(base_size = 13)

ggsave(file.path(PLOTS_DIR, "comparison_composite_rank.png"), p_rank, width = 7, height = 5)

cat("Comparison plots saved to:", PLOTS_DIR, "\n")

# ------------------------------------------------------------
# 7. Print summary for README / docs update
# ------------------------------------------------------------
cat("\n=== COPY INTO README / docs/model_selection.md ===\n")
results |>
  select(model, auc_roc, accuracy, f1, precision, recall, cv_logloss) |>
  arrange(desc(auc_roc)) |>
  print()

cat("\nBest model by composite criterion:", winner, "\n")
