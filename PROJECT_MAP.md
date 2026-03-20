# 📁 ARCADS CASE STUDY - PROJECT MAP

**Status:** ✅ COMPLETE  
**Date:** March 18, 2026

---

## 📂 Complete File Structure

```
/Users/mariyemsqalli/arcads_case/
│
├── 📄 README.md                          # Project overview and setup
├── 📄 AB_TEST_ANALYSIS_REPORT.md         # ⭐ MAIN DELIVERABLE (1-2 pages)
├── 📄 FINAL_SUMMARY.md                   # Comprehensive summary
├── 📄 PROJECT_STATUS.md                  # Detailed status
├── 📄 SUBMISSION_READY.md                # Submission checklist
├── 📄 dbt_project.yml                    # dbt configuration
│
├── 📁 models/
│   │
│   ├── 📁 staging/                       # 11 staging models (views)
│   │   ├── _sources.yml                  # Source definitions (12 tables)
│   │   ├── _staging_models.yml           # Staging documentation
│   │   ├── stg_users.sql
│   │   ├── stg_workspaces.sql
│   │   ├── stg_plans.sql
│   │   ├── stg_workspaces_ab_tests.sql
│   │   ├── stg_stripe_subscription_histories.sql
│   │   ├── stg_stripe_payment_histories.sql
│   │   ├── stg_credits_consumption_events.sql
│   │   ├── stg_videos.sql
│   │   ├── stg_video_assets.sql
│   │   ├── stg_costs.sql
│   │   └── stg_meta_ads.sql              # Marketing data staging
│   │
│   ├── 📁 intermediate/                  # 2 intermediate models
│   │   ├── _intermediate_models.yml      # Intermediate documentation
│   │   ├── int_first_subscriptions.sql   # First subscription per workspace
│   │   └── int_workspace_metrics.sql     # Aggregated workspace metrics
│   │
│   └── 📁 marts/core/                    # 4 mart models
│       ├── _marts_models.yml             # Marts documentation
│       ├── dim_workspaces.sql            # Workspace dimension
│       ├── dim_plans.sql                 # Plans dimension
│       ├── fct_subscriptions.sql         # Subscription facts
│       └── fct_ab_test_paywall.sql       # A/B test fact table
│
├── 📁 analyses/                          # 4 analysis queries
│   ├── ab_test_paywall_analysis.sql      # ⭐ Main A/B test analysis
│   ├── ab_test_results.csv               # Exported results
│   ├── plan_level_analysis.sql           # Plan breakdown
│   ├── engagement_analysis.sql           # User engagement
│   └── marketing_analysis.sql            # ⭐ Marketing performance
│
└── 📁 seeds/
    └── meta_ads.csv                      # 72 days of Meta ads data
```

---

## 🎯 Key Files for Interview

### 1. Primary Deliverable
**`AB_TEST_ANALYSIS_REPORT.md`** - The main 1-2 page analysis report
- Executive summary
- Detailed findings
- Winner determination (30% discount)
- Recommendations

### 2. Supporting Documentation
- **`FINAL_SUMMARY.md`** - Comprehensive project summary
- **`README.md`** - Project setup and overview
- **`SUBMISSION_READY.md`** - Submission checklist

### 3. Analysis Queries
- **`analyses/ab_test_paywall_analysis.sql`** - Main product analysis
- **`analyses/marketing_analysis.sql`** - Marketing performance
- **`analyses/plan_level_analysis.sql`** - Plan breakdown
- **`analyses/engagement_analysis.sql`** - User engagement

### 4. dbt Models
- **`models/staging/`** - 11 staging models
- **`models/intermediate/`** - 2 intermediate models
- **`models/marts/core/`** - 4 mart models

---

## 📊 Project Statistics

### Code Metrics
- **Total Models:** 17 (11 staging + 2 intermediate + 4 marts)
- **Analysis Queries:** 4
- **Documentation Files:** 5
- **Data Tests:** 31
- **Source Tables:** 12
- **Seed Files:** 1 (72 rows of marketing data)

### Lines of Code
- **SQL Files:** ~1,500 lines
- **YAML Documentation:** ~800 lines
- **Markdown Documentation:** ~1,200 lines
- **Total:** ~3,500 lines

---

## 🏆 Analysis Results Summary

### Winner: 30% Discount (Cohort B)

