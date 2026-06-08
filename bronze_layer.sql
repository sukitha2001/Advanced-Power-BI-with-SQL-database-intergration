-- Create the database for the HR Data Warehouse

CREATE DATABASE IF NOT EXISTS hr_dwh
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_general_ci;
USE hr_dwh;

DROP TABLE  IF EXISTS bronze_departments;

CREATE TABLE bronze_departments (
    bronze_departments_sk INT AUTO_INCREMENT PRIMARY KEY,
    dept_id VARCHAR(255),
    dept_name VARCHAR(255),
    location VARCHAR(255),
    manager_id VARCHAR(255),
    created_date VARCHAR(255),
    dep_status VARCHAR(255),
    headcount_budget VARCHAR(255),
    cost_center VARCHAR(255),
    _source_file VARCHAR(500) NOT NULL,
    _load_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    _row_hash CHAR(32) NOT NULL,
    _is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_bronze_dept_id (dept_id),
    INDEX idx_bronze_dept_load_ts (_load_timestamp),
    INDEX idx_bronze_dept_row_hash (_row_hash)
)ENGINE=InnoDB;

DROP TABLE IF EXISTS bronze_employees;

CREATE TABLE bronze_employees (
    bronze_employees_sk INT AUTO_INCREMENT PRIMARY KEY,
    employee_id VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    gender VARCHAR(255),
    date_of_birth VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(255),
    department_id VARCHAR(255),
    department_name VARCHAR(255),
    job_title VARCHAR(255),
    employment_type VARCHAR(255),
    join_date VARCHAR(255),
    salary VARCHAR(255),
    emp_status VARCHAR(255),
    emp_location VARCHAR(255),
    manager_id VARCHAR(255),
    years_experience VARCHAR(255),
    _source_file VARCHAR(500) NOT NULL,
    _load_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    _row_hash CHAR(32) NOT NULL,
    _is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_bronze_emp_id (employee_id),
    INDEX idx_bronze_emp_dept_id (department_id),
    INDEX idx_bronze_emp_manager_id (manager_id),
    INDEX idx_bronze_emp_load_ts (_load_timestamp),
    INDEX idx_bronze_emp_row_hash (_row_hash)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS bronze_performance_reviews;

CREATE TABLE bronze_performance_reviews (
    bronze_performance_reviews_sk INT AUTO_INCREMENT PRIMARY KEY,

    review_id VARCHAR(255),
    employee_id VARCHAR(255),
    review_period VARCHAR(255),
    review_date VARCHAR(255),
    reviewer_id VARCHAR(255),
    performance_score VARCHAR(255),
    rating_label VARCHAR(255),
    goals_achieved_pct VARCHAR(255),
    communication_score VARCHAR(255),
    teamwork_score VARCHAR(255),
    leadership_score VARCHAR(255),
    technical_score VARCHAR(255),
    comments TEXT,
    department VARCHAR(255),
    created_at VARCHAR(255),
    _source_file VARCHAR(500) NOT NULL,
    _load_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    _row_hash CHAR(32) NOT NULL,
    _is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_bronze_perf_review_id (review_id),
    INDEX idx_bronze_perf_emp_id (employee_id),
    INDEX idx_bronze_perf_reviewer_id (reviewer_id),
    INDEX idx_bronze_perf_load_ts (_load_timestamp),
    INDEX idx_bronze_perf_row_hash (_row_hash)

) ENGINE=InnoDB;

DROP TABLE IF EXISTS bronze_training;

CREATE TABLE bronze_training (
    bronze_training_sk INT AUTO_INCREMENT PRIMARY KEY,
    training_id VARCHAR(255),
    employee_id VARCHAR(255),
    course_name VARCHAR(255),
    category VARCHAR(255),
    train_start_date VARCHAR(255),
    end_date VARCHAR(255),
    duration_days VARCHAR(255),
    completion_status VARCHAR(255),
    score VARCHAR(255),
    cost_lkr VARCHAR(255),
    trainer VARCHAR(255),
    department VARCHAR(255),
    train_year VARCHAR(255),
    _source_file VARCHAR(500) NOT NULL,
    _load_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    _row_hash CHAR(32) NOT NULL,
    _is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_bronze_trn_training_id (training_id),
    INDEX idx_bronze_trn_emp_id (employee_id),
    INDEX idx_bronze_trn_load_ts (_load_timestamp),
    INDEX idx_bronze_trn_row_hash (_row_hash)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS bronze_goals;

CREATE TABLE bronze_goals (
    bronze_goals_sk INT AUTO_INCREMENT PRIMARY KEY,
    goal_id VARCHAR(255),
    employee_id VARCHAR(255),
    goal_type VARCHAR(255),
    goal_description TEXT,
    set_date VARCHAR(255),
    due_date VARCHAR(255),
    target_value VARCHAR(255),
    achieved_value VARCHAR(255),
    achievement_pct VARCHAR(255),
    goal_status VARCHAR(255),
    quarter VARCHAR(255),
    department VARCHAR(255),
    goal_priority VARCHAR(255),
    _source_file VARCHAR(500) NOT NULL,
    _load_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    _row_hash CHAR(32) NOT NULL,
    _is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX idx_bronze_goals_goal_id (goal_id),
    INDEX idx_bronze_goals_emp_id (employee_id),
    INDEX idx_bronze_goals_load_ts (_load_timestamp),
    INDEX idx_bronze_goals_row_hash (_row_hash)
) ENGINE=InnoDB;

DROP PROCEDURE IF EXISTS sp_load_bronze_departments;

DELIMITER $$

CREATE PROCEDURE sp_load_bronze_departments(
    IN p_file_path VARCHAR(1000)
)
BEGIN

    DECLARE v_error_message VARCHAR(500);
    DECLARE v_rows_loaded INT DEFAULT 0;
    DECLARE v_load_start DATETIME DEFAULT NOW();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;
        SELECT CONCAT(
            '[ERROR] sp_load_bronze_departments FAILED at ',
            NOW(),
            ' | File: ', IFNULL(p_file_path, 'NULL'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error')
        ) AS error_log;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR SQLWARNING
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[WARNING] sp_load_bronze_departments at ',
            NOW(),
            ' | Warning: ', IFNULL(v_error_message, 'Unknown warning')
        ) AS warning_log;
    END;

    TRUNCATE TABLE bronze_departments;
        SET @load_sql = CONCAT(
        'LOAD DATA INFILE ''', p_file_path, ''' ',
        'INTO TABLE bronze_departments ',
        'FIELDS TERMINATED BY '','' ',
        'OPTIONALLY ENCLOSED BY ''"'' ',
        'LINES TERMINATED BY ''\\n'' ',
        'IGNORE 1 ROWS ',
        '(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8) ',
        'SET ',
        '  dept_id          = @col1, ',
        '  dept_name        = @col2, ',
        '  location         = @col3, ',
        '  manager_id       = @col4, ',
        '  created_date     = @col5, ',
        '  status           = @col6, ',
        '  headcount_budget = @col7, ',
        '  cost_center      = @col8, ',
        '  _source_file     = ''', p_file_path, ''', ',
        '  _load_timestamp  = NOW(), ',
        '  _row_hash        = MD5(CONCAT_WS(''|'', ',
        '                        IFNULL(@col1, ''''), IFNULL(@col2, ''''), ',
        '                        IFNULL(@col3, ''''), IFNULL(@col4, ''''), ',
        '                        IFNULL(@col5, ''''), IFNULL(@col6, ''''), ',
        '                        IFNULL(@col7, ''''), IFNULL(@col8, '''') ',
        '                     )), ',
        '  _is_deleted      = FALSE'
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET v_rows_loaded = ROW_COUNT();

    SELECT CONCAT(
        '[SUCCESS] sp_load_bronze_departments completed at ', NOW(),
        ' | Rows loaded: ', v_rows_loaded,
        ' | Duration: ', TIMESTAMPDIFF(SECOND, v_load_start, NOW()), ' seconds',
        ' | Source: ', p_file_path
    ) AS load_log;

END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_load_bronze_employees;

DELIMITER $$

CREATE PROCEDURE sp_load_bronze_employees(
    IN p_file_path VARCHAR(1000)
)
BEGIN
    DECLARE v_error_message VARCHAR(500);
    DECLARE v_rows_loaded INT DEFAULT 0;
    DECLARE v_load_start DATETIME DEFAULT NOW();

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[ERROR] sp_load_bronze_employees FAILED at ', NOW(),
            ' | File: ', IFNULL(p_file_path, 'NULL'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error')
        ) AS error_log;

        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR SQLWARNING
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[WARNING] sp_load_bronze_employees at ', NOW(),
            ' | Warning: ', IFNULL(v_error_message, 'Unknown warning')
        ) AS warning_log;
    END;

    TRUNCATE TABLE bronze_employees;

    SET @load_sql = CONCAT(
        'LOAD DATA INFILE ''', p_file_path, ''' ',
        'INTO TABLE bronze_employees ',
        'FIELDS TERMINATED BY '','' ',
        'OPTIONALLY ENCLOSED BY ''"'' ',
        'LINES TERMINATED BY ''\\n'' ',
        'IGNORE 1 ROWS ',
        '(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8, @col9, ',
        ' @col10, @col11, @col12, @col13, @col14, @col15, @col16, @col17) ',
        'SET ',
        '  employee_id       = @col1, ',
        '  first_name        = @col2, ',
        '  last_name         = @col3, ',
        '  gender            = @col4, ',
        '  date_of_birth     = @col5, ',
        '  email             = @col6, ',
        '  phone             = @col7, ',
        '  department_id     = @col8, ',
        '  department_name   = @col9, ',
        '  job_title         = @col10, ',
        '  employment_type   = @col11, ',
        '  join_date         = @col12, ',
        '  salary            = @col13, ',
        '  status            = @col14, ',
        '  location          = @col15, ',
        '  manager_id        = @col16, ',
        '  years_experience  = @col17, ',
        '  _source_file      = ''', p_file_path, ''', ',
        '  _load_timestamp   = NOW(), ',
        '  _row_hash         = MD5(CONCAT_WS(''|'', ',
        '                         IFNULL(@col1, ''''),  IFNULL(@col2, ''''), ',
        '                         IFNULL(@col3, ''''),  IFNULL(@col4, ''''), ',
        '                         IFNULL(@col5, ''''),  IFNULL(@col6, ''''), ',
        '                         IFNULL(@col7, ''''),  IFNULL(@col8, ''''), ',
        '                         IFNULL(@col9, ''''),  IFNULL(@col10, ''''), ',
        '                         IFNULL(@col11, ''''), IFNULL(@col12, ''''), ',
        '                         IFNULL(@col13, ''''), IFNULL(@col14, ''''), ',
        '                         IFNULL(@col15, ''''), IFNULL(@col16, ''''), ',
        '                         IFNULL(@col17, '''') ',
        '                      )), ',
        '  _is_deleted       = FALSE'
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET v_rows_loaded = ROW_COUNT();

    SELECT CONCAT(
        '[SUCCESS] sp_load_bronze_employees completed at ', NOW(),
        ' | Rows loaded: ', v_rows_loaded,
        ' | Duration: ', TIMESTAMPDIFF(SECOND, v_load_start, NOW()), ' seconds',
        ' | Source: ', p_file_path
    ) AS load_log;

END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_load_bronze_performance_reviews;

DELIMITER $$

CREATE PROCEDURE sp_load_bronze_performance_reviews(
    IN p_file_path VARCHAR(1000)
)
BEGIN
    DECLARE v_error_message VARCHAR(500);
    DECLARE v_rows_loaded INT DEFAULT 0;
    DECLARE v_load_start DATETIME DEFAULT NOW();

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[ERROR] sp_load_bronze_performance_reviews FAILED at ', NOW(),
            ' | File: ', IFNULL(p_file_path, 'NULL'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error')
        ) AS error_log;

        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR SQLWARNING
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[WARNING] sp_load_bronze_performance_reviews at ', NOW(),
            ' | Warning: ', IFNULL(v_error_message, 'Unknown warning')
        ) AS warning_log;
    END;

    TRUNCATE TABLE bronze_performance_reviews;

    SET @load_sql = CONCAT(
        'LOAD DATA INFILE ''', p_file_path, ''' ',
        'INTO TABLE bronze_performance_reviews ',
        'FIELDS TERMINATED BY '','' ',
        'OPTIONALLY ENCLOSED BY ''"'' ',
        'LINES TERMINATED BY ''\\n'' ',
        'IGNORE 1 ROWS ',
        '(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8, ',
        ' @col9, @col10, @col11, @col12, @col13, @col14, @col15) ',
        'SET ',
        '  review_id            = @col1, ',
        '  employee_id          = @col2, ',
        '  review_period        = @col3, ',
        '  review_date          = @col4, ',
        '  reviewer_id          = @col5, ',
        '  performance_score    = @col6, ',
        '  rating_label         = @col7, ',
        '  goals_achieved_pct   = @col8, ',
        '  communication_score  = @col9, ',
        '  teamwork_score       = @col10, ',
        '  leadership_score     = @col11, ',
        '  technical_score      = @col12, ',
        '  comments             = @col13, ',
        '  department           = @col14, ',
        '  created_at           = @col15, ',
        '  _source_file         = ''', p_file_path, ''', ',
        '  _load_timestamp      = NOW(), ',
        '  _row_hash            = MD5(CONCAT_WS(''|'', ',
        '                            IFNULL(@col1, ''''),  IFNULL(@col2, ''''), ',
        '                            IFNULL(@col3, ''''),  IFNULL(@col4, ''''), ',
        '                            IFNULL(@col5, ''''),  IFNULL(@col6, ''''), ',
        '                            IFNULL(@col7, ''''),  IFNULL(@col8, ''''), ',
        '                            IFNULL(@col9, ''''),  IFNULL(@col10, ''''), ',
        '                            IFNULL(@col11, ''''), IFNULL(@col12, ''''), ',
        '                            IFNULL(@col13, ''''), IFNULL(@col14, ''''), ',
        '                            IFNULL(@col15, '''') ',
        '                         )), ',
        '  _is_deleted          = FALSE'
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET v_rows_loaded = ROW_COUNT();

    SELECT CONCAT(
        '[SUCCESS] sp_load_bronze_performance_reviews completed at ', NOW(),
        ' | Rows loaded: ', v_rows_loaded,
        ' | Duration: ', TIMESTAMPDIFF(SECOND, v_load_start, NOW()), ' seconds',
        ' | Source: ', p_file_path
    ) AS load_log;

END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_load_bronze_training;

DELIMITER $$

CREATE PROCEDURE sp_load_bronze_training(
    IN p_file_path VARCHAR(1000)
)
BEGIN
    DECLARE v_error_message VARCHAR(500);
    DECLARE v_rows_loaded INT DEFAULT 0;
    DECLARE v_load_start DATETIME DEFAULT NOW();

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[ERROR] sp_load_bronze_training FAILED at ', NOW(),
            ' | File: ', IFNULL(p_file_path, 'NULL'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error')
        ) AS error_log;

        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR SQLWARNING
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[WARNING] sp_load_bronze_training at ', NOW(),
            ' | Warning: ', IFNULL(v_error_message, 'Unknown warning')
        ) AS warning_log;
    END;

    TRUNCATE TABLE bronze_training;

    SET @load_sql = CONCAT(
        'LOAD DATA INFILE ''', p_file_path, ''' ',
        'INTO TABLE bronze_training ',
        'FIELDS TERMINATED BY '','' ',
        'OPTIONALLY ENCLOSED BY ''"'' ',
        'LINES TERMINATED BY ''\\n'' ',
        'IGNORE 1 ROWS ',
        '(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8, ',
        ' @col9, @col10, @col11, @col12, @col13) ',
        'SET ',
        '  training_id        = @col1, ',
        '  employee_id        = @col2, ',
        '  course_name        = @col3, ',
        '  category           = @col4, ',
        '  start_date         = @col5, ',
        '  end_date           = @col6, ',
        '  duration_days      = @col7, ',
        '  completion_status  = @col8, ',
        '  score              = @col9, ',
        '  cost_lkr           = @col10, ',
        '  trainer            = @col11, ',
        '  department         = @col12, ',
        '  year               = @col13, ',
        '  _source_file       = ''', p_file_path, ''', ',
        '  _load_timestamp    = NOW(), ',
        '  _row_hash          = MD5(CONCAT_WS(''|'', ',
        '                          IFNULL(@col1, ''''),  IFNULL(@col2, ''''), ',
        '                          IFNULL(@col3, ''''),  IFNULL(@col4, ''''), ',
        '                          IFNULL(@col5, ''''),  IFNULL(@col6, ''''), ',
        '                          IFNULL(@col7, ''''),  IFNULL(@col8, ''''), ',
        '                          IFNULL(@col9, ''''),  IFNULL(@col10, ''''), ',
        '                          IFNULL(@col11, ''''), IFNULL(@col12, ''''), ',
        '                          IFNULL(@col13, '''') ',
        '                       )), ',
        '  _is_deleted        = FALSE'
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET v_rows_loaded = ROW_COUNT();

    SELECT CONCAT(
        '[SUCCESS] sp_load_bronze_training completed at ', NOW(),
        ' | Rows loaded: ', v_rows_loaded,
        ' | Duration: ', TIMESTAMPDIFF(SECOND, v_load_start, NOW()), ' seconds',
        ' | Source: ', p_file_path
    ) AS load_log;

END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_load_bronze_goals;

DELIMITER $$

CREATE PROCEDURE sp_load_bronze_goals(
    IN p_file_path VARCHAR(1000)
)
BEGIN
    DECLARE v_error_message VARCHAR(500);
    DECLARE v_rows_loaded INT DEFAULT 0;
    DECLARE v_load_start DATETIME DEFAULT NOW();

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[ERROR] sp_load_bronze_goals FAILED at ', NOW(),
            ' | File: ', IFNULL(p_file_path, 'NULL'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error')
        ) AS error_log;

        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR SQLWARNING
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[WARNING] sp_load_bronze_goals at ', NOW(),
            ' | Warning: ', IFNULL(v_error_message, 'Unknown warning')
        ) AS warning_log;
    END;

    TRUNCATE TABLE bronze_goals;

    SET @load_sql = CONCAT(
        'LOAD DATA INFILE ''', p_file_path, ''' ',
        'INTO TABLE bronze_goals ',
        'FIELDS TERMINATED BY '','' ',
        'OPTIONALLY ENCLOSED BY ''"'' ',
        'LINES TERMINATED BY ''\\n'' ',
        'IGNORE 1 ROWS ',
        '(@col1, @col2, @col3, @col4, @col5, @col6, @col7, @col8, ',
        ' @col9, @col10, @col11, @col12, @col13) ',
        'SET ',
        '  goal_id            = @col1, ',
        '  employee_id        = @col2, ',
        '  goal_type          = @col3, ',
        '  goal_description   = @col4, ',
        '  set_date           = @col5, ',
        '  due_date           = @col6, ',
        '  target_value       = @col7, ',
        '  achieved_value     = @col8, ',
        '  achievement_pct    = @col9, ',
        '  status             = @col10, ',
        '  quarter            = @col11, ',
        '  department         = @col12, ',
        '  priority           = @col13, ',
        '  _source_file       = ''', p_file_path, ''', ',
        '  _load_timestamp    = NOW(), ',
        '  _row_hash          = MD5(CONCAT_WS(''|'', ',
        '                          IFNULL(@col1, ''''),  IFNULL(@col2, ''''), ',
        '                          IFNULL(@col3, ''''),  IFNULL(@col4, ''''), ',
        '                          IFNULL(@col5, ''''),  IFNULL(@col6, ''''), ',
        '                          IFNULL(@col7, ''''),  IFNULL(@col8, ''''), ',
        '                          IFNULL(@col9, ''''),  IFNULL(@col10, ''''), ',
        '                          IFNULL(@col11, ''''), IFNULL(@col12, ''''), ',
        '                          IFNULL(@col13, '''') ',
        '                       )), ',
        '  _is_deleted        = FALSE'
    );

    PREPARE stmt FROM @load_sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET v_rows_loaded = ROW_COUNT();

    SELECT CONCAT(
        '[SUCCESS] sp_load_bronze_goals completed at ', NOW(),
        ' | Rows loaded: ', v_rows_loaded,
        ' | Duration: ', TIMESTAMPDIFF(SECOND, v_load_start, NOW()), ' seconds',
        ' | Source: ', p_file_path
    ) AS load_log;

END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_load_all_bronze;

DELIMITER $$

CREATE PROCEDURE sp_load_all_bronze(
    IN p_departments_file    VARCHAR(1000),
    IN p_employees_file      VARCHAR(1000),
    IN p_perf_reviews_file   VARCHAR(1000),
    IN p_training_file       VARCHAR(1000),
    IN p_goals_file          VARCHAR(1000)
)
BEGIN
    DECLARE v_error_message VARCHAR(500);
    DECLARE v_total_start DATETIME DEFAULT NOW();
    DECLARE v_step VARCHAR(100);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_message = MESSAGE_TEXT;

        SELECT CONCAT(
            '[ERROR] sp_load_all_bronze FAILED at ', NOW(),
            ' | Failed Step: ', IFNULL(v_step, 'Unknown'),
            ' | Error: ', IFNULL(v_error_message, 'Unknown error'),
            ' | Elapsed: ', TIMESTAMPDIFF(SECOND, v_total_start, NOW()), ' seconds'
        ) AS error_log;

        RESIGNAL;
    END;

    SELECT CONCAT(
        '============================================================', CHAR(10),
        ' BRONZE LAYER FULL LOAD STARTED AT ', NOW(), CHAR(10),
        '============================================================'
    ) AS orchestrator_log;

    SET v_step = 'DEPARTMENTS';
    SELECT CONCAT('[STEP 1/5] Loading bronze_departments from: ', p_departments_file) AS progress;
    CALL sp_load_bronze_departments(p_departments_file);

    SET v_step = 'EMPLOYEES';
    SELECT CONCAT('[STEP 2/5] Loading bronze_employees from: ', p_employees_file) AS progress;
    CALL sp_load_bronze_employees(p_employees_file);

    SET v_step = 'PERFORMANCE_REVIEWS';
    SELECT CONCAT('[STEP 3/5] Loading bronze_performance_reviews from: ', p_perf_reviews_file) AS progress;
    CALL sp_load_bronze_performance_reviews(p_perf_reviews_file);

    SET v_step = 'TRAINING';
    SELECT CONCAT('[STEP 4/5] Loading bronze_training from: ', p_training_file) AS progress;
    CALL sp_load_bronze_training(p_training_file);

    SET v_step = 'GOALS';
    SELECT CONCAT('[STEP 5/5] Loading bronze_goals from: ', p_goals_file) AS progress;
    CALL sp_load_bronze_goals(p_goals_file);

    SELECT
        '============================================================' AS separator;

    SELECT
        'BRONZE LAYER LOAD SUMMARY' AS title,
        NOW() AS completed_at,
        TIMESTAMPDIFF(SECOND, v_total_start, NOW()) AS total_duration_seconds;

    SELECT
        'bronze_departments' AS table_name,
        COUNT(*) AS row_count
    FROM bronze_departments
    UNION ALL
    SELECT
        'bronze_employees',
        COUNT(*)
    FROM bronze_employees
    UNION ALL
    SELECT
        'bronze_performance_reviews',
        COUNT(*)
    FROM bronze_performance_reviews
    UNION ALL
    SELECT
        'bronze_training',
        COUNT(*)
    FROM bronze_training
    UNION ALL
    SELECT
        'bronze_goals',
        COUNT(*)
    FROM bronze_goals;

    SELECT
        '============================================================' AS separator,
        'ALL 5 BRONZE TABLES LOADED SUCCESSFULLY' AS status;

END$$

DELIMITER ;


