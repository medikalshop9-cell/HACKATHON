# ============================================================
# 01_data_cleaning.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Load raw CSV, fix undocumented categories,
#          cast factors, export clean dataset.
# ============================================================

suppressPackageStartupMessages(library(tidyverse))

set.seed(42)

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
DATA_PATH  <- "data/default_credit_card_clients.csv"
OUTPUT_PATH <- "data/credit_clean.csv"

# ------------------------------------------------------------
# 1. Load raw data (skip first metadata row, use row 2 as header)
# ------------------------------------------------------------
raw <- read_csv(DATA_PATH, skip = 1, show_col_types = FALSE)

# Rename target column (spaces → dots)
raw <- raw |>
  rename(default = `default payment next month`)

# Drop the ID column — not a feature
raw <- raw |> select(-ID)

cat("Raw dimensions:", nrow(raw), "rows x", ncol(raw), "cols\n")

# ------------------------------------------------------------
# 2. Recode undocumented categories
# ------------------------------------------------------------

# EDUCATION: {0, 5, 6} → 4 (Others)
raw <- raw |>
  mutate(EDUCATION = if_else(EDUCATION %in% c(0L, 5L, 6L), 4L, EDUCATION))

# MARRIAGE: {0} → 3 (Others)
raw <- raw |>
  mutate(MARRIAGE = if_else(MARRIAGE == 0L, 3L, MARRIAGE))

# PAY_* : {-2} → -1 (paid duly)
pay_cols <- c("PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")
raw <- raw |>
  mutate(across(all_of(pay_cols), ~ if_else(.x == -2L, -1L, .x)))

# ------------------------------------------------------------
# 3. Cast categorical variables to factors
# ------------------------------------------------------------
raw <- raw |>
  mutate(
    SEX       = factor(SEX,       levels = c(1, 2),
                       labels = c("Male", "Female")),
    EDUCATION = factor(EDUCATION, levels = c(1, 2, 3, 4),
                       labels = c("Graduate", "University", "HighSchool", "Others")),
    MARRIAGE  = factor(MARRIAGE,  levels = c(1, 2, 3),
                       labels = c("Married", "Single", "Others")),
    default   = factor(default,   levels = c(0, 1),
                       labels = c("No", "Yes")),
    across(all_of(pay_cols), ~ factor(.x))
  )

# ------------------------------------------------------------
# 4. Validate — no unexpected levels should remain
# ------------------------------------------------------------
stopifnot(all(levels(raw$EDUCATION) %in% c("Graduate", "University", "HighSchool", "Others")))
stopifnot(all(levels(raw$MARRIAGE)  %in% c("Married", "Single", "Others")))

cat("Clean dimensions:", nrow(raw), "rows x", ncol(raw), "cols\n")
cat("Default rate:", round(mean(raw$default == "Yes") * 100, 1), "%\n")

# ------------------------------------------------------------
# 5. Export
# ------------------------------------------------------------

# TODO: Multicollinearity — BILL_AMT1–BILL_AMT6 are highly inter-correlated
# (r = 0.80–0.95 from correlation_matrix.csv). PAY_AMT columns are moderately
# correlated (r = 0.15–0.32). Consider PCA or dropping lagged BILL_AMT columns
# (keep BILL_AMT1, drop BILL_AMT2–6) after model training is complete.
# Do NOT apply this transformation until Phase 2 results are reviewed.

write_csv(raw, OUTPUT_PATH)
cat("Saved clean dataset to:", OUTPUT_PATH, "\n")
