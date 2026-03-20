# Arcads A/B Test Case Study - Project Status

**Date:** March 18, 2026  
**Status:** ✅ **COMPLETE AND READY FOR SUBMISSION**

---

## ✅ Project Setup - COMPLETE

### dbt Configuration
- ✅ dbt version: 1.9.0
- ✅ Adapter: postgres 1.9.1
- ✅ Profile: `arcads_case` configured in `~/.dbt/profiles.yml`
- ✅ Connection: Successfully tested to PostgreSQL database
- ✅ Database: `data-analysis-test` on AWS RDS (eu-west-3)
- ✅ Schema: `public` (read-only access)

### Project Structure
```
arcads_case/
├── models/
│   ├── staging/          ✅ 11 staging models (views)
│   ├── intermediate/     ✅ 2 intermediate models (tables)
│   └── marts/core/       ✅ 4 mart models (dimensions + facts)
├── analyses/             ✅ 3 working SQL analysis queries
├── seeds/                ✅ 1 seed file (meta_ads_data.csv)
├── dbt_project.yml       ✅ Properly configured
├── README.md             ✅ Complete documentation
└── AB_TEST_ANALYSIS_REPORT.md  ✅ Final analysis report
```

---

## ✅ Data Models - COMPLETE

### Staging Layer (11 models)
All staging models successfully compiled and documented:
1. ✅ `stg_users` - User accounts
2. ✅ `stg_workspaces` - Workspace entities
3. ✅ `stg_plans` - Subscription plans
4. ✅ `stg_workspaces_ab_tests` - AB test assignments
5. ✅ `stg_stripe_subscription_histories` - Subscription history
6. ✅ `stg_stripe_payment_histories` - Payment history
7. ✅ `stg_credits_consumption_events` - Credit usage
8. ✅ `stg_videos` - Video generations
9. ✅ `stg_video_assets` - Other content generations
10. ✅ `stg_costs` - Generation costs
11. ✅ `stg_meta_ads` - Marketing data (seed)

### Intermediate Layer (2 models)
1. ✅ `int_first_subscriptions` - First subscription per workspace with AB test info
2. ✅ `int_workspace_metrics` - Aggregated revenue, costs, and engagement metrics

### Marts Layer (4 models)
1. ✅ `dim_workspaces` - Workspace dimension with aggregated metrics
2. ✅ `dim_plans` - Plan dimension with pricing information
3. ✅ `fct_ab_test_paywall` - Fact table for AB test analysis
4. ✅ `fct_ab_test_analysis` - Pre-aggregated AB test metrics with lift calculations

**Total:** 17 models + 30 data tests + 12 sources + 3 analyses

---

## ✅ Analysis Queries - COMPLETE & TESTED

### 1. Main A/B Test Analysis (`ab_test_paywall_analysis.sql`)
**Status:** ✅ Working and tested
- Compares both 10% and 30% discount tests
- Key metrics: conversion rates, revenue, LTV, profit, time to conversion
- Results exported to: `analyses/ab_test_results.csv`

### 2. Plan-Level Analysis (`plan_level_analysis.sql`)
**Status:** ✅ Working and tested
- Breaks down conversions by plan type (STARTER, BASIC/CREATOR, PRO)
- Shows billing interval distribution (monthly vs yearly)
- Revenue totals by plan

### 3. Engagement Analysis (`engagement_analysis.sql`)
**Status:** ✅ Working and tested
- User engagement metrics (content generation, credit consumption)
- Segmented by conversion status
- Cost analysis

---

## ✅ Key Findings - ANALYSIS COMPLETE

### Winner: 30% Discount Test (Cohort B)

#### 30% Discount Test Results:
- **Conversion Rate Lift:** +48.24% (1.63% → 2.41%) ⭐
- **LTV per Workspace Lift:** +9.06% (€2.28 → €2.48) ⭐
- **Sample Size:** ~22,500 workspaces per cohort
- **Statistical Significance:** High (large sample + significant lift)
- **Test Period:** Jan 28 - Feb 10, 2026

#### 10% Discount Test Results:
- **Conversion Rate Lift:** +4.29% (1.09% → 1.14%)
- **LTV per Workspace:** -13.31% (€5.59 → €4.85) ⚠️
- **Sample Size:** ~24,700 workspaces per cohort
- **Test Period:** Jan 1-10, 2026

