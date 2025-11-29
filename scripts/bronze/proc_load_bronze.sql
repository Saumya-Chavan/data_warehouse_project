-- MySQL 8+ version of bronze.load_bronze
-- Usage: CALL bronze.load_bronze();

DROP PROCEDURE IF EXISTS bronze.load_bronze;
DELIMITER $$

CREATE PROCEDURE bronze.load_bronze()
BEGIN
    DECLARE v_start_time DATETIME;
    DECLARE v_end_time DATETIME;
    DECLARE v_batch_start DATETIME;
    DECLARE v_batch_end DATETIME;
    DECLARE v_err_msg TEXT DEFAULT NULL;

    -- Error handler: capture error & continue to the end (you can change behavior if you want)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_err_msg = MESSAGE_TEXT;
        SET v_batch_end = NOW();
        SELECT '==========================================' AS info;
        SELECT 'ERROR OCCURRED DURING LOADING BRONZE LAYER' AS info;
        SELECT CONCAT('Error: ', IFNULL(v_err_msg,'(no message)')) AS error_message;
        SELECT CONCAT('Total elapsed seconds: ',
                      TIMESTAMPDIFF(SECOND, v_batch_start, v_batch_end)) AS elapsed_seconds;
        SELECT '==========================================' AS info;
    END;

    SET v_batch_start = NOW();

    SELECT '================================================' AS info;
    SELECT 'Loading Bronze Layer' AS info;
    SELECT '================================================' AS info;

    -- -----------------------
    -- CRM Tables
    -- -----------------------

    -- crm_cust_info
    SET v_start_time = NOW();
    SELECT '>> Truncating Table: bronze.crm_cust_info' AS info;
    TRUNCATE TABLE bronze.crm_cust_info;

    SELECT '>> Loading Data Into: bronze.crm_cust_info' AS info;
    -- Use LOAD DATA INFILE (server side) or LOAD DATA LOCAL INFILE (client side)
   USE bronze;

      -- ==========================================================
      -- Load CRM Product Info (crm_prd_info)
      -- ==========================================================
      TRUNCATE TABLE bronze.crm_prd_info;

      LOAD DATA LOCAL INFILE 
      '/Users/saumyachavan/Downloads/sql-data-warehouse-project/datasets/source_crm/prd_info_end.csv'
      INTO TABLE bronze.crm_prd_info
      FIELDS TERMINATED BY ',' 
      ENCLOSED BY '"' 
      LINES TERMINATED BY '\r\n'
      IGNORE 1 ROWS
      (
          prd_id,
          prd_key,
          prd_nm,
          @prd_cost,
          prd_line,
          prd_start_dt,
          @prd_end_dt
      )
      SET 
          prd_cost = NULLIF(@prd_cost, ''),
          prd_end_dt = STR_TO_DATE(TRIM(NULLIF(@prd_end_dt, '')), '%Y-%m-%d');
          

      -- ==========================================================
      -- Load ERP Customer Info (erp_cust_az12)
      -- ==========================================================
      TRUNCATE TABLE bronze.erp_cust_az12;

      LOAD DATA LOCAL INFILE 
      '/Users/saumyachavan/Downloads/sql-data-warehouse-project/datasets/source_erp/cust_az12.csv'
      INTO TABLE bronze.erp_cust_az12
      FIELDS TERMINATED BY ',' 
      ENCLOSED BY '"' 
      LINES TERMINATED BY '\r\n'
      IGNORE 1 ROWS;


-- ==========================================================
-- Load ERP Location Info (erp_loc_a101)
-- ==========================================================
    TRUNCATE TABLE bronze.erp_loc_a101;

    LOAD DATA LOCAL INFILE 
    '/Users/saumyachavan/Downloads/sql-data-warehouse-project/datasets/source_erp/loc_a101.csv'
    INTO TABLE bronze.erp_loc_a101
    FIELDS TERMINATED BY ',' 
    ENCLOSED BY '"' 
    LINES TERMINATED BY '\r\n'
    IGNORE 1 ROWS;


    SET v_end_time = NOW();
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS info;
    SELECT '>> -------------' AS info;

    -- erp_cust_az12
    SET v_start_time = NOW();
    SELECT '>> Truncating Table: bronze.erp_cust_az12' AS info;
    TRUNCATE TABLE bronze.erp_cust_az12;

    SELECT '>> Loading Data Into: bronze.erp_cust_az12' AS info;
    LOAD DATA INFILE '/Users/saumyachavan/Downloads/sql-data-warehouse-project/datasets/source_erp/cust_az12.csv'
    INTO TABLE bronze.erp_cust_az12
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;

    SET v_end_time = NOW();
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS info;
    SELECT '>> -------------' AS info;

    -- erp_px_cat_g1v2
    SET v_start_time = NOW();
    SELECT '>> Truncating Table: bronze.erp_px_cat_g1v2' AS info;
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    SELECT '>> Loading Data Into: bronze.erp_px_cat_g1v2' AS info;
    LOAD DATA INFILE '/Users/saumyachavan/Downloads/sql-data-warehouse-project/datasets/source_erp/px_cat_g1v2.csv'
    INTO TABLE bronze.erp_px_cat_g1v2
    FIELDS TERMINATED BY ','
    ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES;

    SET v_end_time = NOW();
    SELECT CONCAT('>> Load Duration: ', TIMESTAMPDIFF(SECOND, v_start_time, v_end_time), ' seconds') AS info;
    SELECT '>> -------------' AS info;

    -- Final summary
    SET v_batch_end = NOW();
    SELECT '==========================================' AS info;
    SELECT 'Loading Bronze Layer is Completed' AS info;
    SELECT CONCAT('   - Total Load Duration: ', TIMESTAMPDIFF(SECOND, v_batch_start, v_batch_end), ' seconds') AS info;
    SELECT '==========================================' AS info;

END$$

DELIMITER ;