#### Product Metrics
| Metric | Lift |
|--------|------|
| Conversion Rate | **+48.24%** |
| LTV per Workspace | **+9.06%** |
| Sample Size | 22,500 per cohort |

#### Marketing Metrics
| Metric | Improvement |
|--------|-------------|
| Sign-up to Purchase Conv. | **+201%** |
| Cost per Purchase | **-12%** |
| Marketing Efficiency | Significantly improved |

---

## 🚀 Quick Start Commands

### Verify Setup
```bash
cd /Users/mariyemsqalli/arcads_case
dbt debug
dbt list
```

### Run Main Analysis
```bash
PGPASSWORD='7fy8iQGEfPUDjJ4JMxug' psql \
  -h test-db.csuvza3lg5wp.eu-west-3.rds.amazonaws.com \
  -U data-analysis-test \
  -d data-analysis-test \
  -f analyses/ab_test_paywall_analysis.sql
```

### Compile All Models
```bash
dbt compile
```

---

## ✅ Completion Checklist

### dbt Project
- ✅ 11 staging models created and documented
- ✅ 2 intermediate models created
- ✅ 4 mart models created
- ✅ 31 data quality tests configured
- ✅ 12 source tables documented
- ✅ Complete YAML documentation
- ✅ Proper naming conventions (stg_, int_, dim_, fct_)

### Analysis
- ✅ Main A/B test analysis completed
- ✅ Marketing performance analysis completed
- ✅ Plan-level analysis completed
- ✅ Engagement analysis completed
- ✅ Results exported and documented

### Documentation
- ✅ Main analysis report (1-2 pages)
- ✅ README with setup instructions
- ✅ Project status document
- ✅ Submission checklist
- ✅ Final comprehensive summary

### Data Quality
- ✅ All queries tested and working
- ✅ Marketing data loaded (72 days)
- ✅ Large sample sizes (~22,500 per cohort)
- ✅ Statistical significance confirmed
- ✅ Multiple validation checks

---

## 🎓 Technical Highlights

### Database Schema Mastery
- Identified correct column names (`feature` not `abTestName`)
- Handled UUID type casting
- Worked around read-only access constraints
- Used `analyses/` folder for direct SQL queries

### dbt Best Practices
- Proper layering (staging → intermediate → marts)
- Consistent naming conventions
- Complete documentation
- Data quality tests
- Source definitions with freshness

### SQL Excellence
- CTEs for clarity
- Window functions for lift calculations
- Proper aggregations
- Null handling
- Statistical rigor

### Data Integration
- Loaded external marketing data via seeds
- Created staging model for marketing data
- Integrated product and marketing analysis
- Cross-validated findings

---

## 📈 Business Impact

### Immediate (Week 1)
- Roll out 30% discount to 100% of users
- Expected: +48% conversion rate increase

### Short-term (1-3 months)
- ~50% more paid users
- 12% better marketing ROI
- Larger customer base

### Long-term (6-12 months)
- Positive LTV if retention improves to 15%+
- Market share gains
- Upsell opportunities

---

## 🎯 Interview Presentation Flow

### 1. Introduction (1 min)
- "I analyzed two A/B tests on Arcads paywall: 10% and 30% discounts"
- "Built complete dbt project with 17 models"
- "Integrated product and marketing data"

### 2. Methodology (2 min)
- Show dbt project structure
- Explain layering approach (staging → intermediate → marts)
- Highlight data quality tests

### 3. Key Findings (3 min)
- **30% discount is clear winner**
- Product: +48% conversion, +9% LTV
- Marketing: +201% conversion rate, -12% CAC
- Large sample size (22,500 per cohort)

### 4. Recommendations (2 min)
- Roll out 30% discount immediately
- Scale marketing investment (better ROI)
- Focus on retention optimization
- Test longer discount periods

### 5. Q&A
- Be ready to discuss technical approach
- Explain how you handled challenges
- Show code examples if requested

---

## 📞 Final Status

**✅ PROJECT COMPLETE**

**Winner:** 30% Discount  
**Conversion Lift:** +48.24%  
**LTV Lift:** +9.06%  
**Marketing Efficiency:** +12%

**Recommendation:** Implement immediately with retention focus

**Status:** READY FOR INTERVIEW PRESENTATION 🚀

---

*All files are complete, tested, and ready for submission.*
