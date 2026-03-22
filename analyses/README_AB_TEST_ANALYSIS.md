# AB Test Complete Analysis - Enhanced Version

## Overview
This analysis compares two paywall discount AB tests with comprehensive metrics including:
1. **Churn Analysis** - Are users just taking the discount and leaving?
2. **CAC Integration** - True profitability including customer acquisition costs
3. **Time Normalization** - Fair comparison despite different test durations

**Cohort Definitions:**
- **Cohort A** = Control group (baseline)
- **Cohort B** = Test group (variant with discount)
- **test_label** = Human-readable label ("Control" or "Test")

## Key Features

### 1. Churn Post-Discount Metrics
Answers: *Are people only taking advantage of the discount and then churning?*

**Metrics:**
- `churned_workspaces` - Total number of churned users
- `churned_after_first_month` - Users who left after just one subscription (discount-only users)
- `churn_rate_percent` - Overall churn rate
- `first_month_churn_rate_percent` - % who churned after first subscription
- `retention_rate_percent` - % who renewed (had multiple subscriptions)
- `avg_subscription_lifetime_days` - Average customer lifetime
- `churn_rate_diff` - Churn difference between test and control

**Interpretation:**
- High `first_month_churn_rate_percent` = Users exploiting the discount
- Low `retention_rate_percent` = Poor long-term value
- Compare test vs control to see if discount attracts lower-quality customers

### 2. CAC (Customer Acquisition Cost) Integration
Answers: *What's the true profitability including marketing spend?*

**Metrics:**
- `avg_cac_per_signup` - Average cost to acquire each sign-up
- `avg_cac_per_purchase` - Average cost to acquire each paying customer
- `total_cac_cost` - Total acquisition cost for the cohort
- `total_profit_with_cac` - Revenue - Generation Cost - CAC
- `profit_per_workspace_with_cac` - Per-user profitability including CAC

**Data Source:**
- Meta Ads data from `seeds/meta_ads.csv`
- Automatically matched to test periods
- CAC calculated as: Total Ad Spend / Total Sign-ups

### 3. Test Duration Normalization
Answers: *How do we compare tests that ran for different lengths of time?*

**Metrics:**
- `test_duration_days` - How many days each test ran
- `workspaces_per_day` - Daily acquisition rate
- `conversions_per_day` - Daily conversion rate
- `revenue_per_day` - Daily revenue
- `profit_per_day` - Daily profit (with CAC)
- `projected_*_30d` - All metrics extrapolated to 30 days for comparison

**Approach:**
- All lift calculations use normalized daily rates
- 30-day projections allow apples-to-apples comparison
- Accounts for seasonality and test timing differences

## How to Run

### Prerequisites
1. Ensure database connection is configured
2. Run dbt seeds to load Meta Ads data:
   ```bash
   dbt seed
   ```

### Execute the Analysis
```bash
# Option 1: Run directly in SQL editor
# Open analyses/ab_test_complete_analysis.sql and execute

# Option 2: Compile and run via dbt
dbt compile -s ab_test_complete_analysis
# Then run the compiled SQL from target/compiled/...
```

## Output Columns

### Volume & Conversion
- `total_workspaces` - Total users in cohort
- `converted_workspaces` - Users who subscribed
- `conversion_rate_percent` - Conversion rate
- `conversion_lift_pct` - Lift vs control

### Revenue Metrics
- `total_revenue` - Total revenue
- `avg_first_payment` - Average first payment amount
- `revenue_per_workspace` - Revenue per user
- `revenue_per_day` - Daily revenue rate
- `projected_revenue_30d` - 30-day revenue projection
- `revenue_lift_pct` - Revenue lift vs control

### Profitability (with CAC)
- `total_profit_with_cac` - Total profit after all costs
- `profit_per_workspace_with_cac` - Profit per user
- `profit_per_day` - Daily profit rate
- `projected_profit_30d` - 30-day profit projection
- `profit_lift_pct` - Profit lift vs control

### Churn & Retention
- `churned_workspaces` - Total churned
- `churned_after_first_month` - First-month churners
- `churn_rate_percent` - Overall churn rate
- `first_month_churn_rate_percent` - First-month churn rate
- `retention_rate_percent` - Renewal rate
- `avg_subscription_lifetime_days` - Average lifetime
- `churn_rate_diff` - Churn difference vs control
- `first_month_churn_diff` - First-month churn difference

### Engagement
- `total_generations` - Total content generated
- `avg_generations_per_active_user` - Avg generations per active user

## Key Questions Answered

### 1. Which discount performs better?
Compare `profit_per_day` and `profit_lift_pct` between:
- PAYWALL_FIRST_MONTH_DISCOUNT (test)
- PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT (test)

### 2. Are discount users just churning?
Look at:
- `first_month_churn_rate_percent` - Should be low (<30%)
- `retention_rate_percent` - Should be high (>50%)
- `first_month_churn_diff` - Test vs control difference

If test cohort has significantly higher first-month churn, users are exploiting the discount.

### 3. Is the discount profitable after CAC?
Check:
- `profit_per_workspace_with_cac` - Should be positive
- `profit_lift_pct` - Should be positive vs control
- `avg_cac_per_signup` - Should be < LTV

### 4. Fair comparison despite different test durations?
Use normalized metrics:
- `*_per_day` metrics for rate comparison
- `projected_*_30d` for volume comparison
- All lift calculations use normalized values

## Example Interpretation

```
Test: PAYWALL_FIRST_MONTH_30_PERCENT_DISCOUNT
Cohort: B (Test)
test_label: Test
- conversion_rate_percent: 25% (+5% vs control)
- first_month_churn_rate_percent: 40% (+15% vs control)
- profit_per_workspace_with_cac: €15 (-€5 vs control)
- retention_rate_percent: 45% (-20% vs control)
```

**Interpretation:**
- ❌ Higher conversion but lower quality customers
- ❌ 40% churn after first month = discount exploitation
- ❌ Lower profit per user despite higher conversion
- ❌ Poor retention = bad long-term value
- **Recommendation:** Don't implement this discount

## Notes

- All monetary values in EUR
- Churn defined as: last subscription ended before current date
- First-month churn: users with only 1 subscription that has ended
- CAC matched to test periods automatically
- Generation costs estimated at €0.01 per credit