### Key Insights:
1. ✅ 30% discount significantly outperforms 10% discount
2. ✅ Higher discount drives much better conversion without sacrificing LTV
3. ⚠️ Low renewal rates (~6%) indicate retention opportunity
4. ⚠️ Profit per workspace slightly lower with 30% discount
5. ✅ Most conversions on STARTER plan (monthly)

---

## ✅ Deliverables - COMPLETE

### 1. Complete dbt Project ✅
- Proper layering: staging → intermediate → marts
- Full documentation in YAML files
- 30 data quality tests configured
- All models compile successfully

### 2. Working Analysis Queries ✅
- 3 SQL queries in `analyses/` folder
- All tested and working
- Results exported to CSV

### 3. Final Report ✅
- File: `AB_TEST_ANALYSIS_REPORT.md`
- 1-2 page analysis with:
  - Executive summary
  - Detailed findings
  - Statistical analysis
  - Clear winner determination
  - Actionable recommendations

### 4. Documentation ✅
- Comprehensive `README.md` with setup instructions
- Schema notes and quirks documented
- All YAML documentation complete

---

## 📋 How to Use This Project

### Run Analysis Queries

```bash
# Navigate to project
cd /Users/mariyemsqalli/arcads_case

# Run main A/B test analysis
PGPASSWORD='7fy8iQGEfPUDjJ4JMxug' psql -h test-db.csuvza3lg5wp.eu-west-3.rds.amazonaws.com \
  -U data-analysis-test -d data-analysis-test \
  -f analyses/ab_test_paywall_analysis.sql

# Run plan-level analysis
PGPASSWORD='7fy8iQGEfPUDjJ4JMxug' psql -h test-db.csuvza3lg5wp.eu-west-3.rds.amazonaws.com \
  -U data-analysis-test -d data-analysis-test \
  -f analyses/plan_level_analysis.sql

# Run engagement analysis
PGPASSWORD='7fy8iQGEfPUDjJ4JMxug' psql -h test-db.csuvza3lg5wp.eu-west-3.rds.amazonaws.com \
  -U data-analysis-test -d data-analysis-test \
  -f analyses/engagement_analysis.sql
```

### Verify dbt Setup

```bash
# Test connection
dbt debug

# List all models
dbt list

# Compile models (read-only, won't materialize)
dbt compile
```

---

## 🎯 Recommendations for Next Steps

### Immediate Actions (Post-Interview):
1. **Roll out 30% discount** to 100% of users
2. **Focus on retention optimization** (current 6% renewal rate needs improvement)
3. **Implement upsell strategies** to increase ARPU
4. **Monitor long-term metrics** (6-12 month LTV, retention curves)

### Future Tests:
1. Test longer discount periods (3 months vs 1 month)
2. Test graduated discounts (30% → 20% → 10% over time)
3. Test discount on yearly plans
4. Test different discount levels (20%, 25%, 35%)

---

## ✅ Project Quality Checklist

- ✅ dbt project follows best practices (staging → intermediate → marts)
- ✅ All models have proper documentation
- ✅ Data quality tests configured (unique, not_null)
- ✅ Consistent naming conventions (stg_, int_, dim_, fct_)
- ✅ SQL queries follow best practices (CTEs, clear logic)
- ✅ Analysis is statistically sound
- ✅ Recommendations are actionable and data-driven
- ✅ Documentation is comprehensive and clear
- ✅ All queries tested and working
- ✅ Results exported and ready for presentation

---

## 📊 Files Ready for Interview Submission

1. **AB_TEST_ANALYSIS_REPORT.md** - Main analysis report (1-2 pages)
2. **README.md** - Project documentation and setup
3. **analyses/ab_test_results.csv** - Exported results
4. **analyses/*.sql** - All analysis queries
5. **models/** - Complete dbt project with all layers
6. **This file (PROJECT_STATUS.md)** - Project status summary

---

## ✅ READY FOR INTERVIEW SUBMISSION

All deliverables are complete, tested, and ready for presentation. The analysis clearly shows the 30% discount as the winner with actionable recommendations for next steps.

**Good luck with your interview! 🚀**
