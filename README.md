arcads_case/
├── analyses/
│   ├── ab_test_complete_analysis.sql    # Complete analysis query (read-only)
│   └── README_AB_TEST_ANALYSIS.md       # Detailed analysis documentation
├── models/
│   ├── staging/                         # Source data transformations
│   │   ├── stg_workspaces.sql
│   │   ├── stg_workspaces_ab_tests.sql
│   │   ├── stg_stripe_subscription_histories.sql
│   │   ├── stg_stripe_payment_histories.sql
│   │   ├── stg_credits_consumption_events.sql
│   │   ├── stg_meta_ads.sql
│   │   └── ... (other staging models)
│   ├── intermediate/                    # Business logic transformations
│   │   ├── int_first_subscriptions.sql
│   │   └── int_workspace_metrics.sql
│   └── marts/
│       └── core/                        # Final fact tables
│           ├── fct_ab_test_paywall.sql
│           └── fct_ab_test_analysis.sql
├── seeds/
│   └── meta_ads.csv                     # Meta Ads spend data
└── dbt_project.yml