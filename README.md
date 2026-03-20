<<<<<<< HEAD
# aircads-ai-case
=======
# Test dbt connection
cd /Users/mariyemsqalli/arcads_case
dbt debug

# Run analysis queries
PGPASSWORD='7fy8iQGEfPUDjJ4JMxug' psql -h test-db.csuvza3lg5wp.eu-west-3.rds.amazonaws.com \
  -U data-analysis-test -d data-analysis-test \
  -f analyses/ab_test_paywall_analysis.sql
>>>>>>> db713c5 (feat: initial dbt project setup)
