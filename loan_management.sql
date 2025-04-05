# Loan Management Project - Complete SQL Script
-- sql
-- Create the database and set it as active
CREATE DATABASE loan_management_project;
USE loan_management_project;

/* 
SECTION 1: CUSTOMER INCOME ANALYSIS
This section focuses on analyzing customer income data and creating classifications
*/

-- 1.1 View imported customer income data
SELECT * FROM customer_income;
SELECT COUNT(*) FROM customer_income;

-- 1.2 Classify customers based on applicant income
SELECT *, 
    CASE
        WHEN Applicant_Income > 15000 THEN "A Grade"
        WHEN Applicant_Income > 9000 THEN "B Grade"
        WHEN Applicant_Income > 5000 THEN "Middle Class Customer"
        ELSE "Low class"
    END AS Grade 
FROM customer_income;

-- 1.3 Set monthly interest rates based on income and property area
SELECT *, 
    CASE 
        WHEN Applicant_Income < 5000 AND Property_Area = "rural" THEN "3"
        WHEN Applicant_Income < 5000 AND Property_Area = "Semi rural" THEN "3.5"
        WHEN Applicant_Income < 5000 AND Property_Area = "Urban" THEN "5"
        WHEN Applicant_Income < 5000 AND Property_Area = "Semi Urban" THEN "2.5"
        ELSE "7"
    END AS Monthly_interest_rate
FROM customer_income;

-- 1.4 Create a new table with customer classifications and interest rates
CREATE TABLE Loan_details AS
SELECT *, 
    CASE
        WHEN Applicant_Income > 15000 THEN "A Grade"
        WHEN Applicant_Income > 9000 THEN "B Grade"
        WHEN Applicant_Income > 5000 THEN "Middle Class Customer"
        ELSE "Low class"
    END AS Grade,
    CASE 
        WHEN Applicant_Income < 5000 AND Property_Area = "rural" THEN "3"
        WHEN Applicant_Income < 5000 AND Property_Area = "Semi rural" THEN "3.5"
        WHEN Applicant_Income < 5000 AND Property_Area = "Urban" THEN "5"
        WHEN Applicant_Income < 5000 AND Property_Area = "Semi Urban" THEN "2.5"
        ELSE "7"
    END AS Monthly_interest_rate
FROM customer_income; 

-- Verify the new table
SELECT * FROM Loan_details;
SELECT COUNT(*) FROM Loan_details;

/*
SECTION 2: LOAN STATUS PROCESSING
This section handles loan status tracking with triggers for automated processing
*/

-- 2.1 Create loan status and cibil score tracking tables
CREATE TABLE Loan_status(
    Loan_ID VARCHAR(25) PRIMARY KEY, 
    Customer_id TEXT, 
    LoanAmount VARCHAR(50), 
    Loan_Amount_Term INT, 
    Cibil_Score INT
);

CREATE TABLE Cibil_table(
    Loan_ID VARCHAR(25), 
    Loanamount VARCHAR(50), 
    Cibil_Score INT, 
    Cibil_Score_status VARCHAR(50)
);

-- 2.2 Create trigger to handle null loan amounts
DELIMITER ??
CREATE TRIGGER loan_amount_verify BEFORE INSERT ON loan_status FOR EACH ROW
BEGIN
    IF NEW.LoanAmount IS NULL THEN 
        SET NEW.LoanAmount = 'Loan Still Processing';
    END IF;
END ??
DELIMITER ;

-- 2.3 Create trigger to evaluate CIBIL scores
DELIMITER ??
CREATE TRIGGER cibil_verify BEFORE INSERT ON loan_status FOR EACH ROW
BEGIN
    -- Apply cibil score conditioning
    INSERT INTO Cibil_table(Loan_ID, Loanamount, Cibil_Score, Cibil_Score_status)
    VALUES (NEW.Loan_ID, NEW.Loanamount, NEW.Cibil_Score,
        CASE 
            WHEN NEW.Cibil_Score > 900 THEN "High cibil score" 
            WHEN NEW.Cibil_Score > 750 THEN "No penalty"
            WHEN NEW.Cibil_Score > 0 THEN "Penalty customers" 
            ELSE "Reject Customers (Loan cannot apply)"
        END
    ); 
END ??
DELIMITER ;

