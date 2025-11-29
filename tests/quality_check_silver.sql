/*
===============================================================================
Quality Checks -
===============================================================================
Script Purpose:
    Data consistency / standardization checks on the silver layer.
===============================================================================
*/

-- ====================================================================
-- Checking 'silver.crm_cust_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    cst_id,
    COUNT(*) AS cnt
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT 
    cst_key
FROM silver.crm_cust_info
WHERE cst_key <> TRIM(cst_key);

-- Data Standardization & Consistency (distinct marital statuses)
SELECT DISTINCT 
    cst_marital_status
FROM silver.crm_cust_info;


-- ====================================================================
-- Checking 'silver.crm_prd_info'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT 
    prd_id,
    COUNT(*) AS cnt
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT 
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm <> TRIM(prd_nm);

-- Check for NULLs or Negative Values in Cost
-- Expectation: No Results
SELECT 
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- Data Standardization & Consistency (distinct product lines)
SELECT DISTINCT 
    prd_line
FROM silver.crm_prd_info;

-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
-- Assumes prd_start_dt and prd_end_dt are DATE or DATETIME; if stored as strings you may need STR_TO_DATE()
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_start_dt IS NOT NULL
  AND prd_end_dt < prd_start_dt;


-- ====================================================================
-- Checking 'silver.crm_sales_details'
-- ====================================================================
-- Check for Invalid Dates
-- Expectation: No Results
-- Assumes sls_due_dt is stored as an integer YYYYMMDD or as a string of length 8.
SELECT 
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM silver.crm_sales_details
WHERE sls_due_dt <= 0
   OR CHAR_LENGTH(CAST(sls_due_dt AS CHAR)) <> 8
   OR CAST(sls_due_dt AS UNSIGNED) > 20500101
   OR CAST(sls_due_dt AS UNSIGNED) < 19000101;

-- Check for Invalid Date Orders (Order Date > Shipping/Due Dates)
-- Assumes sls_order_dt, sls_ship_dt, sls_due_dt are DATE or comparable numeric YYYYMMDD
SELECT *
FROM silver.crm_sales_details
WHERE (sls_order_dt IS NOT NULL AND sls_ship_dt IS NOT NULL AND sls_order_dt > sls_ship_dt)
   OR (sls_order_dt IS NOT NULL AND sls_due_dt  IS NOT NULL AND sls_order_dt > sls_due_dt);

-- Check Data Consistency: Sales = Quantity * Price
-- Expectation: No Results
SELECT DISTINCT 
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
   OR sls_sales <> (sls_quantity * sls_price)
ORDER BY sls_sales, sls_quantity, sls_price;


-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================
-- Identify Out-of-Range Dates
-- Expectation: Birthdates between 1924-01-01 and Today
-- Assumes bdate is DATE or DATE-like; adjust if stored as string.
SELECT DISTINCT 
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
   OR bdate > CURDATE();

-- Data Standardization & Consistency (distinct genders)
SELECT DISTINCT 
    gen
FROM silver.erp_cust_az12;


-- ====================================================================
-- Checking 'silver.erp_loc_a101'
-- ====================================================================
-- Data Standardization & Consistency (distinct countries)
SELECT DISTINCT 
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;


-- ====================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ====================================================================
-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE cat  <> TRIM(cat)
   OR subcat <> TRIM(subcat)
   OR maintenance <> TRIM(maintenance);

-- Data Standardization & Consistency (distinct maintenance values)
SELECT DISTINCT 
    maintenance
FROM silver.erp_px_cat_g1v2;
