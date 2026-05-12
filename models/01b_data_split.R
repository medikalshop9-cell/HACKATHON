# ============================================================
# 01b_data_split.R
# Credit Assessment Agent — Africa Business School, UM6P
# Purpose: Create ONE canonical train/validation/test split.
#          All model scripts load from these saved files.
#          SMOTE is NOT applied here — only inside model scripts
#          on the training fold. Test and validation sets are
#          NEVER touched by resampling to prevent data leakage.
# ============================================================
#
# Split strategy:
#   60% train       → model fitting + SMOTE (inside each model script)
#   20% validation  → threshold tuning, grey-zone decisions (40–60%)
#   20% test        → final locked evaluation, touched ONCE per model
#
# Class balance (stratified):
#   ~22% default rate preserved in each split via createDataPartition

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(caret))

set.seed(42)

# ------------------------------------------------------------
# Config
# ------------------------------------------------------------
CLEAN_PATH <- "data/credit_clean.csv"
PAY_COLS   <- c("PAY_0", "PAY_2", "PAY_3", "PAY_4", "PAY_5", "PAY_6")

# ------------------------------------------------------------
# 1. Load clean data
# ------------------------------------------------------------
df <- read_csv(CLEAN_PATH, show_col_types = FALSE) |>
  mutate(
    default   = factor(default,   levels = c("No", "Yes")),
    SEX       = factor(SEX),
    EDUCATION = factor(EDUCATION),
    MARRIAGE  = factor(MARRIAGE),
    across(all_of(PAY_COLS), factor)
  )

n_total <- nrow(df)
cat("Total rows:", n_total, "\n")
cat("Class distribution (raw):\n")
print(table(df$default))
cat("Default rate:", round(mean(df$default == "Yes") * 100, 1), "%\n\n")

# ------------------------------------------------------------
# 2. First split: 60% train | 40% temp (val + test)
# ------------------------------------------------------------
train_idx <- createDataPartition(df$default, p = 0.60, list = FALSE)
train_set <- df[ train_idx, ]
temp_set  <- df[-train_idx, ]

# ------------------------------------------------------------
# 3. Second split: 50% of temp = validation, 50% = test
#    (0.5 × 40% = 20% val | 20% test of original)
# ------------------------------------------------------------
val_idx  <- createDataPartition(temp_set$default, p = 0.50, list = FALSE)
val_set  <- temp_set[ val_idx, ]
test_set <- temp_set[-val_idx, ]

# ------------------------------------------------------------
# 4. Verify stratification — default rate must be ~22% in all splits
# ------------------------------------------------------------
splits <- list(train = train_set, validation = val_set, test = test_set)

cat("=== Split Summary ===\n")
for (name in names(splits)) {
  s <- splits[[name]]
  rate <- round(mean(s$default == "Yes") * 100, 1)
  cat(sprintf("  %-12s %5d rows  |  Default rate: %s%%\n", name, nrow(s), rate))
}
cat("\n")

# Guard: all splits must stay within ±1.5pp of the overall default rate
overall_rate <- mean(df$default == "Yes")
for (name in names(splits)) {
  split_rate <- mean(splits[[name]]$default == "Yes")
  diff <- abs(split_rate - overall_rate)
  if (diff > 0.015) {
    stop(sprintf("Stratification failed for %s: %.1f%% vs expected %.1f%%",
                 name, split_rate * 100, overall_rate * 100))
  }
}
cat("Stratification check PASSED (all splits within 1.5pp of overall rate)\n\n")

# ------------------------------------------------------------
# 5. Save splits
#    - Raw factor splits saved as CSV for audit
#    - Encoded (numeric dummy) matrices NOT saved — each model
#      script encodes its own features to avoid column mismatch
# ------------------------------------------------------------
write_csv(train_set, "data/split_train.csv")
write_csv(val_set,   "data/split_validation.csv")
write_csv(test_set,  "data/split_test.csv")

# Save split indices for reproducibility audit
split_log <- tibble(
  split      = c("train", "validation", "test"),
  n_rows     = c(nrow(train_set), nrow(val_set), nrow(test_set)),
  pct_total  = round(c(nrow(train_set), nrow(val_set), nrow(test_set)) / n_total * 100, 1),
  default_rate = round(c(
    mean(train_set$default == "Yes"),
    mean(val_set$default == "Yes"),
    mean(test_set$default == "Yes")
  ) * 100, 2)
)
write_csv(split_log, "data/split_log.csv")

cat("Saved:\n")
cat("  data/split_train.csv      (", nrow(train_set), "rows)\n")
cat("  data/split_validation.csv (", nrow(val_set), "rows)\n")
cat("  data/split_test.csv       (", nrow(test_set), "rows)\n")
cat("  data/split_log.csv        (audit log)\n\n")

# ------------------------------------------------------------
# NOTE FOR MODEL SCRIPTS
# ------------------------------------------------------------
# Each model script should:
#   1. Load split_train.csv      → apply SMOTE → fit model
#   2. Load split_validation.csv → tune threshold (esp. 40–60% grey zone)
#   3. Load split_test.csv       → final evaluation (ONCE, at the end)
#
# SMOTE must ONLY be applied to split_train.csv — never to val or test.
# Do not re-split inside model scripts.
# ============================================================