-- 2.4 Combined trigger for both loan amount and CIBIL processing
DELIMITER ??
CREATE TRIGGER cibil_verify_table BEFORE INSERT ON loan_status FOR EACH ROW
BEGIN
    -- Handle null loan amounts
    IF NEW.LoanAmount IS NULL THEN 
        SET NEW.LoanAmount = 'Loan Still Processing';
    END IF;
    
    -- Apply cibil score conditioning
    INSERT INTO Cibil_table(Loan_ID, Loanamount, Cibil_Score, Cibil_Score_status)
    VALUES (NEW.Loan_ID, NEW.Loanamount, NEW.Cibil_Score,
        CASE 
            WHEN NEW.Cibil_Score > 900 THEN "High cibil score" 
            WHEN NEW.Cibil_Score > 750 THEN "No penalty"
            WHEN NEW.Cibil_Score > 0 THEN "Penalty customers" 
            ELSE "Reject Customers (Loan cannot apply)"
        END
    ); 
END ??
DELIMITER ;

-- 2.5 Import loan status data and verify
INSERT INTO loan_status (SELECT * FROM loan_status_copy);
SELECT * FROM Loan_status;

-- 2.6 Create loan status details table with CIBIL information
CREATE TABLE loan_cibil_score_status_details AS
SELECT L.*, C.Cibil_Score_status 
FROM Loan_status L 
JOIN Cibil_table C ON L.Loan_ID = C.Loan_ID;

-- 2.7 Filter out rejected and processing loans
SELECT * FROM loan_cibil_score_status_details 
WHERE Cibil_Score_status = "Reject Customers (Loan cannot apply)" 
OR LoanAmount = "Loan still Processing";

SELECT COUNT(*) FROM loan_cibil_score_status_details 
WHERE Cibil_Score_status = "Reject Customers (Loan cannot apply)" 
OR LoanAmount = "Loan still Processing";

-- Remove rejected/processing loans
DELETE FROM loan_cibil_score_status_details 
WHERE Cibil_Score_status = "Reject Customers (Loan cannot apply)" 
OR LoanAmount = "Loan still Processing";

-- Verify filtered data
SELECT * FROM loan_cibil_score_status_details;
SELECT COUNT(*) FROM loan_cibil_score_status_details;

-- 2.8 Convert loan amount to integer
ALTER TABLE loan_cibil_score_status_details MODIFY LoanAmount INT;
DESCRIBE loan_cibil_score_status_details;

/*
SECTION 3: INTEREST CALCULATIONS
This section calculates monthly and annual interest for loans
*/

-- 3.2 Create customer interest analysis table
CREATE TABLE customer_interest_analysis AS 
SELECT 
    d.*, 
    cs.loanamount, 
    cs.loan_amount_term, 
    cs.cibil_score, 
    cs.cibil_score_status,
    ROUND(((monthly_interest_rate / 100) * loanamount), 0) AS Monthly_interest,
    ROUND(((monthly_interest_rate / 100) * loanamount) * 12, 0) AS Annual_interest 
FROM loan_details D 
JOIN loan_cibil_score_status_details CS ON d.loan_ID = CS.loan_ID;

-- Verify interest analysis
SELECT * FROM customer_interest_analysis;

/*
SECTION 4: CUSTOMER INFORMATION MANAGEMENT
This section handles customer demographic data updates
*/

-- 4.1 View customer info and identify missing data
SELECT * FROM customer_info;
SELECT * FROM customer_info WHERE Gender IS NULL OR age IS NULL;

-- 4.2 Update gender information
UPDATE customer_info SET Gender = "Female" 
WHERE Customer_ID IN ('IP43006', 'IP43016', 'IP43508', 'IP43577', 'IP43589', 'IP43593');

UPDATE customer_info SET Gender = "Male" 
WHERE Customer_ID IN ('IP43018', 'IP43038');

-- 4.3 Update age information using CASE statement
UPDATE customer_info SET age = CASE 
    WHEN Customer_ID = 'IP43007' THEN '45'
    WHEN Customer_ID = 'IP43009' THEN '32'
    ELSE age
END;

-- Verify updates
SELECT * FROM customer_info 
WHERE Customer_ID IN ('IP43006', 'IP43016', 'IP43508', 'IP43577', 'IP43589', 'IP43593');

SELECT * FROM customer_info 
WHERE Customer_ID IN ('IP43018', 'IP43038');

SELECT * FROM customer_info 
WHERE Customer_ID IN ('IP43007', 'IP43009');

/*
SECTION 5: GEOGRAPHIC DATA INTEGRATION
This section combines customer data with geographic information
*/

-- 5.1 View geographic tables
SELECT * FROM country_state;
SELECT * FROM region_info;
SELECT * FROM customer_info;

