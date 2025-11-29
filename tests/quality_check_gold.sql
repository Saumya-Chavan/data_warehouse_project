/*
===============================================================================
Quality Checks - Gold Layer (MySQL 8+)
===============================================================================
Purpose:
  - Verify uniqueness of surrogate keys in dimensions
  - Detect orphan rows in fact table (missing dimension lookups)
  - Provide quick counts to assess severity
===============================================================================
*/

-- ====================================================================
-- 1) Uniqueness checks
-- ====================================================================
-- customers: duplicates (expect 0 rows)
SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- products: duplicates (expect 0 rows)
SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- ====================================================================
-- 2) NULL or missing surrogate keys in dimensions (sanity)
-- ====================================================================
-- If surrogate keys are nullable this will surface them (should usually be NOT NULL)
SELECT COUNT(*) AS null_customer_keys
FROM gold.dim_customers
WHERE customer_key IS NULL;

SELECT COUNT(*) AS null_product_keys
FROM gold.dim_products
WHERE product_key IS NULL;


-- ====================================================================
-- 3) Orphan detection (fact -> dimension)
-- ====================================================================
-- Option A (readable): LEFT JOIN and show offending rows (small volumes)
SELECT f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p  ON p.product_key   = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;

-- Option B (recommended for counts / severity): use NOT EXISTS for performance
-- Count orphans by reason
SELECT
    SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key) THEN 1 ELSE 0 END) AS orphan_customers,
    SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key) THEN 1 ELSE 0 END)   AS orphan_products,
    COUNT(*) AS total_fact_rows
FROM gold.fact_sales f;

-- Option C (individual count queries)
SELECT COUNT(*) AS orphan_customer_rows
FROM gold.fact_sales f
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key);

SELECT COUNT(*) AS orphan_product_rows
FROM gold.fact_sales f
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key);


-- ====================================================================
-- 4) Optional: show small sample of orphan rows for investigation
-- ====================================================================
SELECT f.order_number, f.customer_key, f.product_key, f.order_date, f.sales_amount
FROM gold.fact_sales f
WHERE NOT EXISTS (SELECT 1 FROM gold.dim_customers c WHERE c.customer_key = f.customer_key)
   OR NOT EXISTS (SELECT 1 FROM gold.dim_products p WHERE p.product_key = f.product_key)
LIMIT 200;


-- ====================================================================
-- 5) Extra: Referential integrity summary (joins + percentages)
-- ====================================================================
-- This gives a quick percentage of fact rows that have matching dims
WITH totals AS (
    SELECT COUNT(*) AS fact_total FROM gold.fact_sales
),
matches AS (
    SELECT COUNT(*) AS matched_count
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON c.customer_key = f.customer_key
    JOIN gold.dim_products p  ON p.product_key   = f.product_key
)
SELECT
    t.fact_total,
    m.matched_count,
    t.fact_total - m.matched_count AS unmatched_count,
    ROUND( (m.matched_count / NULLIF(t.fact_total,0)) * 100, 2) AS pct_matched
FROM totals t CROSS JOIN matches m;
