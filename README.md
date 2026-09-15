# Retail Banking Probability of Default (PD) Scorecard

## Project Overview

This project develops a retail banking Probability of Default (PD) scorecard using the UCI Credit Card Default dataset.

The objective is to build an interpretable credit risk model that estimates the probability that a customer will default on their next month's payment and converts that probability into a traditional credit score.

The complete workflow was implemented in SAS Studio, covering data preparation, exploratory analysis, scorecard development, model validation, score scaling, risk segmentation, and production scoring.

---

## Business Problem

Retail banks need reliable methods to identify customers who are more likely to default on their credit obligations.

A Probability of Default scorecard can help financial institutions:

- Identify high-risk customers
- Segment customers into different risk categories
- Support credit risk decisions
- Prioritize accounts for monitoring
- Estimate customer-level probability of default
- Convert model predictions into an interpretable credit score

---

## Dataset

The project uses the **UCI Credit Card Default** dataset.

Dataset characteristics:

- **30,000 customer records**
- **25 original variables**
- Target variable: `default_payment_next_month`
- Binary target:
  - `0` = No default
  - `1` = Default

The raw dataset is not included in this repository.

---

## Project Workflow

The scorecard was developed through the following stages:

1. Data Import
2. Data Cleaning
3. Exploratory Data Analysis
4. Missing Value Analysis
5. Outlier Treatment
6. Stratified Train/Test Split
7. Scorecard Binning
8. Weight of Evidence (WOE) and Information Value (IV)
9. WOE Transformation
10. Multicollinearity / VIF Analysis
11. Logistic Regression
12. Hosmer-Lemeshow Validation
13. AUC, Gini and KS Evaluation
14. Scorecard Point Scaling
15. Score Distribution Analysis
16. Decile Validation
17. Risk-Ordered Lift and Gains
18. Population Stability Index (PSI)
19. Characteristic Analysis
20. Production Scoring
21. Final Reporting

---

## Train/Test Split

A stratified 70/30 train-test split was used.

| Dataset | Records |
|---|---:|
| Training | 21,001 |
| Testing | 8,999 |
| Total | 30,000 |

The target distribution was preserved during the split.

---

## Scorecard Variables

Three variables were selected for the final scorecard:

- `PAY_0`
- `AGE`
- `LIMIT_BAL`

### Information Value

| Variable | Information Value |
|---|---:|
| PAY_0 | 0.8840 |
| LIMIT_BAL | 0.1533 |
| AGE | 0.0144 |

`PAY_0` was the strongest predictor in the final model.

---

## Logistic Regression Model

The final logistic regression model was built using WOE-transformed variables.

### Model Coefficients

| Variable | Coefficient |
|---|---:|
| Intercept | -1.2549 |
| WOE_PAY_0 | -0.9578 |
| WOE_AGE | -0.2234 |
| WOE_LIMIT_BAL | -0.6155 |

The model's training c-statistic was approximately **0.7385**.

---

## Model Performance

The final model achieved:

| Metric | Result |
|---|---:|
| AUC | **0.7385** |
| Gini | **47.71** |
| KS | **38.24** |
| Hosmer-Lemeshow p-value | **0.5688** |

The results indicate meaningful discriminatory power and acceptable calibration for this project.

---

## Scorecard Scaling

The predicted probability of default was converted into a traditional credit score using:

| Parameter | Value |
|---|---:|
| Base Score | 600 |
| Base Odds | 50 |
| PDO | 20 |
| Factor | ≈ 28.85 |
| Offset | ≈ 487.12 |

Higher credit scores represent lower estimated default risk.

---

## Score Distribution

The training population produced scores approximately between:

- **Minimum:** 452
- **Maximum:** 549
- **Mean:** 528.36
- **Median:** 536

---

## Risk Decile Validation

Customers were divided into ten risk-ordered deciles.

The scorecard demonstrated strong risk separation:

- Lowest-score / highest-risk decile had approximately **70.19%** bad rate.
- Highest-score / lowest-risk decile had approximately **9.66%** bad rate.

The risk ordering confirms that lower scores correspond to higher default risk.

The first risk decile captured approximately **31.88% of all defaults** while representing approximately **10.05% of the population**, producing approximately **3.17x lift**.

---

## Characteristic Analysis

### PAY_0

Observed default rates increased substantially with repayment delay:

| Repayment Status | Default Rate |
|---|---:|
| Duly Paid / No Delay | 13.65% |
| 1 Month Delay | 34.25% |
| 2 Months Delay | 69.22% |
| 3+ Months Delay | 72.00% |

This demonstrates that recent repayment behavior is a major indicator of future default risk.

### LIMIT_BAL

Default rates also varied across credit-limit bands:

| Credit Limit | Default Rate |
|---|---:|
| ≤ 50k | 31.78% |
| 50k–100k | 25.94% |
| 100k–200k | 19.38% |
| > 200k | 14.77% |

---

## Population Stability Index

The total PSI between the training and testing score distributions was approximately:

**PSI = 0.0003**

This indicates very little difference between the training and testing score distributions in this project.

---

## Production Scoring

The final scorecard was applied to the held-out test population.

Test population:

**8,999 customers**

The resulting production-style scoring dataset contains customer-level:

- Probability of Default
- Credit Score
- Risk information

---

## Project Structure

```text
Retail-PD-Scorecard/
│
├── data/
│   └── README.md
│
├── report/
│   └── Retail_PD_Scorecard_Final_Report.pdf
│
├── sas/
│   └── Retail_PD_Scorecard_Master.sas
│
├── screenshots/
│   ├── data_import.png
│   ├── model_performance.png
│   ├── scorecard.png
│   ├── decile_validation.png
│   └── characteristic_analysis.png
│
└── README.md