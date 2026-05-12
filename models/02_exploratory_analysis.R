# ============================================================
# 02_exploratory_analysis.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: EDA — distributions, class balance, correlations,
#          repayment trend analysis. Saves plots to docs/figures/
# ============================================================

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(pROC))

set.seed(42)

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
CLEAN_PATH   <- "data/credit_clean.csv"
FIGURES_PATH <- "docs/figures"

dir.create(FIGURES_PATH, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 1. Load clean data
# ------------------------------------------------------------
pay_status_cols <- c("PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")

df <- read_csv(CLEAN_PATH, show_col_types = FALSE) |>
  mutate(
    default   = factor(default),
    SEX       = factor(SEX),
    EDUCATION = factor(EDUCATION),
    MARRIAGE  = factor(MARRIAGE),
    across(all_of(pay_status_cols), factor)
  )

cat("Loaded:", nrow(df), "rows\n")

# ------------------------------------------------------------
# 2. Class balance
# ------------------------------------------------------------
class_counts <- df |>
  count(default) |>
  mutate(pct = n / sum(n) * 100)

print(class_counts)

p_balance <- ggplot(class_counts, aes(x = default, y = n, fill = default)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = sprintf("%d (%.1f%%)", n, pct)), vjust = -0.5) +
  labs(title = "Target Class Distribution",
       x = "Default Next Month", y = "Count") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "01_class_balance.png"), p_balance, width = 6, height = 4)

# ------------------------------------------------------------
# 3. Demographic distributions by default status
# ------------------------------------------------------------
plot_cat <- function(var, title) {
  df |>
    count(!!sym(var), default) |>
    group_by(!!sym(var)) |>
    mutate(pct = n / sum(n) * 100) |>
    filter(default == "Yes") |>
    ggplot(aes(x = !!sym(var), y = pct, fill = !!sym(var))) +
    geom_col(show.legend = FALSE) +
    labs(title = title, x = var, y = "Default Rate (%)") +
    theme_minimal()
}

ggsave(file.path(FIGURES_PATH, "02_default_by_education.png"),
       plot_cat("EDUCATION", "Default Rate by Education"), width = 7, height = 4)
ggsave(file.path(FIGURES_PATH, "03_default_by_marriage.png"),
       plot_cat("MARRIAGE", "Default Rate by Marital Status"), width = 6, height = 4)
ggsave(file.path(FIGURES_PATH, "04_default_by_sex.png"),
       plot_cat("SEX", "Default Rate by Sex"), width = 5, height = 4)

# ------------------------------------------------------------
# 4. LIMIT_BAL vs default
# ------------------------------------------------------------
p_limit <- ggplot(df, aes(x = default, y = LIMIT_BAL, fill = default)) +
  geom_boxplot(show.legend = FALSE, outlier.alpha = 0.2) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Credit Limit by Default Status", x = "Default", y = "LIMIT_BAL (NTD)") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "05_limit_bal_vs_default.png"), p_limit, width = 6, height = 4)

# ------------------------------------------------------------
# 5. Repayment status (PAY_0) distribution
# ------------------------------------------------------------
p_pay0 <- df |>
  count(PAY_0, default) |>
  ggplot(aes(x = PAY_0, y = n, fill = default)) +
  geom_col(position = "fill") +
  labs(title = "PAY_0 Repayment Status vs Default Rate",
       x = "PAY_0 Value", y = "Proportion", fill = "Default") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "06_pay0_vs_default.png"), p_pay0, width = 8, height = 4)

# ------------------------------------------------------------
# 6. PAY_* trend: consecutive delays heatmap
# ------------------------------------------------------------
pay_long <- df |>
  select(default, all_of(pay_status_cols)) |>
  pivot_longer(cols = all_of(pay_status_cols), names_to = "month", values_to = "status") |>
  count(month, status, default) |>
  pivot_wider(names_from = default, values_from = n, values_fill = 0) |>
  mutate(pct_default = Yes / (No + Yes) * 100) |>
  rename(n = Yes)

p_pay_trend <- ggplot(pay_long, aes(x = month, y = status, fill = pct_default)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#ffffcc", high = "#d73027", name = "Default %") +
  labs(title = "Default Rate by Repayment Status × Month",
       x = "Month", y = "PAY Status") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "07_pay_trend_heatmap.png"), p_pay_trend, width = 9, height = 5)

# ------------------------------------------------------------
# 7. Age distribution by default
# ------------------------------------------------------------
p_age <- ggplot(df, aes(x = AGE, fill = default)) +
  geom_histogram(binwidth = 2, position = "identity", alpha = 0.6) +
  labs(title = "Age Distribution by Default Status",
       x = "Age", y = "Count", fill = "Default") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "08_age_distribution.png"), p_age, width = 7, height = 4)

# ------------------------------------------------------------
# 8. Bill vs Payment scatter (BILL_AMT1 vs PAY_AMT1)
# ------------------------------------------------------------
p_bill_pay <- df |>
  slice_sample(n = 3000) |>
  ggplot(aes(x = BILL_AMT1, y = PAY_AMT1, color = default)) +
  geom_point(alpha = 0.4, size = 0.8) +
  scale_x_continuous(labels = scales::comma, limits = c(0, 500000)) +
  scale_y_continuous(labels = scales::comma, limits = c(0, 200000)) +
  labs(title = "Bill Amount vs Payment Amount (Sep 2005, sample n=3000)",
       x = "BILL_AMT1 (NTD)", y = "PAY_AMT1 (NTD)", color = "Default") +
  theme_minimal()

ggsave(file.path(FIGURES_PATH, "09_bill_vs_payment.png"), p_bill_pay, width = 7, height = 5)

# ------------------------------------------------------------
# 9. Correlation heatmap (numeric features only)
# ------------------------------------------------------------
num_cols <- df |> select(LIMIT_BAL, AGE, starts_with("BILL_AMT"), starts_with("PAY_AMT"))
cor_mat  <- cor(num_cols, use = "complete.obs")

cor_long <- as.data.frame(cor_mat) |>
  rownames_to_column("var1") |>
  pivot_longer(-var1, names_to = "var2", values_to = "correlation")

p_corr <- ggplot(cor_long, aes(x = var1, y = var2, fill = correlation)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "#4575b4", mid = "white", high = "#d73027",
                       midpoint = 0, limits = c(-1, 1), name = "r") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Correlation Matrix — Numeric Features")

ggsave(file.path(FIGURES_PATH, "10_correlation_heatmap.png"), p_corr, width = 9, height = 8)

# Save raw matrix as CSV
write_csv(as.data.frame(cor_mat) |> rownames_to_column("variable"),
          file.path(FIGURES_PATH, "correlation_matrix.csv"))

# ------------------------------------------------------------
# 10. Export all plots to a single multi-page PDF
# ------------------------------------------------------------
PDF_PATH <- file.path(FIGURES_PATH, "eda_plots.pdf")

all_plots <- list(
  p_balance,
  plot_cat("EDUCATION", "Default Rate by Education"),
  plot_cat("MARRIAGE",  "Default Rate by Marital Status"),
  plot_cat("SEX",       "Default Rate by Sex"),
  p_limit,
  p_pay0,
  p_pay_trend,
  p_age,
  p_bill_pay,
  p_corr
)

pdf(PDF_PATH, width = 9, height = 6)
invisible(lapply(all_plots, print))
dev.off()

cat("EDA complete.\n")
cat("Individual PNGs saved to:", FIGURES_PATH, "\n")
cat("Combined PDF saved to   :", PDF_PATH, "\n")