-- 5.2 Join country/state with region info
SELECT 
    c.customer_id,
    c.Load_Id,
    c.Customer_name,
    c.Postal_Code,
    c.Segment,
    c.State,
    r.Region_id,
    r.Region 
FROM country_state c 
JOIN region_info r ON c.Region_id = r.Region_Id 
ORDER BY Region_id;

-- 5.3 Three-way join (customer info + country/state + region)
SELECT 
    C.*, 
    D.region, 
    d.postal_code, 
    d.segment,
    d.state 
FROM customer_info C 
JOIN (
    SELECT C.*, r.region 
    FROM country_state C 
    JOIN region_info r ON c.region_id = r.region_id
) d ON c.customer_id = d.customer_id;

/*
SECTION 6: COMPREHENSIVE REPORTING
This section creates comprehensive reports and procedures
*/

-- 6.1 Create full loan details table combining all information
CREATE TABLE Customer_Full_Loan_details AS
SELECT 
    L.loan_ID,
    L.Customer_ID,
    L.Applicant_Income,
    L.Coapplicant_income,
    L.property_Area,
    L.Loan_status,
    L.Grade,
    L.Monthly_interest_rate,
    L.loanAmount,
    L.loan_amount_term,
    L.Cibil_score,
    L.cibil_score_status,
    L.Monthly_interest,
    L.Annual_interest,
    C.Customer_name,
    c.Gender,
    C.age,
    C.married,
    C.Education,
    C.self_Employed,
    C.Region_Id,
    CS.Postal_code,
    CS.segment,
    CS.state,
    R.region 
FROM customer_interest_analysis L
JOIN customer_info C ON L.Customer_id = C.Customer_id
JOIN Country_state CS ON L.Customer_id = CS.Customer_id
JOIN region_info R ON C.region_id = R.region_id;

-- Verify full loan details
SELECT * FROM Customer_Full_Loan_details;
SELECT COUNT(*) FROM Customer_Full_Loan_details;

-- 6.2 Find mismatched records
SELECT 
    c.*,
    s.postal_code,
    s.segment,
    s.state,
    r.region 
FROM region_info r 
LEFT JOIN customer_info c ON r.region_id = c.region_id 
LEFT JOIN country_state s ON r.region_id = s.region_id 
WHERE c.region_id IS NULL;

-- 6.3 Filter for high CIBIL scores
SELECT * FROM Customer_Full_Loan_details 
WHERE cibil_score_status = 'High Cibil Score';

SELECT COUNT(*) FROM Customer_Full_Loan_details 
WHERE cibil_score_status = 'High Cibil Score';

-- 6.4 Filter for specific segments
SELECT * FROM Customer_Full_Loan_details 
WHERE segment IN ('home office', 'corporate');

SELECT COUNT(*) FROM Customer_Full_Loan_details 
WHERE segment IN ('home office', 'corporate');

/*
SECTION 7: STORED PROCEDURES
This section creates procedures for common reporting needs
*/

-- 7.1 Create comprehensive reporting procedure
DELIMITER ??
CREATE PROCEDURE Customers_loan_data_details()
BEGIN
    -- Full loan details
    SELECT 
        L.*, 
        C.Customer_name,
        c.Gender,
        C.age,
        C.married,
        C.Education,
        C.self_Employed,
        C.Region_Id,
        CS.Postal_code,
        CS.segment,
        CS.state,
        R.region 
    FROM customer_interest_analysis L
    JOIN customer_info C ON L.Customer_id = C.Customer_id
    JOIN Country_state CS ON L.Customer_id = CS.Customer_id
    JOIN region_info R ON C.region_id = R.region_id;

    -- Mismatched records
    SELECT 
        c.*,
        s.postal_code,
        s.segment,
        s.state,
        r.region 
    FROM region_info r 
    LEFT JOIN customer_info c ON r.region_id = c.region_id 
    LEFT JOIN country_state s ON r.region_id = s.region_id 
    WHERE c.region_id IS NULL;

    -- High CIBIL scores
    SELECT * FROM Customer_Full_Loan_details 
    WHERE cibil_score_status = 'High Cibil Score';

    -- Segment filter
    SELECT * FROM Customer_Full_Loan_details 
    WHERE segment IN ('home office', 'corporate');
END ??
DELIMITER ;

-- 7.2 Test procedure
SHOW PROCEDURE STATUS WHERE name = 'Customers_loan_data_details';
CALL Customers_loan_data_details();
DROP PROCEDURE Customers_loan_data_details;

