/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to populate the 'silver' database tables from the 'bronze'
    database.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL silver.load_silver;
===============================================================================
*/
DELIMITER //

CREATE OR REPLACE PROCEDURE silver_load_silver()
BEGIN
    -- 1. Declare Variables
    DECLARE total_start_time DATETIME;
    DECLARE step_start_time DATETIME;
    DECLARE step_time_in_seconds DECIMAL(10, 2);
    DECLARE total_time_in_seconds DECIMAL(10, 2);

    DECLARE oops_code CHAR(5);
    DECLARE oops_message TEXT;

    -- Error Handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            oops_code = RETURNED_SQLSTATE,
            oops_message = MESSAGE_TEXT;
        SELECT '=====================================================================================' AS message;
        SELECT '**LOAD FAILED!** An error interrupted the Silver layer process.' AS message;
        SELECT CONCAT('Error State: ', oops_code, ' | Problem: ', oops_message) AS message;
        SELECT '=====================================================================================' AS message;
    END;

    -- Start Timing
    SET total_start_time = NOW();
    SELECT '=====================================================================================' AS message;
    SELECT CONCAT('**STARTING SILVER LOAD** at: ', DATE_FORMAT(total_start_time, '%Y-%m-%d %H:%i:%s')) AS message;
    SELECT '=====================================================================================' AS message;

    -- CRM Section
    SELECT '-------------------------------------------------------------------------------------' AS message;
    SELECT '>> SECTION: Customer Relationship Management (CRM) Data' AS message;
    SELECT '-------------------------------------------------------------------------------------' AS message;

    -- STEP 1: crm_cust_info
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.crm_cust_info;

    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        t.cst_id, t.cst_key, TRIM(t.cst_firstname), TRIM(t.cst_lastname),
        CASE
            WHEN UPPER(TRIM(t.cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(t.cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'Unavailable'
        END,
        CASE
            WHEN UPPER(TRIM(t.cst_gndr)) = 'F' THEN 'Female'
            WHEN UPPER(TRIM(t.cst_gndr)) = 'M' THEN 'Male'
            ELSE 'Unknown'
        END,
        t.cst_create_date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) AS t
    WHERE t.flag = 1;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 1 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- STEP 2: crm_prd_info
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.crm_prd_info;

    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt
    )
    SELECT 
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(prd_key, 7) AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0),
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'N/A'
        END,
        CAST(prd_start_dt AS DATE),
        DATE_SUB(
            LEAD(CAST(prd_start_dt AS DATE)) OVER (PARTITION BY prd_key ORDER BY prd_start_dt, prd_id),
            INTERVAL 1 DAY
        )
    FROM bronze.crm_prd_info;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 2 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- STEP 3: crm_sales_details
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.crm_sales_details;

    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price
    )
    SELECT
        sls_ord_num, sls_prd_key, sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR CHAR_LENGTH(CAST(sls_order_dt AS CHAR)) != 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_ship_dt = 0 OR CHAR_LENGTH(CAST(sls_ship_dt AS CHAR)) != 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR), '%Y%m%d') END,
        CASE WHEN sls_due_dt = 0 OR CHAR_LENGTH(CAST(sls_due_dt AS CHAR)) != 8 THEN NULL
             ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR), '%Y%m%d') END,
        CASE
            WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * (
                CASE
                    WHEN sls_price IS NULL OR sls_price <= 0
                    THEN sls_sales * 1.0 / NULLIF(sls_quantity, 0)
                    ELSE ABS(sls_price)
                END
            )
            ELSE sls_sales
        END,
        sls_quantity,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales * 1.0 / NULLIF(sls_quantity, 0)
            ELSE ABS(sls_price)
        END
    FROM bronze.crm_sales_details;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 3 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- ERP Section
    SELECT '-------------------------------------------------------------------------------------' AS message;
    SELECT '>> SECTION: Enterprise Resource Planning (ERP) Data' AS message;
    SELECT '-------------------------------------------------------------------------------------' AS message;

    -- STEP 4: erp_cust_az12
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.erp_cust_az12;

    INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
    SELECT 
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
             ELSE cid
        END,
        CASE WHEN bdate > CURDATE() THEN NULL
             ELSE bdate
        END,
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
            ELSE 'Unknown'
        END
    FROM bronze.erp_cust_az12;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 4 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- STEP 5: erp_loc_a101
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.erp_loc_a101;

    INSERT INTO silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', ''),
        CASE
            WHEN TRIM(cntry) = 'DE' THEN 'Germany'
            WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
            ELSE TRIM(cntry)
        END
    FROM bronze.erp_loc_a101;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 5 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- STEP 6: erp_px_cat_g1v2
    SET step_start_time = NOW();
    TRUNCATE TABLE silver.erp_px_cat_g1v2;

    INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT id, cat, subcat, maintenance
    FROM bronze.erp_px_cat_g1v2;

    SET step_time_in_seconds = TIMESTAMPDIFF(SECOND, step_start_time, NOW());
    SELECT CONCAT('>> Step 6 Duration: ', step_time_in_seconds, ' seconds') AS message;

    -- Summary
    SET total_time_in_seconds = TIMESTAMPDIFF(SECOND, total_start_time, NOW());
    SELECT '=====================================================================================' AS message;
    SELECT '**SILVER LOAD COMPLETE!**' AS message;
    SELECT CONCAT('**Total Load Duration:** ', total_time_in_seconds, ' seconds') AS message;
    SELECT '=====================================================================================' AS message;

END //

DELIMITER ;
