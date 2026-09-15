# Retail Banking Probability of Default (PD) Scorecard

![SAS](https://img.shields.io/badge/SAS-Statistical%20Modeling-1f4e79)
![Credit Risk](https://img.shields.io/badge/Domain-Credit%20Risk-2f855a)
![Model](https://img.shields.io/badge/Model-Logistic%20Regression-4a5568)
![Status](https://img.shields.io/badge/Status-Completed-success)

An end-to-end **Retail Banking Probability of Default (PD) Scorecard** developed using SAS, WOE/IV analysis, logistic regression, and credit-risk model validation.

---

## 📌 Project Overview

This project develops a credit-risk scorecard that estimates the probability that a retail banking customer will default on their next payment.

The model converts customer credit and repayment characteristics into:

- **Probability of Default (PD)**
- **Credit Score**
- **Risk Deciles**
- **Risk Segmentation**
- **Portfolio Monitoring Metrics**

The complete workflow was implemented in **SAS Studio**, covering data preparation, exploratory analysis, variable binning, WOE transformation, Information Value analysis, logistic regression, score scaling, model validation, lift/gains analysis, PSI monitoring, and production scoring.

---

## 💼 Business Problem

Retail banks need reliable methods to identify customers who are more likely to default.

A PD scorecard can help risk teams:

- Identify high-risk customers
- Support credit-risk assessment
- Prioritize collections
- Segment customers by risk
- Monitor portfolio behavior
- Support credit-limit decisions

The goal of this project was to build an interpretable and statistically validated scorecard using a standard credit-risk modeling methodology.

---

## 📊 Dataset

**Dataset:** UCI Credit Card Default Dataset

| Attribute | Value |
|---|---:|
| Customers | **30,000** |
| Variables | **25** |
| Target | `default.payment.next.month` |
| Domain | Retail Credit Risk |

The raw dataset is **not included** in this repository.

Dataset information is available in [`data/README.md`](data/README.md).

---

# 🔄 Project Workflow

```text
Raw Credit Data
       ↓
Data Import
       ↓
Data Cleaning & Quality Checks
       ↓
Exploratory Data Analysis
       ↓
Missing Value Analysis
       ↓
Outlier Treatment
       ↓
Stratified Train/Test Split
       ↓
Variable Binning
       ↓
WOE Transformation
       ↓
Information Value (IV)
       ↓
VIF / Multicollinearity Check
       ↓
Logistic Regression
       ↓
Probability of Default
       ↓
Scorecard Scaling
       ↓
Model Validation
       ↓
Risk Decile & Lift Analysis
       ↓
PSI Monitoring
       ↓
Production Scoring

# 👤 Author

## Devansh Gupta

**Data Analytics | Data Science | Credit Risk Modeling**

An end-to-end portfolio project demonstrating practical application of:

**SAS + WOE/IV + Logistic Regression + Probability of Default + Credit Scorecard + Model Validation**
