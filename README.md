arcads_case/
├── analyses/
│   ├── ab_test_complete_analysis.sql    # Complete analysis query (read-only execution)
│   └── README_AB_TEST_ANALYSIS.md       # Detailed analysis documentation
├── models/
│   ├── staging/                         # Source data transformations
│   │   ├── stg_workspaces.sql
│   │   ├── stg_workspaces_ab_tests.sql
│   │   ├── stg_stripe_subscription_histories.sql
│   │   ├── stg_stripe_payment_histories.sql
│   │   ├── stg_credits_consumption_events.sql
│   │   ├── stg_videos.sql
│   │   ├── stg_video_assets.sql
│   │   ├── stg_costs.sql
│   │   ├── stg_meta_ads.sql
│   │   ├── stg_plans.sql
│   │   ├── stg_products.sql
│   │   ├── stg_folders.sql
│   │   ├── stg_projects.sql
│   │   └── stg_scripts.sql
│   ├── intermediate/                    # Business logic transformations
│   │   ├── int_first_subscriptions.sql  # First subscription per workspace
│   │   └── int_workspace_metrics.sql    # Aggregated workspace metrics
│   └── marts/
│       └── core/                        # Final fact tables
│           ├── fct_ab_test_paywall.sql  # Comprehensive AB test fact table
│           └── fct_ab_test_analysis.sql # Final analysis with metrics
├── seeds/
│   └── meta_ads.csv                     # Meta Ads spend data (external source)
├── dbt_project.yml                      # dbt project configuration
└── README.md                            # This file