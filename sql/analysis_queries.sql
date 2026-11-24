-- Loan Default Risk Analysis: MySQL queries (database: loan_db, table: loans)
USE loan_db;

-- 1. Default rate by grade
SELECT grade, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM loans GROUP BY grade ORDER BY grade;

-- 2. Default rate by purpose, ranked (window function)
SELECT purpose, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct,
       RANK() OVER (ORDER BY AVG(`default`) DESC) AS risk_rank
FROM loans GROUP BY purpose;

-- 3. Default rate by income band (CTE)
WITH banded AS (
  SELECT `default`,
         CASE WHEN annual_inc < 40000 THEN '1. Under 40k'
              WHEN annual_inc < 80000 THEN '2. 40k-80k'
              WHEN annual_inc < 120000 THEN '3. 80k-120k'
              ELSE '4. Over 120k' END AS income_band
  FROM loans
)
SELECT income_band, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM banded GROUP BY income_band ORDER BY income_band;

-- 4. Default rate by year
SELECT issue_year, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM loans GROUP BY issue_year ORDER BY issue_year;

-- 5. Share of loans vs share of defaults by grade (cumulative Pareto)
WITH g AS (
  SELECT grade, COUNT(*) AS loans, SUM(`default`) AS defaults FROM loans GROUP BY grade
)
SELECT grade, loans, defaults,
       ROUND(loans * 100 / SUM(loans) OVER (), 2) AS pct_of_loans,
       ROUND(defaults * 100 / SUM(defaults) OVER (), 2) AS pct_of_defaults,
       ROUND(SUM(defaults) OVER (ORDER BY grade) * 100 / SUM(defaults) OVER (), 2) AS cumulative_pct_defaults
FROM g ORDER BY grade;

-- 6. Year-over-year change in default rate (LAG)
WITH y AS (
  SELECT issue_year, COUNT(*) AS loans, AVG(`default`) * 100 AS rate FROM loans GROUP BY issue_year
)
SELECT issue_year, loans, ROUND(rate, 2) AS default_rate_pct,
       ROUND(rate - LAG(rate) OVER (ORDER BY issue_year), 2) AS change_vs_prev_year
FROM y ORDER BY issue_year;

-- 7. Riskiest states (minimum 5,000 loans)
SELECT addr_state, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct,
       RANK() OVER (ORDER BY AVG(`default`) DESC) AS risk_rank
FROM loans GROUP BY addr_state HAVING COUNT(*) >= 5000
ORDER BY risk_rank LIMIT 10;

-- 8. Default rate by debt-to-income band
SELECT CASE WHEN dti < 10 THEN '1. Under 10' WHEN dti < 20 THEN '2. 10-20'
            WHEN dti < 30 THEN '3. 20-30' ELSE '4. 30+' END AS dti_band,
       COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM loans WHERE dti IS NOT NULL GROUP BY dti_band ORDER BY dti_band;

-- 9. Default rate by interest-rate quintile (NTILE)
WITH q AS (
  SELECT `default`, int_rate, NTILE(5) OVER (ORDER BY int_rate) AS rate_quintile FROM loans
)
SELECT rate_quintile, COUNT(*) AS loans, ROUND(MIN(int_rate), 2) AS min_rate,
       ROUND(MAX(int_rate), 2) AS max_rate, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM q GROUP BY rate_quintile ORDER BY rate_quintile;

-- 10. Dollar exposure lost to defaults by grade
SELECT grade, ROUND(SUM(loan_amnt) / 1e6, 1) AS total_issued_millions,
       ROUND(SUM(CASE WHEN `default` = 1 THEN loan_amnt ELSE 0 END) / 1e6, 1) AS defaulted_millions,
       ROUND(SUM(CASE WHEN `default` = 1 THEN loan_amnt ELSE 0 END) * 100 / SUM(loan_amnt), 2) AS dollar_default_rate_pct
FROM loans GROUP BY grade ORDER BY grade;

-- 11. Term vs verification status
SELECT term, verification_status, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM loans GROUP BY term, verification_status ORDER BY term, default_rate_pct DESC;

-- 12. Highest-risk segments (grade + purpose, minimum 2,000 loans)
SELECT grade, purpose, COUNT(*) AS loans, ROUND(AVG(`default`) * 100, 2) AS default_rate_pct
FROM loans GROUP BY grade, purpose HAVING COUNT(*) >= 2000
ORDER BY default_rate_pct DESC LIMIT 10;