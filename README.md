# Arcads AB Test Analysis

## Overview

This repository contains an analysis of two A/B tests conducted to evaluate the impact of different first-month discount strategies on customer acquisition and retention for Arcads, a video generation platform.

## Business Context

Arcads wanted to understand whether offering discounts on the first month of subscription would improve conversion rates and customer lifetime value. Two tests were conducted:

- **Test 1: 10% First-Month Discount** (January 1-10, 2026)
- **Test 2: 30% First-Month Discount** (January 28 - February 10, 2026)

Each test randomly assigned workspaces to either a control group (Cohort A) or a variant group (Cohort B) that received the discount offer.

## Analysis Goals

The analysis aims to answer:

1. **Does offering a first-month discount increase conversion rates?**
2. **What is the impact on customer acquisition cost (CAC)?**
3. **How does the discount affect lifetime value (LTV)?**
4. **Do discounted customers churn at different rates?**
5. **Which discount level (10% vs 30%) provides better ROI?**

## Key metrics analyzed

- **Conversion rate**: Percentage of workspaces that subscribe after being assigned to a test
- **Customer acquisition cost (CAC)**: Meta Ads spend divided by number of acquired customers
- **Lifetime value (LTV)**: Total revenue generated per customer
- **Churn rate**: Percentage of customers who cancel their subscription
- **Revenue & profit**: Total revenue minus generation costs
- **Statistical Significance**: Chi-square tests to validate findings

## Data Sources

The analysis uses data from:
- Workspace and subscription information
- Payment histories
- AB test assignments
- Credit consumption and generation costs
- Meta Ads spend data

## Project Structure

This is a **dbt project** that transforms raw data into analysis-ready datasets. The analysis is organized in three layers:

- **Staging models**: clean and standardize raw data
- **Intermediate models**: calculate business metrics (first subscriptions, workspace aggregations)
- **Marts models**: final fact tables ready for analysis

The main analysis query is located in `analyses/ab_test_complete_analysis.sql` and can be executed directly against the database.

## Key Findings

For detailed results and insights, see `https://salt-tempo-107.notion.site/Case-study-327ea2670962800e8675d89430447a3c?pvs=73`.

## Technical Notes

- The database connection is read-only, so the analysis uses the `analyses/` directory for query execution
- All models are structured to follow dbt best practices but are not materialized