/*
SECTION 8: DATABASE CONSTRAINTS
This section establishes referential integrity through foreign keys
*/

-- 8.1 Set foreign key constraints
ALTER TABLE Loan_status ADD CONSTRAINT Customer_loan_details_key  
    FOREIGN KEY (Customer_ID) REFERENCES customer_income(Customer_ID);

ALTER TABLE Loan_details ADD CONSTRAINT Customer_key 
    FOREIGN KEY (Customer_ID) REFERENCES customer_info(Customer_ID);

ALTER TABLE Loan_status ADD CONSTRAINT Loan_key  
    FOREIGN KEY (Loan_ID) REFERENCES Loan_details(loan_ID);

ALTER TABLE customer_info ADD CONSTRAINT Region_key  
    FOREIGN KEY (Region_ID) REFERENCES region_info(Region_ID);

ALTER TABLE Loan_status ADD CONSTRAINT Customer_loan_key  
    FOREIGN KEY (Customer_ID) REFERENCES customer_info(Customer_ID);

ALTER TABLE customer_interest_analysis ADD CONSTRAINT Interest_key  
    FOREIGN KEY (Customer_ID) REFERENCES customer_info(Customer_ID);

ALTER TABLE country_state ADD CONSTRAINT Country_region_key  
    FOREIGN KEY (Region_ID) REFERENCES region_info(Region_ID);

ALTER TABLE Cibil_table ADD CONSTRAINT Loan_Cibil_key  
    FOREIGN KEY (Loan_ID) REFERENCES Loan_status(Loan_ID);

-- 8.2 Modify table structures to support constraints
ALTER TABLE customer_income 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(30) NOT NULL, 
    ADD PRIMARY KEY (Customer_ID);

ALTER TABLE customer_interest_analysis 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(30) NULL DEFAULT NULL;

ALTER TABLE customer_interest_analysis 
    CHANGE COLUMN loanamount loanamount VARCHAR(30) NULL DEFAULT NULL;

ALTER TABLE customer_interest_analysis 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(30) NOT NULL,
    ADD PRIMARY KEY (Customer_ID);

ALTER TABLE customer_info 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(40) NULL DEFAULT NULL;

ALTER TABLE customer_info 
    CHANGE COLUMN Loan_Id Loan_Id VARCHAR(30) NULL DEFAULT NULL;

ALTER TABLE customer_info 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(40) NOT NULL, 
    ADD PRIMARY KEY (Customer_ID);

ALTER TABLE loan_details 
    CHANGE COLUMN Customer_ID Customer_ID VARCHAR(40) NULL DEFAULT NULL;

ALTER TABLE loan_details 
    CHANGE COLUMN Loan_ID Loan_ID VARCHAR(25) NOT NULL, 
    ADD PRIMARY KEY (Loan_ID);

ALTER TABLE loan_status 
    CHANGE COLUMN Customer_id Customer_id VARCHAR(30) NULL DEFAULT NULL;

ALTER TABLE region_info 
    ADD PRIMARY KEY (Region_Id);

ALTER TABLE country_state 
    CHANGE COLUMN Loan_Id Loan_Id VARCHAR(30) NULL DEFAULT NULL;

ALTER TABLE country_state 
    CHANGE COLUMN Loan_Id Loan_Id VARCHAR(30) NOT NULL,
    ADD PRIMARY KEY (Loan_Id);

ALTER TABLE country_state 
    CHANGE COLUMN Customer_id Customer_id VARCHAR(30) NOT NULL,
    CHANGE COLUMN Loan_Id Loan_Id VARCHAR(30) NULL,
    DROP PRIMARY KEY, 
    ADD PRIMARY KEY (Customer_id);

/*
SECTION 9: DATA VERIFICATION
This section provides queries to verify all data structures
*/

-- 9.1 View all imported tables
SELECT * FROM customer_income;
SELECT * FROM loan_status;
SELECT * FROM customer_info;
SELECT * FROM country_state;
SELECT * FROM Region_info;
SELECT * FROM loan_status_copy;

-- 9.2 View all created tables
SELECT * FROM loan_details;
SELECT * FROM cibil_table;
SELECT * FROM customer_interest_analysis;
SELECT * FROM loan_cibil_score_status_details;

-- 9.3 Describe table structures
DESC customer_income;
DESC loan_status;
DESC customer_info;
DESC country_state;
DESC Region_info;
DESC loan_status_copy;
DESC loan_details;
DESC cibil_table;
DESC customer_interest_analysis;
DESC loan_cibil_score_status_details;