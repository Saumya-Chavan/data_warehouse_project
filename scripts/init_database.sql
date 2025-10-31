/*
=============================================================
Create DataWarehouse and Layered Databases
=============================================================
Script Purpose:
    This script creates one main database named 'datawarehouse'
    and three layer databases — 'bronze', 'silver', and 'gold'.

    If they already exist, they will be dropped and recreated.
=============================================================
*/

-- Drop and recreate main DataWarehouse database
DROP DATABASE IF EXISTS datawarehouse;
CREATE DATABASE datawarehouse;

-- Drop and recreate layer databases
DROP DATABASE IF EXISTS bronze;
CREATE DATABASE bronze;

DROP DATABASE IF EXISTS silver;
CREATE DATABASE silver;

DROP DATABASE IF EXISTS gold;
CREATE DATABASE gold;

-- Optional: verify
SHOW DATABASES;

