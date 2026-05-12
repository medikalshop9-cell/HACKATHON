# Dataset Reference — Variable Dictionary
**Source:** UCI ML Repository — Default of Credit Card Clients  
**DOI:** 10.24432/C55S3H  
**Authors:** I-Cheng Yeh & Che-hui Lien (2009)  
**License:** CC BY 4.0

---

## Quick Facts

| Property | Value |
|---|---|
| Observations | 30,000 |
| Input features | 23 |
| Target variable | 1 (binary) |
| Missing values | None |
| Currency | New Taiwan Dollar (NTD) |
| Time period | April – September 2005 |
| Class balance | 77.9% no default / 22.1% default |

---

## Target Variable

| Column | Type | Values | Description |
|---|---|---|---|
| `default.payment.next.month` | Binary integer | `0` = No default, `1` = Default | Whether the client defaulted on their October 2005 payment |

---

## Feature Groups

### 1. Client Profile (Demographics)

| Column | R Type | Values | Description |
|---|---|---|---|
| `ID` | Integer | 1–30000 | Client identifier — **drop before modeling** |
| `LIMIT_BAL` | Numeric | 10,000–1,000,000 NTD | Amount of given credit (includes individual and family/supplementary credit) |
| `SEX` | Factor | `1`=Male, `2`=Female | Gender |
| `EDUCATION` | Factor | `1`=Graduate school, `2`=University, `3`=High school, `4`=Others | Education level |
| `MARRIAGE` | Factor | `1`=Married, `2`=Single, `3`=Others | Marital status |
| `AGE` | Integer | 21–79 | Age in years |

---

### 2. Repayment Status (PAY_*)

Monthly repayment status from **September 2005 (most recent) back to April 2005**.

| Column | Month | Description |
|---|---|---|
| `PAY_0` | September 2005 | Repayment status |
| `PAY_2` | August 2005 | Repayment status |
| `PAY_3` | July 2005 | Repayment status |
| `PAY_4` | June 2005 | Repayment status |
| `PAY_5` | May 2005 | Repayment status |
| `PAY_6` | April 2005 | Repayment status |

**R Type:** Factor  
**Scale:**

| Value | Meaning |
|---|---|
| `-2` | No consumption (undocumented — recode to `-1`) |
| `-1` | Paid duly |
| `0` | Use of revolving credit |
| `1` | Payment delay: 1 month |
| `2` | Payment delay: 2 months |
| `3` | Payment delay: 3 months |
| `4` | Payment delay: 4 months |
| `5` | Payment delay: 5 months |
| `6` | Payment delay: 6 months |
| `7` | Payment delay: 7 months |
| `8` | Payment delay: 8 months or more |

> **Note:** `PAY_1` does not exist in this dataset — the column naming jumps from `PAY_0` to `PAY_2`.

---

### 3. Bill Statement Amounts (BILL_AMT*)

Monthly statement balances in NTD. Negative values indicate refunds/credit balances — valid.

| Column | Month |
|---|---|
| `BILL_AMT1` | September 2005 |
| `BILL_AMT2` | August 2005 |
| `BILL_AMT3` | July 2005 |
| `BILL_AMT4` | June 2005 |
| `BILL_AMT5` | May 2005 |
| `BILL_AMT6` | April 2005 |

**R Type:** Numeric  
**Range:** -165,580 to 964,511 NTD (mean ≈ 51,223 for BILL_AMT1)

---

### 4. Payment Amounts (PAY_AMT*)

Amount actually paid by the client each month in NTD.

| Column | Month |
|---|---|
| `PAY_AMT1` | September 2005 |
| `PAY_AMT2` | August 2005 |
| `PAY_AMT3` | July 2005 |
| `PAY_AMT4` | June 2005 |
| `PAY_AMT5` | May 2005 |
| `PAY_AMT6` | April 2005 |

**R Type:** Numeric  
**Range:** 0 to 873,552 NTD (mean ≈ 5,664 for PAY_AMT1)

---

## Data Cleaning Rules

These are mandatory before any modeling. All cleaning lives in `models/01_data_cleaning.R`.

| Variable | Issue | Action |
|---|---|---|
| `EDUCATION` | Values `0`, `5`, `6` are undocumented (345 rows / 1.15%) | Recode → `4` (Others) |
| `MARRIAGE` | Value `0` is undocumented (54 rows / 0.18%) | Recode → `3` (Others) |
| `PAY_0`–`PAY_6` | Value `-2` is undocumented (varies by month) | Recode → `-1` (paid duly) |
| All `PAY_*`, `SEX`, `EDUCATION`, `MARRIAGE` | Stored as integers | Cast to `factor` |
| `ID` | Client identifier, not a feature | Drop before modeling |

---

## Observed Distributions (Raw Data)

### EDUCATION
| Value | Label | Count | % |
|---|---|---|---|
| 0 | Undocumented → recode to Others | 14 | 0.0% |
| 1 | Graduate school | 10,585 | 35.3% |
| 2 | University | 14,030 | 46.8% |
| 3 | High school | 4,917 | 16.4% |
| 4 | Others | 123 | 0.4% |
| 5 | Undocumented → recode to Others | 280 | 0.9% |
| 6 | Undocumented → recode to Others | 51 | 0.2% |

### MARRIAGE
| Value | Label | Count | % |
|---|---|---|---|
| 0 | Undocumented → recode to Others | 54 | 0.2% |
| 1 | Married | 13,659 | 45.5% |
| 2 | Single | 15,964 | 53.2% |
| 3 | Others | 323 | 1.1% |

### SEX
| Value | Label | Count | % |
|---|---|---|---|
| 1 | Male | 11,888 | 39.6% |
| 2 | Female | 18,112 | 60.4% |

### AGE
- Min: 21 | Max: 79 | Mean: 35.5

### LIMIT_BAL
- Min: 10,000 NTD | Max: 1,000,000 NTD | Mean: 167,484 NTD

---
 Performance Metrics for Managers
Do not just report Accuracy. Please provide a Performance Dashboard including:
*Hint: Calculate Profitability = (True Positives × Interest)- (False Positives × Loan Principal).
Metric
Model A Model B Model C
AUC-ROC
0.XX
False Positive Rate XX%
Profitability Index* $XXX
0.XX
XX%
$XXX
0.XX
XX%
$XXX

## Citation

```
Yeh, I-C., & Lien, C. (2009). The comparisons of data mining techniques for the predictive
accuracy of probability of default of credit card clients.
Expert Systems with Applications, 36(2), 2473–2480.
https://doi.org/10.24432/C55S3H
```
