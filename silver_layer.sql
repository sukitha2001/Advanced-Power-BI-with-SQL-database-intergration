USE hr_dwh;

DROP PROCEDURE IF EXISTS sp_load_all_silver;
DROP PROCEDURE IF EXISTS sp_clean_silver_goals;
DROP PROCEDURE IF EXISTS sp_clean_silver_training;
DROP PROCEDURE IF EXISTS sp_clean_silver_performance_reviews;
DROP PROCEDURE IF EXISTS sp_clean_silver_employees;
DROP PROCEDURE IF EXISTS sp_clean_silver_departments;

DROP FUNCTION IF EXISTS fn_clean_department;
DROP FUNCTION IF EXISTS fn_parse_date;
DROP FUNCTION IF EXISTS fn_clean_gender;
DROP FUNCTION IF EXISTS fn_clean_quarter;

DROP TABLE IF EXISTS silver_goals;
DROP TABLE IF EXISTS silver_training;
DROP TABLE IF EXISTS silver_performance_reviews;
DROP TABLE IF EXISTS silver_employees;
DROP TABLE IF EXISTS silver_departments;

CREATE TABLE silver_departments (
    dept_id                 VARCHAR(10),
    dept_name               VARCHAR(100),
    dep_location            VARCHAR(100),
    manager_id              VARCHAR(20),
    created_date            DATE,
    dep_status              VARCHAR(20),
    headcount_budget        INT,
    cost_center             VARCHAR(20),
    _source_bronze_hash     VARCHAR(64),
    _silver_load_timestamp  DATETIME,
    _is_valid_fk            TINYINT(1),
    PRIMARY KEY (dept_id),
    INDEX idx_silver_dept_name (dept_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE silver_employees (
    employee_id             VARCHAR(20),
    first_name              VARCHAR(100),
    last_name               VARCHAR(100),
    gender                  VARCHAR(10),
    date_of_birth           DATE,
    email                   VARCHAR(150),
    phone                   VARCHAR(20),
    department_id           VARCHAR(10),
    department_name         VARCHAR(100),
    job_title               VARCHAR(150),
    employment_type         VARCHAR(20),
    join_date               DATE,
    salary                  DECIMAL(12,2),
    emp_status              VARCHAR(20),
    emp_location            VARCHAR(100),
    manager_id              VARCHAR(20),
    years_experience        INT,
    -- ── Silver Metadata ──
    _source_bronze_hash     VARCHAR(64),
    _silver_load_timestamp  DATETIME,
    _is_valid_fk            TINYINT(1) DEFAULT 1,
    PRIMARY KEY (employee_id),
    INDEX idx_silver_emp_dept (department_id),
    INDEX idx_silver_emp_status (status),
    INDEX idx_silver_emp_name (last_name, first_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE silver_performance_reviews (
    review_id               VARCHAR(20),
    employee_id             VARCHAR(20),
    review_period           VARCHAR(20),
    review_date             DATE,
    reviewer_id             VARCHAR(20),
    performance_score       DECIMAL(3,1),
    rating_label            VARCHAR(20),
    goals_achieved_pct      DECIMAL(5,1),
    communication_score     DECIMAL(3,1),
    teamwork_score          DECIMAL(3,1),
    leadership_score        DECIMAL(3,1),
    technical_score         DECIMAL(3,1),
    comments                TEXT,
    department              VARCHAR(100),
    created_at              DATE,

    -- ── Silver Metadata ──
    _source_bronze_hash     VARCHAR(64),
    _silver_load_timestamp  DATETIME,
    _is_valid_fk            TINYINT(1) DEFAULT 1,
    PRIMARY KEY (review_id),
    INDEX idx_silver_review_emp (employee_id),
    INDEX idx_silver_review_period (review_period),
    INDEX idx_silver_review_date (review_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE silver_training (
    training_id             VARCHAR(20),
    employee_id             VARCHAR(20),
    course_name             VARCHAR(200),
    category                VARCHAR(50),
    train_start_date        DATE,
    end_date                DATE,
    duration_days           INT,
    completion_status       VARCHAR(20),
    score                   INT,
    cost_lkr                DECIMAL(12,2),
    trainer                 VARCHAR(20),
    department              VARCHAR(100),
    train_year              INT,

    -- ── Silver Metadata ──
    _source_bronze_hash     VARCHAR(64)     COMMENT 'Hash from bronze layer for lineage tracking.',
    _silver_load_timestamp  DATETIME        COMMENT 'Timestamp when this row was loaded into Silver.',
    _is_valid_fk            TINYINT(1)      DEFAULT 1 COMMENT '1 = employee_id FK valid, 0 = orphaned.',

    PRIMARY KEY (training_id),
    INDEX idx_silver_training_emp (employee_id),
    INDEX idx_silver_training_dept (department),
    INDEX idx_silver_training_year (year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE silver_goals (
    goal_id                 VARCHAR(20),
    employee_id             VARCHAR(20),
    goal_type               VARCHAR(100),
    goal_description        TEXT,
    set_date                DATE,
    due_date                DATE,
    target_value            DECIMAL(14,2),
    achieved_value          DECIMAL(14,2),
    achievement_pct         DECIMAL(5,1),
    goal_status             VARCHAR(20),
    quarter                 VARCHAR(10),
    department              VARCHAR(100),
    priority                VARCHAR(10),

    -- ── Silver Metadata ──
    _source_bronze_hash     VARCHAR(64)     COMMENT 'Hash from bronze layer for lineage tracking.',
    _silver_load_timestamp  DATETIME        COMMENT 'Timestamp when this row was loaded into Silver.',
    _is_valid_fk            TINYINT(1)      DEFAULT 1 COMMENT '1 = employee_id FK valid, 0 = orphaned.',

    PRIMARY KEY (goal_id),
    INDEX idx_silver_goal_emp (employee_id),
    INDEX idx_silver_goal_quarter (quarter),
    INDEX idx_silver_goal_status (goal_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER $$

CREATE FUNCTION fn_clean_department(dept_name VARCHAR(255))
RETURNS VARCHAR(100)
DETERMINISTIC
NO SQL
COMMENT 'Maps dirty department name variants to canonical names. Handles typos, abbreviations, casing.'
BEGIN
    DECLARE cleaned VARCHAR(255);

    SET cleaned = TRIM(dept_name);
    IF cleaned IS NULL OR cleaned = '' OR UPPER(cleaned) = 'N/A' THEN
        RETURN NULL;
    END IF;

    RETURN CASE LOWER(cleaned)
        -- ── Engineering ──
        -- Variants: Engineering, Enginering, Engineerng, ENGINEERING, Eng, engineering
        WHEN 'engineering'      THEN 'Engineering'
        WHEN 'enginering'       THEN 'Engineering'     -- typo: missing 'e'
        WHEN 'engineerng'       THEN 'Engineering'     -- typo: missing 'i'
        WHEN 'eng'              THEN 'Engineering'     -- abbreviation

        -- ── Human Resources ──
        -- Variants: Human Resources, Human Resource, HR, H.R., human resources, Humaan Resources
        WHEN 'human resources'  THEN 'Human Resources'
        WHEN 'human resource'   THEN 'Human Resources' -- missing plural 's'
        WHEN 'hr'               THEN 'Human Resources' -- common abbreviation
        WHEN 'h.r.'             THEN 'Human Resources' -- abbreviation with dots
        WHEN 'humaan resources' THEN 'Human Resources' -- typo: double 'a'

        -- ── Sales ──
        -- Variants: Sales, sales, SALES, Slaes, Sale
        WHEN 'sales'            THEN 'Sales'
        WHEN 'slaes'            THEN 'Sales'           -- typo: transposed letters
        WHEN 'sale'             THEN 'Sales'           -- missing plural 's'

        -- ── Marketing ──
        -- Variants: Marketing, Marketting, marketing, MARKETING, Mktg
        WHEN 'marketing'        THEN 'Marketing'
        WHEN 'marketting'       THEN 'Marketing'       -- typo: double 't'
        WHEN 'mktg'             THEN 'Marketing'       -- abbreviation

        -- ── Finance ──
        -- Variants: Finance, Fiance, finance, FINANCE, Fin
        WHEN 'finance'          THEN 'Finance'
        WHEN 'fiance'           THEN 'Finance'         -- typo: missing 'n'
        WHEN 'fin'              THEN 'Finance'         -- abbreviation

        -- ── Operations ──
        -- Variants: Operations, Operatons, operations, Ops, OPERATIONS
        WHEN 'operations'       THEN 'Operations'
        WHEN 'operatons'        THEN 'Operations'      -- typo: missing 'i'
        WHEN 'ops'              THEN 'Operations'      -- abbreviation

        -- ── Customer Support ──
        -- Variants: Customer Support, Customer service, Cust Support, CS, customer support
        WHEN 'customer support' THEN 'Customer Support'
        WHEN 'customer service' THEN 'Customer Support' -- synonym
        WHEN 'cust support'     THEN 'Customer Support' -- abbreviation
        WHEN 'cs'               THEN 'Customer Support' -- abbreviation

        -- ── IT ──
        -- Variants: IT, I.T., Information Technology, it, Info Tech
        WHEN 'it'               THEN 'IT'
        WHEN 'i.t.'             THEN 'IT'              -- abbreviation with dots
        WHEN 'information technology' THEN 'IT'        -- full name → canonical short
        WHEN 'info tech'        THEN 'IT'              -- abbreviated full name

        -- ── Legal ──
        -- Variants: Legal, legal, LEGAL, Legel, Law
        WHEN 'legal'            THEN 'Legal'
        WHEN 'legel'            THEN 'Legal'           -- typo: 'e' instead of 'a'
        WHEN 'law'              THEN 'Legal'           -- synonym

        -- ── Research & Dev ──
        -- Variants: Research & Dev, R&D, r&d, Research and Development, RnD
        WHEN 'research & dev'   THEN 'Research & Dev'
        WHEN 'r&d'              THEN 'Research & Dev'  -- abbreviation
        WHEN 'research and development' THEN 'Research & Dev' -- full name
        WHEN 'rnd'              THEN 'Research & Dev'  -- abbreviation without '&'

        -- ── Administration ──
        -- Variants: Administration, Admin, admin, ADMIN, Administraton
        WHEN 'administration'   THEN 'Administration'
        WHEN 'admin'            THEN 'Administration'  -- abbreviation
        WHEN 'administraton'    THEN 'Administration'  -- typo: 'o' instead of 'io'

        -- ── Procurement ──
        -- Variants: Procurement, Procurment, procurement, PROCUREMENT, Proc
        WHEN 'procurement'      THEN 'Procurement'
        WHEN 'procurment'       THEN 'Procurement'    -- typo: missing 'e'
        WHEN 'proc'             THEN 'Procurement'    -- abbreviation

        ELSE TRIM(dept_name)
    END;
END$$


CREATE FUNCTION fn_parse_date(date_str VARCHAR(255))
RETURNS DATE
DETERMINISTIC
NO SQL
COMMENT 'Parses dates from 6 different source formats into a standard DATE type.'
BEGIN
    DECLARE cleaned VARCHAR(255);
    DECLARE result DATE;

    -- Handle NULL, blank, and N/A values
    SET cleaned = TRIM(date_str);
    IF cleaned IS NULL OR cleaned = '' OR UPPER(cleaned) = 'N/A' THEN
        RETURN NULL;
    END IF;

    -- Attempt 1: ISO format '%Y-%m-%d' (e.g., 2023-06-15)
    SET result = STR_TO_DATE(cleaned, '%Y-%m-%d');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- Attempt 2: '%Y/%m/%d' (e.g., 2023/06/15)
    SET result = STR_TO_DATE(cleaned, '%Y/%m/%d');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- Attempt 3: '%d/%m/%Y' (e.g., 15/06/2023)
    SET result = STR_TO_DATE(cleaned, '%d/%m/%Y');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- Attempt 4: '%m-%d-%Y' (e.g., 06-15-2023)
    SET result = STR_TO_DATE(cleaned, '%m-%d-%Y');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- Attempt 5: '%d %b %Y' (e.g., 15 Jun 2023)
    SET result = STR_TO_DATE(cleaned, '%d %b %Y');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- Attempt 6: '%B %d, %Y' (e.g., June 15, 2023)
    SET result = STR_TO_DATE(cleaned, '%B %d, %Y');
    IF result IS NOT NULL THEN RETURN result; END IF;

    -- If no format matched, return NULL rather than failing
    -- WHY: A failed parse shouldn't crash the entire ETL pipeline.
    RETURN NULL;
END$$


CREATE FUNCTION fn_clean_gender(gender_val VARCHAR(50))
RETURNS VARCHAR(10)
DETERMINISTIC
NO SQL
COMMENT 'Standardizes gender values from 12+ variants to Male/Female.'
BEGIN
    DECLARE cleaned VARCHAR(50);

    SET cleaned = TRIM(gender_val);
    IF cleaned IS NULL OR cleaned = '' OR UPPER(cleaned) = 'N/A' THEN
        RETURN NULL;
    END IF;

    RETURN CASE LOWER(cleaned)
        -- Male variants
        WHEN 'male'   THEN 'Male'
        WHEN 'm'      THEN 'Male'
        WHEN 'man'    THEN 'Male'

        -- Female variants
        WHEN 'female' THEN 'Female'
        WHEN 'f'      THEN 'Female'
        WHEN 'woman'  THEN 'Female'

        -- Fallback: return as-is for unknown values (data preservation)
        ELSE TRIM(gender_val)
    END;
END$$


CREATE FUNCTION fn_clean_quarter(quarter_val VARCHAR(50))
RETURNS VARCHAR(10)
DETERMINISTIC
NO SQL
COMMENT 'Standardizes quarter formats (Q12022, q3 2022, 2022-Q1, etc.) to Q1 2021 format.'
BEGIN
    DECLARE cleaned VARCHAR(50);
    DECLARE q_digit VARCHAR(1);
    DECLARE q_year VARCHAR(4);

    SET cleaned = TRIM(quarter_val);
    IF cleaned IS NULL OR cleaned = '' OR UPPER(cleaned) = 'N/A' THEN
        RETURN NULL;
    END IF;

    SET q_digit = REGEXP_SUBSTR(UPPER(cleaned), '(?<=Q)[1-4]');

    -- Extract the 4-digit year
    SET q_year = REGEXP_SUBSTR(cleaned, '[0-9]{4}');

    -- If we successfully extracted both components, construct canonical format
    IF q_digit IS NOT NULL AND q_year IS NOT NULL THEN
        RETURN CONCAT('Q', q_digit, ' ', q_year);
    END IF;

    -- Fallback: return as-is if we can't parse it
    RETURN cleaned;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE sp_clean_silver_departments()
COMMENT 'Silver ETL: Cleans and loads department data from bronze_departments.'
BEGIN
    -- Error handling: if anything fails, we roll back and surface the error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    TRUNCATE TABLE silver_departments;

    INSERT INTO silver_departments (
        dept_id,
        dept_name,
        location,
        manager_id,
        created_date,
        status,
        headcount_budget,
        cost_center,
        _source_bronze_hash,
        _silver_load_timestamp,
        _is_valid_fk
    )
    SELECT
        -- ── Business Columns ──
        -- dept_id: NULLIF handles blanks → NULL; TRIM removes stray whitespace
        NULLIF(TRIM(b.dept_id), '')                           AS dept_id,

        -- dept_name: Use our helper function for comprehensive typo/variant mapping
        fn_clean_department(b.dept_name)                      AS dept_name,

        -- location: Simple null handling — blank → NULL
        NULLIF(TRIM(b.location), '')                          AS location,

        -- manager_id: References an employee. We can't validate the FK here
        -- because employees haven't been loaded yet. We'll flag it as valid=1
        -- and the Gold Layer can cross-validate if needed.
        NULLIF(TRIM(b.manager_id), '')                        AS manager_id,

        -- created_date: Parse from mixed formats using our helper function
        fn_parse_date(b.created_date)                         AS created_date,

        -- status: Standardize casing variants (Active/active/ACTIVE → Active)
        CASE UPPER(TRIM(b.status))
            WHEN 'ACTIVE'   THEN 'Active'
            WHEN 'INACTIVE' THEN 'Inactive'
            ELSE NULL  -- blank or unrecognized → NULL
        END                                                   AS status,

        -- headcount_budget: CAST from VARCHAR to INT
        -- WHY NULLIF first: empty strings can't be cast to INT, so we NULL them
        CAST(NULLIF(TRIM(b.headcount_budget), '') AS UNSIGNED)  AS headcount_budget,

        -- cost_center: Simple clean — no type change needed
        NULLIF(TRIM(b.cost_center), '')                       AS cost_center,

        -- ── Metadata ──
        b._row_hash                                           AS _source_bronze_hash,
        NOW()                                                 AS _silver_load_timestamp,
        1                                                     AS _is_valid_fk

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY _row_hash
                ORDER BY _load_timestamp DESC
            ) AS rn
        FROM bronze_departments
        WHERE _is_deleted = 0  -- Exclude soft-deleted records from Bronze
    ) b
    WHERE b.rn = 1         -- Keep only the first (latest) row per hash group
      AND b.dept_id IS NOT NULL
      AND TRIM(b.dept_id) != '';  -- Skip rows with no dept_id (can't be a valid dept)

    COMMIT;
END$$


CREATE PROCEDURE sp_clean_silver_employees()
COMMENT 'Silver ETL: Cleans and loads employee data from bronze_employees.'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Full refresh: TRUNCATE ensures no stale data remains
    TRUNCATE TABLE silver_employees;

    INSERT INTO silver_employees (
        employee_id,
        first_name,
        last_name,
        gender,
        date_of_birth,
        email,
        phone,
        department_id,
        department_name,
        job_title,
        employment_type,
        join_date,
        salary,
        status,
        location,
        manager_id,
        years_experience,
        _source_bronze_hash,
        _silver_load_timestamp,
        _is_valid_fk
    )
    SELECT
        -- ── Identity ──
        TRIM(b.employee_id)                                   AS employee_id,
        NULLIF(TRIM(b.first_name), '')                        AS first_name,
        NULLIF(TRIM(b.last_name), '')                         AS last_name,

        -- gender: 12 variants → 'Male' or 'Female'
        fn_clean_gender(b.gender)                             AS gender,

        -- date_of_birth: Mixed date formats → proper DATE type
        fn_parse_date(b.date_of_birth)                        AS date_of_birth,

        -- email: Simple cleanup, blank → NULL
        NULLIF(TRIM(b.email), '')                             AS email,

        -- phone: 'N/A' is used as a placeholder for missing phones → treat as NULL
        -- WHY: 'N/A' is not a valid phone number and would cause issues in reporting
        CASE
            WHEN TRIM(b.phone) IN ('', 'N/A', 'n/a', 'NA') THEN NULL
            ELSE TRIM(b.phone)
        END                                                   AS phone,

        -- department_id: Keep as-is for FK validation
        NULLIF(TRIM(b.department_id), '')                     AS department_id,

        -- department_name: Clean using our comprehensive mapping function
        fn_clean_department(b.department_name)                AS department_name,


        NULLIF(TRIM(b.job_title), '')                         AS job_title,

        -- employment_type: Standardize casing variants
        -- Source has: Full-Time, full-time, Part-Time, Contract, CONTRACT, Permanent, permanent, ''
        CASE LOWER(TRIM(b.employment_type))
            WHEN 'full-time'  THEN 'Full-Time'
            WHEN 'part-time'  THEN 'Part-Time'
            WHEN 'contract'   THEN 'Contract'
            WHEN 'permanent'  THEN 'Permanent'
            ELSE NULL  -- blank or unrecognized → NULL
        END                                                   AS employment_type,

        -- join_date: Mixed date formats → DATE
        fn_parse_date(b.join_date)                            AS join_date,

        -- salary: VARCHAR → DECIMAL(12,2)
        -- WHY NULLIF before CAST: Empty strings can't be cast to DECIMAL
        CAST(NULLIF(TRIM(b.salary), '') AS DECIMAL(12,2))     AS salary,

        -- status: Standardize the 8 known variants to 4 canonical values
        -- Source has: Active, active, ACTIVE, Inactive, Terminated, terminated, On Leave, on leave
        CASE LOWER(TRIM(b.status))
            WHEN 'active'     THEN 'Active'
            WHEN 'inactive'   THEN 'Inactive'
            WHEN 'terminated' THEN 'Terminated'
            WHEN 'on leave'   THEN 'On Leave'
            ELSE NULL
        END                                                   AS status,

        -- location: Simple cleanup
        NULLIF(TRIM(b.location), '')                          AS location,

        -- manager_id: Keep as-is; could validate against employee_id but
        -- self-referencing FK validation adds complexity. Gold Layer handles this.
        NULLIF(TRIM(b.manager_id), '')                        AS manager_id,

        -- years_experience: VARCHAR → INT
        CAST(NULLIF(TRIM(b.years_experience), '') AS UNSIGNED)  AS years_experience,

        -- ── Metadata ──
        b._row_hash                                           AS _source_bronze_hash,
        NOW()                                                 AS _silver_load_timestamp,


        CASE
            WHEN TRIM(b.department_id) IS NULL OR TRIM(b.department_id) = '' THEN 1
            WHEN EXISTS (
                SELECT 1 FROM silver_departments sd
                WHERE sd.dept_id = TRIM(b.department_id)
            ) THEN 1   -- FK is valid
            ELSE 0      -- FK is orphaned
        END                                                   AS _is_valid_fk

    FROM (
        -- Deduplication: Keep the latest version of each unique row
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY _row_hash
                ORDER BY _load_timestamp DESC
            ) AS rn
        FROM bronze_employees
        WHERE _is_deleted = 0
    ) b
    WHERE b.rn = 1
      AND TRIM(b.employee_id) IS NOT NULL
      AND TRIM(b.employee_id) != '';

    COMMIT;
END$$


CREATE PROCEDURE sp_clean_silver_performance_reviews()
COMMENT 'Silver ETL: Cleans and loads performance review data from bronze_performance_reviews.'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    TRUNCATE TABLE silver_performance_reviews;

    INSERT INTO silver_performance_reviews (
        review_id,
        employee_id,
        review_period,
        review_date,
        reviewer_id,
        performance_score,
        rating_label,
        goals_achieved_pct,
        communication_score,
        teamwork_score,
        leadership_score,
        technical_score,
        comments,
        department,
        created_at,
        _source_bronze_hash,
        _silver_load_timestamp,
        _is_valid_fk
    )
    SELECT
        TRIM(b.review_id)                                     AS review_id,
        TRIM(b.employee_id)                                   AS employee_id,

        -- review_period: Standardize quarter formats (Q12022 → Q1 2022, etc.)
        fn_clean_quarter(b.review_period)                     AS review_period,

        -- review_date: Parse mixed date formats
        fn_parse_date(b.review_date)                          AS review_date,

        -- reviewer_id: Keep as-is; blank → NULL
        NULLIF(TRIM(b.reviewer_id), '')                       AS reviewer_id,

        CAST(
            NULLIF(
                TRIM(REPLACE(REPLACE(b.performance_score, '"', ''), '''', '')),
                ''
            ) AS DECIMAL(3,1)
        )                                                     AS performance_score,

        CASE
            WHEN LOWER(TRIM(b.rating_label)) IN ('poor', '1 - poor', '1-poor')
                THEN 'Poor'
            WHEN LOWER(TRIM(b.rating_label)) IN ('below average', 'below avg', 'below_average',
                                                  '2-below average', '2 - below average', 'below avge')
                THEN 'Below Average'
            WHEN LOWER(TRIM(b.rating_label)) IN ('average', 'avg', '3 - average', '3-avg',
                                                  '3 - avg')
                THEN 'Average'
            WHEN LOWER(TRIM(b.rating_label)) IN ('good', '4-good', '4 - good')
                THEN 'Good'
            WHEN LOWER(TRIM(b.rating_label)) IN ('excellent', '5 - excellent', '5-excellent')
                THEN 'Excellent'
            WHEN TRIM(b.rating_label) = '' OR b.rating_label IS NULL
                THEN NULL
            ELSE TRIM(b.rating_label)  -- Preserve unrecognized values
        END                                                   AS rating_label,


        CAST(
            NULLIF(
                TRIM(REPLACE(b.goals_achieved_pct, '%', '')),
                ''
            ) AS DECIMAL(5,1)
        )                                                     AS goals_achieved_pct,

        -- Sub-scores: Simple VARCHAR → DECIMAL casts
        -- These are already clean numbers (1.0–5.0) or blank
        CAST(NULLIF(TRIM(b.communication_score), '') AS DECIMAL(3,1))  AS communication_score,
        CAST(NULLIF(TRIM(b.teamwork_score), '') AS DECIMAL(3,1))       AS teamwork_score,
        CAST(NULLIF(TRIM(b.leadership_score), '') AS DECIMAL(3,1))     AS leadership_score,
        CAST(NULLIF(TRIM(b.technical_score), '') AS DECIMAL(3,1))      AS technical_score,

        CASE
            WHEN TRIM(b.comments) IN ('', 'N/A', 'n/a', 'NA', 'None', 'none', 'NULL')
                THEN NULL
            ELSE TRIM(b.comments)
        END                                                   AS comments,

        -- department: Clean typos and variants
        fn_clean_department(b.department)                     AS department,

        -- created_at: Parse mixed date formats
        fn_parse_date(b.created_at)                           AS created_at,

        -- ── Metadata ──
        b._row_hash                                           AS _source_bronze_hash,
        NOW()                                                 AS _silver_load_timestamp,

        CASE
            WHEN TRIM(b.employee_id) IS NULL OR TRIM(b.employee_id) = '' THEN 0
            WHEN EXISTS (
                SELECT 1 FROM silver_employees se
                WHERE se.employee_id = TRIM(b.employee_id)
            ) THEN 1   -- Valid FK
            ELSE 0      -- Orphaned FK
        END                                                   AS _is_valid_fk

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY _row_hash
                ORDER BY _load_timestamp DESC
            ) AS rn
        FROM bronze_performance_reviews
        WHERE _is_deleted = 0
    ) b
    WHERE b.rn = 1
      AND TRIM(b.review_id) IS NOT NULL
      AND TRIM(b.review_id) != '';

    COMMIT;
END$$


CREATE PROCEDURE sp_clean_silver_training()
COMMENT 'Silver ETL: Cleans and loads training data from bronze_training.'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    TRUNCATE TABLE silver_training;

    INSERT INTO silver_training (
        training_id,
        employee_id,
        course_name,
        category,
        start_date,
        end_date,
        duration_days,
        completion_status,
        score,
        cost_lkr,
        trainer,
        department,
        year,
        _source_bronze_hash,
        _silver_load_timestamp,
        _is_valid_fk
    )
    SELECT
        TRIM(b.training_id)                                   AS training_id,
        TRIM(b.employee_id)                                   AS employee_id,

        -- course_name: Some are lowercase due to source issues (~8%)
        -- We preserve original casing in Silver; Gold Layer can title-case if needed
        NULLIF(TRIM(b.course_name), '')                       AS course_name,

        -- ── category: Standardize to 4 canonical values ──
        -- Source: Technical, technical, TECHNICAL, Soft Skills, soft skills,
        --         Compliance, Leadership, '', N/A
        CASE
            WHEN LOWER(TRIM(b.category)) = 'technical'   THEN 'Technical'
            WHEN LOWER(TRIM(b.category)) = 'soft skills' THEN 'Soft Skills'
            WHEN LOWER(TRIM(b.category)) = 'compliance'  THEN 'Compliance'
            WHEN LOWER(TRIM(b.category)) = 'leadership'  THEN 'Leadership'
            WHEN TRIM(b.category) IN ('', 'N/A', 'n/a', 'NA') THEN NULL
            ELSE TRIM(b.category)
        END                                                   AS category,

        -- start_date / end_date: Parse mixed date formats
        fn_parse_date(b.start_date)                           AS start_date,
        fn_parse_date(b.end_date)                             AS end_date,

        -- ── duration_days: Remove ' days' suffix ──
        -- Source has two formats: plain number "5" or suffixed "5 days"
        -- WHY REPLACE: The ' days' suffix prevents numeric casting
        CAST(
            NULLIF(
                TRIM(REPLACE(LOWER(TRIM(b.duration_days)), ' days', '')),
                ''
            ) AS UNSIGNED
        )                                                     AS duration_days,

        -- ── completion_status: Standardize to 4 canonical values ──
        -- Source: Completed, completed, COMPLETED, Incomplete, In Progress,
        --         in progress, Dropped, ''
        CASE LOWER(TRIM(b.completion_status))
            WHEN 'completed'   THEN 'Completed'
            WHEN 'incomplete'  THEN 'Incomplete'
            WHEN 'in progress' THEN 'In Progress'
            WHEN 'dropped'     THEN 'Dropped'
            ELSE NULL  -- blank or unrecognized
        END                                                   AS completion_status,

        -- score: VARCHAR → INT (training assessment score, 0–100)
        CAST(NULLIF(TRIM(b.score), '') AS UNSIGNED)           AS score,

        -- cost_lkr: VARCHAR → DECIMAL (training cost in Sri Lankan Rupees)
        CAST(NULLIF(TRIM(b.cost_lkr), '') AS DECIMAL(12,2))  AS cost_lkr,

        -- ── trainer: Standardize to 3 canonical values ──
        -- Source: Internal, External, internal, EXTERNAL, Online, online, ''
        CASE LOWER(TRIM(b.trainer))
            WHEN 'internal' THEN 'Internal'
            WHEN 'external' THEN 'External'
            WHEN 'online'   THEN 'Online'
            ELSE NULL
        END                                                   AS trainer,

        -- department: Clean typos using our helper function
        fn_clean_department(b.department)                     AS department,

        -- year: VARCHAR → INT (4-digit year)
        CAST(NULLIF(TRIM(b.year), '') AS UNSIGNED)            AS year,

        -- ── Metadata ──
        b._row_hash                                           AS _source_bronze_hash,
        NOW()                                                 AS _silver_load_timestamp,

        -- FK Validation: Does employee_id exist in silver_employees?
        CASE
            WHEN TRIM(b.employee_id) IS NULL OR TRIM(b.employee_id) = '' THEN 0
            WHEN EXISTS (
                SELECT 1 FROM silver_employees se
                WHERE se.employee_id = TRIM(b.employee_id)
            ) THEN 1
            ELSE 0
        END                                                   AS _is_valid_fk

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY _row_hash
                ORDER BY _load_timestamp DESC
            ) AS rn
        FROM bronze_training
        WHERE _is_deleted = 0
    ) b
    WHERE b.rn = 1
      AND TRIM(b.training_id) IS NOT NULL
      AND TRIM(b.training_id) != '';

    COMMIT;
END$$


-- ────────────────────────────────────────────────────────────────────────────
-- 4.5  sp_clean_silver_goals()
-- ────────────────────────────────────────────────────────────────────────────
-- CLEANS: Employee goal records (~55,000 rows, ~57,750 with duplicates)
--
-- SPECIAL CLEANING:
--   • achievement_pct: Remove '%' suffix, cast to DECIMAL. Can exceed 100%.
--   • quarter: Highly inconsistent formats → fn_clean_quarter()
--   • status: Mixed casing + N/A → standardize to 4 canonical values
--   • priority: Mixed casing + N/A → standardize to 3 canonical values
--   • target_value / achieved_value: VARCHAR → DECIMAL for calculations
-- ────────────────────────────────────────────────────────────────────────────
CREATE PROCEDURE sp_clean_silver_goals()
COMMENT 'Silver ETL: Cleans and loads goal data from bronze_goals.'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    TRUNCATE TABLE silver_goals;

    INSERT INTO silver_goals (
        goal_id,
        employee_id,
        goal_type,
        goal_description,
        set_date,
        due_date,
        target_value,
        achieved_value,
        achievement_pct,
        status,
        quarter,
        department,
        priority,
        _source_bronze_hash,
        _silver_load_timestamp,
        _is_valid_fk
    )
    SELECT
        TRIM(b.goal_id)                                       AS goal_id,
        TRIM(b.employee_id)                                   AS employee_id,

        -- goal_type: Some are ALL CAPS (~6%). Preserve original; not critical to standardize.
        NULLIF(TRIM(b.goal_type), '')                         AS goal_type,

        -- goal_description: Handle blanks/N/A → NULL
        CASE
            WHEN TRIM(b.goal_description) IN ('', 'N/A', 'n/a', 'NA', 'None')
                THEN NULL
            ELSE TRIM(b.goal_description)
        END                                                   AS goal_description,

        -- set_date / due_date: Parse mixed date formats
        fn_parse_date(b.set_date)                             AS set_date,
        fn_parse_date(b.due_date)                             AS due_date,

        -- target_value: VARCHAR → DECIMAL (monetary/numeric targets)
        CAST(NULLIF(TRIM(b.target_value), '') AS DECIMAL(14,2))   AS target_value,

        -- achieved_value: VARCHAR → DECIMAL
        CAST(NULLIF(TRIM(b.achieved_value), '') AS DECIMAL(14,2)) AS achieved_value,

        -- ── achievement_pct: Remove '%' sign, cast to DECIMAL ──
        -- Source: "87.5%" → 87.5
        -- NOTE: This can exceed 100% (over-achievement), so DECIMAL(5,1) accommodates up to 999.9%
        CAST(
            NULLIF(
                TRIM(REPLACE(b.achievement_pct, '%', '')),
                ''
            ) AS DECIMAL(5,1)
        )                                                     AS achievement_pct,

        -- ── status: Standardize to 4 canonical values ──
        -- Source: Completed, completed, In Progress, in progress, Overdue, overdue,
        --         Cancelled, cancelled, '', N/A
        CASE
            WHEN LOWER(TRIM(b.status)) = 'completed'   THEN 'Completed'
            WHEN LOWER(TRIM(b.status)) = 'in progress' THEN 'In Progress'
            WHEN LOWER(TRIM(b.status)) = 'overdue'     THEN 'Overdue'
            WHEN LOWER(TRIM(b.status)) = 'cancelled'   THEN 'Cancelled'
            WHEN TRIM(b.status) IN ('', 'N/A', 'n/a', 'NA') THEN NULL
            ELSE TRIM(b.status)
        END                                                   AS status,

        -- quarter: Highly inconsistent → use our helper function
        -- Handles: Q12022, Q2-2023, q3 2022, 2022 Q1, 2023-Q3, etc.
        fn_clean_quarter(b.quarter)                           AS quarter,

        -- department: Clean typos using our helper function
        fn_clean_department(b.department)                     AS department,

        -- ── priority: Standardize to 3 canonical values ──
        -- Source: High, Medium, Low, high, LOW, MEDIUM, '', N/A
        CASE
            WHEN LOWER(TRIM(b.priority)) = 'high'   THEN 'High'
            WHEN LOWER(TRIM(b.priority)) = 'medium' THEN 'Medium'
            WHEN LOWER(TRIM(b.priority)) = 'low'    THEN 'Low'
            WHEN TRIM(b.priority) IN ('', 'N/A', 'n/a', 'NA') THEN NULL
            ELSE TRIM(b.priority)
        END                                                   AS priority,

        -- ── Metadata ──
        b._row_hash                                           AS _source_bronze_hash,
        NOW()                                                 AS _silver_load_timestamp,

        -- FK Validation: Does employee_id exist in silver_employees?
        CASE
            WHEN TRIM(b.employee_id) IS NULL OR TRIM(b.employee_id) = '' THEN 0
            WHEN EXISTS (
                SELECT 1 FROM silver_employees se
                WHERE se.employee_id = TRIM(b.employee_id)
            ) THEN 1
            ELSE 0
        END                                                   AS _is_valid_fk

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY _row_hash
                ORDER BY _load_timestamp DESC
            ) AS rn
        FROM bronze_goals
        WHERE _is_deleted = 0
    ) b
    WHERE b.rn = 1
      AND TRIM(b.goal_id) IS NOT NULL
      AND TRIM(b.goal_id) != '';

    COMMIT;
END$$


-- ============================================================================
-- SECTION 5: MASTER ORCHESTRATION PROCEDURE
-- ============================================================================
-- PURPOSE: Execute all 5 silver cleaning procedures in the correct dependency
-- order with logging and error handling.
--
-- DEPENDENCY ORDER:
--   1. Departments  (no dependencies — reference/dimension table)
--   2. Employees    (depends on departments for FK validation)
--   3. Performance Reviews (depends on employees for FK validation)
--   4. Training     (depends on employees for FK validation)
--   5. Goals        (depends on employees for FK validation)
--
-- WHY NOT PARALLEL: Steps 3, 4, 5 COULD run in parallel since they only
-- depend on employees (not each other), but MySQL stored procedures don't
-- support parallelism natively. For a production system, we would use an
-- orchestration tool (Airflow, dbt, etc.) to parallelize these.
-- ============================================================================

CREATE PROCEDURE sp_load_all_silver()
COMMENT 'Master orchestrator: Runs all 5 silver layer ETL procedures in dependency order.'
BEGIN
    -- Variables for logging
    DECLARE v_start_time DATETIME;
    DECLARE v_step_start DATETIME;
    DECLARE v_dept_count INT DEFAULT 0;
    DECLARE v_emp_count INT DEFAULT 0;
    DECLARE v_review_count INT DEFAULT 0;
    DECLARE v_training_count INT DEFAULT 0;
    DECLARE v_goals_count INT DEFAULT 0;

    -- Error handling: Catch and report any errors
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Log the error context
        SELECT 'ERROR: Silver layer load FAILED. Check individual procedures for details.' AS error_message,
               NOW() AS error_time;
        RESIGNAL;
    END;

    SET v_start_time = NOW();

    -- ════════════════════════════════════════════════════════════════
    -- STEP 1: DEPARTMENTS (no dependencies)
    -- ════════════════════════════════════════════════════════════════
    SET v_step_start = NOW();
    SELECT '>>> Step 1/5: Loading silver_departments...' AS progress;

    CALL sp_clean_silver_departments();

    SELECT COUNT(*) INTO v_dept_count FROM silver_departments;
    SELECT CONCAT('    ✅ silver_departments loaded: ', v_dept_count, ' rows (',
                  TIMESTAMPDIFF(SECOND, v_step_start, NOW()), 's)') AS result;

    -- ════════════════════════════════════════════════════════════════
    -- STEP 2: EMPLOYEES (depends on departments for FK validation)
    -- ════════════════════════════════════════════════════════════════
    SET v_step_start = NOW();
    SELECT '>>> Step 2/5: Loading silver_employees...' AS progress;

    CALL sp_clean_silver_employees();

    SELECT COUNT(*) INTO v_emp_count FROM silver_employees;
    SELECT CONCAT('    ✅ silver_employees loaded: ', v_emp_count, ' rows (',
                  TIMESTAMPDIFF(SECOND, v_step_start, NOW()), 's)') AS result;

    -- ════════════════════════════════════════════════════════════════
    -- STEP 3: PERFORMANCE REVIEWS (depends on employees for FK validation)
    -- ════════════════════════════════════════════════════════════════
    SET v_step_start = NOW();
    SELECT '>>> Step 3/5: Loading silver_performance_reviews...' AS progress;

    CALL sp_clean_silver_performance_reviews();

    SELECT COUNT(*) INTO v_review_count FROM silver_performance_reviews;
    SELECT CONCAT('    ✅ silver_performance_reviews loaded: ', v_review_count, ' rows (',
                  TIMESTAMPDIFF(SECOND, v_step_start, NOW()), 's)') AS result;

    -- ════════════════════════════════════════════════════════════════
    -- STEP 4: TRAINING (depends on employees for FK validation)
    -- ════════════════════════════════════════════════════════════════
    SET v_step_start = NOW();
    SELECT '>>> Step 4/5: Loading silver_training...' AS progress;

    CALL sp_clean_silver_training();

    SELECT COUNT(*) INTO v_training_count FROM silver_training;
    SELECT CONCAT('    ✅ silver_training loaded: ', v_training_count, ' rows (',
                  TIMESTAMPDIFF(SECOND, v_step_start, NOW()), 's)') AS result;

    -- ════════════════════════════════════════════════════════════════
    -- STEP 5: GOALS (depends on employees for FK validation)
    -- ════════════════════════════════════════════════════════════════
    SET v_step_start = NOW();
    SELECT '>>> Step 5/5: Loading silver_goals...' AS progress;

    CALL sp_clean_silver_goals();

    SELECT COUNT(*) INTO v_goals_count FROM silver_goals;
    SELECT CONCAT('    ✅ silver_goals loaded: ', v_goals_count, ' rows (',
                  TIMESTAMPDIFF(SECOND, v_step_start, NOW()), 's)') AS result;

    -- ════════════════════════════════════════════════════════════════
    -- FINAL SUMMARY
    -- ════════════════════════════════════════════════════════════════
    SELECT '════════════════════════════════════════════════════════════' AS divider;
    SELECT CONCAT('SILVER LAYER LOAD COMPLETE — Total time: ',
                  TIMESTAMPDIFF(SECOND, v_start_time, NOW()), ' seconds') AS summary;
    SELECT '════════════════════════════════════════════════════════════' AS divider;

    -- Summary counts with FK validation stats
    SELECT
        'silver_departments' AS table_name, v_dept_count AS total_rows,
        (SELECT COUNT(*) FROM silver_departments WHERE _is_valid_fk = 0) AS invalid_fk_rows
    UNION ALL
    SELECT
        'silver_employees', v_emp_count,
        (SELECT COUNT(*) FROM silver_employees WHERE _is_valid_fk = 0)
    UNION ALL
    SELECT
        'silver_performance_reviews', v_review_count,
        (SELECT COUNT(*) FROM silver_performance_reviews WHERE _is_valid_fk = 0)
    UNION ALL
    SELECT
        'silver_training', v_training_count,
        (SELECT COUNT(*) FROM silver_training WHERE _is_valid_fk = 0)
    UNION ALL
    SELECT
        'silver_goals', v_goals_count,
        (SELECT COUNT(*) FROM silver_goals WHERE _is_valid_fk = 0);

END$$

DELIMITER ;
