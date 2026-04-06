SET FOREIGN_KEY_CHECKS = 0;          -- Allow forward-reference during build
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- ── Create & select the database ──────────────────────────────
CREATE DATABASE IF NOT EXISTS ydy_hrm
    CHARACTER SET  utf8mb4
    COLLATE        utf8mb4_unicode_ci;

USE ydy_hrm;


-- ============================================================
-- PAGE 1 ▸ COMPANY PROFILE
-- The CHECK constraint enforces the single-row rule.
-- ============================================================
CREATE TABLE company_profile ( 
    id                      TINYINT UNSIGNED    NOT NULL DEFAULT 1,

    -- ── Legal & Incorporation ─────────────────────────────
    legal_name              VARCHAR(150)        NOT NULL,
    trading_name            VARCHAR(100),
    ceo_name                VARCHAR(100),
    head_office_address     TEXT,
    entity_type             VARCHAR(60),                        -- e.g. 'Private Ltd. Co'
    establishment_date      DATE,
    registration_number     VARCHAR(80),
    tin                     VARCHAR(30),                        -- Tax Identification Number
    vat_number              VARCHAR(50),
    trade_license_number    VARCHAR(80),

    -- ── Operational Policies ─────────────────────────────
    work_week_description   VARCHAR(150),                       -- 'Mon–Fri (40 hrs) Sat (Half day)'
    probation_days          VARCHAR(150),
    retirement_age          VARCHAR(150),

    -- ── Treasury / Finance ───────────────────────────────
    main_bank               VARCHAR(100),
    bank_account_primary    VARCHAR(100),
    base_currency           VARCHAR(100),
    fiscal_year_start_month VARCHAR(100),   

    -- ── Digital Identity ─────────────────────────────────
    website_url             VARCHAR(255),
    helpdesk_email          VARCHAR(150),
    corporate_phone         VARCHAR(30),
    logo_path               VARCHAR(255),

    -- ── Social Media ────────────────────────────────────
    linkedin_handle         VARCHAR(100),
    telegram_handle         VARCHAR(100),
    facebook_handle         VARCHAR(100),

    -- ── Audit ────────────────────────────────────────────
    updated_at              TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_company       PRIMARY KEY (id),
    CONSTRAINT chk_single_row   CHECK (id = 1)          -- Enforce exactly one company record
);

-- Seed the single company row immediately
-- (Update these values to match the real company later)
INSERT INTO company_profile (
    id, legal_name, trading_name, ceo_name,
    head_office_address, entity_type, establishment_date,
    registration_number, tin, vat_number, trade_license_number,
    work_week_description, probation_days, retirement_age,
    main_bank, bank_account_primary, base_currency,
    fiscal_year_start_month, website_url, helpdesk_email,
    corporate_phone, linkedin_handle, telegram_handle, facebook_handle
) VALUES (
    1,
    'YDY HRM Enterprise Ltd.',
    'YDY Systems',
    'YDY Systems',
    'Mexico, Lideta, Addis Ababa',
    'Private Ltd. Co',
    '2010-10-12',
    'MT/AA/14/667/09',
    '0019283746',
    '9928374-VAT-01',
    '01/01/14/19283',
    'Mon — Fri (40 hrs)  Sat (Half day)',
    90,
    60,
    'CBE (Commercial Bank of Ethiopia)',
    '1000192837465',
    'ETB',
    7,
    'www.ydy-hrm.com',
    'support@ydyhrm.com',
    '+251 11 667 89',
    '/ydy-systems',
    '@YDY_Systems',
    '/YDY.Enterprise'
);


-- ============================================================
-- PAGE 2 ▸ BRANCH OFFICES
-- Each office location the company operates from. 
-- ============================================================
CREATE TABLE branches (
    branch_id       SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    branch_name     VARCHAR(100)        NOT NULL,  
    location        TEXT,
    phone           VARCHAR(30),
    email           VARCHAR(150),
    -- manager is added via FK after employees table is created
    manager_emp_id  INT UNSIGNED,
    status          ENUM('Active','Inactive') NOT NULL DEFAULT 'Active',
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (branch_id),
    INDEX idx_branch_status  (status),          -- Filter active/inactive branches fast
    INDEX idx_branch_name    (branch_name)       -- Search by name
);


-- ============================================================
-- PAGE 3 ▸ DEPARTMENTS
-- Organisational units within the company.
-- head_emp_id FK is added after the employees table is created
-- to avoid a circular-reference problem.
-- ============================================================
CREATE TABLE departments (
    dept_id         SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    dept_name       VARCHAR(100)        NOT NULL,                     -- Which branch this dept sits in
    head_emp_id     INT UNSIGNED,                               -- HOD (FK added via ALTER below)
    description     TEXT,
    status          ENUM('Active','Inactive') NOT NULL DEFAULT 'Active',
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (dept_id),
    UNIQUE  KEY uk_dept_name        (dept_name),                -- No duplicate dept names
    INDEX       idx_dept_branch     (branch_id),
    INDEX       idx_dept_status     (status),

    CONSTRAINT fk_dept_branch
        FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 4 ▸ EMPLOYMENT TYPES
-- Master list: Full-Time, Contract, Part-Time, Intern, Casual …
-- ============================================================
CREATE TABLE employment_types (
    type_id         TINYINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    type_name       VARCHAR(80)         NOT NULL,
    description     TEXT, 

    PRIMARY KEY (type_id),
    UNIQUE KEY uk_type_name (type_name)                         -- Prevent duplicate type names
);

-- Seed standard employment types (matches the UI)
INSERT INTO employment_types (type_name, description, has_benefits, is_permanent) VALUES
('Permanent / Full-Time', 'Regular employee with full benefits',            'Yes',     1),
('Fixed-Term Contract',   'Time-bound employment agreement',                'Partial', 0),
('Part-Time',             'Less than 40 hours per week',                    'Partial', 0),
('Internship',            'Student or graduate trainee',                    'No',      0),
('Temporary / Casual',    'Short-term project-based',                       'No',      0);


-- ============================================================
-- PAGE 5 ▸ JOB POSITIONS
-- Titles that exist in the org — linked to a department.
-- headcount_target helps HR spot where hiring gaps exist.
-- ============================================================
CREATE TABLE job_positions (
    position_id     SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    title           VARCHAR(150)        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    grade_level     VARCHAR(10),                    
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (position_id),
    INDEX idx_pos_dept   (dept_id),                            -- Join to departments
    INDEX idx_pos_title  (title),                              -- Search by job title
    INDEX idx_pos_active (is_active),

    CONSTRAINT fk_pos_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 6 ▸ EMPLOYEES  (the central/core table)
-- Almost every other table FK's back to this one.
-- reports_to_emp_id is a self-referential FK (manager hierarchy).
-- ============================================================
CREATE TABLE employees (
    emp_id                  INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_code                VARCHAR(10)         NOT NULL,       -- E0001, E0002 …

    -- ── Section A: Personal Identity (Onboarding Step 1) ──
    first_name              VARCHAR(80)         NOT NULL,
    middle_name             VARCHAR(80),
    last_name               VARCHAR(80)         NOT NULL,
    gender                  ENUM('Male','Female','Other') NOT NULL,
    date_of_birth           DATE                NOT NULL,
    nationality             VARCHAR(80)         NOT NULL DEFAULT 'Ethiopian',
    marital_status          ENUM('Single','Married','Divorced','Widowed') NOT NULL DEFAULT 'Single',
    place_of_birth          VARCHAR(100),
    profile_photo_path      VARCHAR(255),

    -- ── Section B: Contact Channels (Onboarding Step 2) ──
    personal_phone          VARCHAR(25),
    personal_email          VARCHAR(150),
    permanent_address       TEXT,
    city                    VARCHAR(80),
    postal_code             VARCHAR(20),

    -- ── Section C: Employment Placement (Onboarding Step 3) ──
    dept_id                 SMALLINT UNSIGNED,
    position_id             SMALLINT UNSIGNED,
    branch_id               SMALLINT UNSIGNED,
    type_id                 TINYINT UNSIGNED,
    reports_to_emp_id       INT UNSIGNED,                       -- Manager (self-join)
    hire_date               DATE                NOT NULL,
    contract_start_date     DATE,
    contract_end_date       DATE,                               -- NULL = permanent/open-ended
    probation_end_date      DATE,

    -- ── Section D: Financial & Treasury (Onboarding Step 4) ──
    gross_salary            DECIMAL(14,2),
    tin_number              VARCHAR(30),                        -- Employee's personal TIN
    bank_name               VARCHAR(100),
    bank_account_number     VARCHAR(60),

    -- ── Section E: Compliance & Legal (Onboarding Step 5) ──
    id_type                 ENUM('National ID','Passport','Other') NOT NULL DEFAULT 'National ID',
    id_number               VARCHAR(60),
    id_expiry_date          DATE,
    emergency_contact_name  VARCHAR(150),
    emergency_contact_phone VARCHAR(25),
    emergency_contact_relation VARCHAR(50),

    -- ── System / Status ──────────────────────────────────
    status                  ENUM('Active','Inactive','Terminated','Resigned','Retired')
                                                NOT NULL DEFAULT 'Active',
    created_at              TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (emp_id),
    UNIQUE  KEY uk_emp_code      (emp_code),                   -- Human-readable unique ID
    UNIQUE  KEY uk_emp_email     (personal_email),
    INDEX       idx_emp_dept     (dept_id),                    -- Filter/join by department
    INDEX       idx_emp_position (position_id),                -- Filter/join by role
    INDEX       idx_emp_branch   (branch_id),
    INDEX       idx_emp_type     (type_id),
    INDEX       idx_emp_status   (status),                     -- Fast active/inactive filter
    INDEX       idx_emp_manager  (reports_to_emp_id),          -- Org-chart traversal
    INDEX       idx_emp_hire     (hire_date),                  -- For anniversary / tenure queries
    INDEX       idx_emp_contract (contract_end_date),          -- Contract renewal alerts
    INDEX       idx_emp_name     (last_name, first_name),      -- Name search

    CONSTRAINT fk_emp_dept
        FOREIGN KEY (dept_id)     REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_emp_position
        FOREIGN KEY (position_id) REFERENCES job_positions(position_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_emp_branch
        FOREIGN KEY (branch_id)   REFERENCES branches(branch_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_emp_type
        FOREIGN KEY (type_id)     REFERENCES employment_types(type_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (reports_to_emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ── Now that employees exists, close the circular FK loops ───
ALTER TABLE departments
    ADD CONSTRAINT fk_dept_head
        FOREIGN KEY (head_emp_id) REFERENCES employees(emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE branches
    ADD CONSTRAINT fk_branch_manager
        FOREIGN KEY (manager_emp_id) REFERENCES employees(emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE;


-- ============================================================
-- PAGE 6 ▸ PROBATION TRACKER
-- Auto-populated when a new employee is created.
-- probation_end_date copied from employees.probation_end_date.
-- ============================================================
CREATE TABLE probation_records (
    prob_id             INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id              INT UNSIGNED        NOT NULL,
    probation_start     DATE                NOT NULL,
    probation_end       DATE                NOT NULL,
    status              ENUM('Active','Passed','Extended','Terminated')
                                            NOT NULL DEFAULT 'Active',
    reviewer_emp_id     INT UNSIGNED,                           -- Who confirmed the outcome
    outcome_notes       TEXT,
    reviewed_at         DATE,
    created_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (prob_id),
    INDEX idx_prob_emp    (emp_id),
    INDEX idx_prob_status (status),
    INDEX idx_prob_end    (probation_end),                      -- "Ending Soon" dashboard alert

    CONSTRAINT fk_prob_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_prob_reviewer
        FOREIGN KEY (reviewer_emp_id) REFERENCES employees(emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 6 ▸ CONTRACT RENEWALS
-- Tracks every contract version for Fixed-Term employees.
-- A new row is inserted each time a contract is renewed.
-- ============================================================
CREATE TABLE contract_renewals (
    renewal_id          INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id              INT UNSIGNED        NOT NULL,
    contract_version    TINYINT UNSIGNED    NOT NULL DEFAULT 1, -- 1st, 2nd, 3rd renewal …
    start_date          DATE                NOT NULL,
    end_date            DATE                NOT NULL,
    salary_at_renewal   DECIMAL(14,2),
    status              ENUM('Active','Expired','Terminated','Pending')
                                            NOT NULL DEFAULT 'Active',
    renewed_by_emp_id   INT UNSIGNED,                           -- HR user who processed it
    notes               TEXT,
    created_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (renewal_id),
    INDEX idx_cr_emp    (emp_id),
    INDEX idx_cr_end    (end_date),                             -- Expiry alert index
    INDEX idx_cr_status (status),

    CONSTRAINT fk_cr_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cr_renewed_by
        FOREIGN KEY (renewed_by_emp_id) REFERENCES employees(emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 7 ▸ FORMER EMPLOYEES
-- A summary record created when an employee leaves.
-- The employees row is kept (status='Resigned'/'Terminated').
-- ============================================================
CREATE TABLE former_employees (
    record_id           INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id              INT UNSIGNED        NOT NULL,
    exit_date           DATE                NOT NULL,
    exit_reason         ENUM('Resigned','Terminated','Retired','End of Contract','Deceased','Other')
                                            NOT NULL,
    rehire_eligible     ENUM('Yes','No','Conditional') NOT NULL DEFAULT 'Yes',
    final_settlement    DECIMAL(14,2),
    notes               TEXT,
    processed_by        INT UNSIGNED,                           -- HR officer
    created_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (record_id),
    UNIQUE  KEY uk_fe_emp      (emp_id),                        -- One exit record per employee
    INDEX       idx_fe_reason  (exit_reason),
    INDEX       idx_fe_rehire  (rehire_eligible),

    CONSTRAINT fk_fe_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fe_processor
        FOREIGN KEY (processed_by) REFERENCES employees(emp_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 8 ▸ DOCUMENT / ATTACHMENT VAULT
-- ── 8a. vault_document_types ─────────────────────────────────
-- Master list of documents the company requires from all staff.
-- Edit this table to add / remove document requirements.
-- ============================================================
CREATE TABLE vault_document_types (
    doc_type_id     SMALLINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    doc_name        VARCHAR(150)        NOT NULL,               -- e.g. 'Signed Employment Contract'
    category        VARCHAR(60),                                -- 'Legal','Identity','Education' …
    is_mandatory    TINYINT(1)          NOT NULL DEFAULT 1,
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,

    PRIMARY KEY (doc_type_id),
    UNIQUE KEY uk_doctype_name (doc_name)
);

-- Seed with the 12 mandatory docs visible in the UI
INSERT INTO vault_document_types (doc_name, category) VALUES
('Signed Employment Contract',          'Legal'),
('Curriculum Vitae (CV)',               'Identity'),
('Academic Credentials',                'Education'),
('Clearance / Release Letter',          'History'),
('Experience Letters',                  'History'),
('Certificate of Competence (COC)',     'Professional'),
('Guarantor Form & ID',                 'Legal'),
('Confidentiality / NDA Agreement',     'Compliance'),
('Acknowledgments',                     'Compliance'),
('National ID / Passport Copy',         'Identity'),
('TIN Certification Document',          'Tax'),
('Health & Fitness Clearance',          'Compliance');


-- ── 8b. employee_documents ───────────────────────────────────
-- One row per employee–document combination.
-- status='Uploaded' means the file is stored; 'Missing' = not yet.
-- ============================================================
CREATE TABLE employee_documents (
    emp_doc_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    doc_type_id     SMALLINT UNSIGNED   NOT NULL,
    file_path       VARCHAR(500),                               -- Relative path to stored file
    file_name       VARCHAR(255),
    file_size_kb    INT UNSIGNED,
    uploaded_at     DATETIME,
    expiry_date     DATE,                                       -- For IDs, certificates with expiry
    status          ENUM('Uploaded','Missing','Expired')
                                        NOT NULL DEFAULT 'Missing',
    notes           TEXT,
    uploaded_by     INT UNSIGNED,                               -- HR user who uploaded it
    updated_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (emp_doc_id),
    UNIQUE  KEY uk_emp_doctype   (emp_id, doc_type_id),        -- One entry per doc per employee
    INDEX       idx_ed_emp       (emp_id),
    INDEX       idx_ed_status    (status),                      -- Compliance dashboard queries
    INDEX       idx_ed_expiry    (expiry_date),                 -- Expiry alerts

    CONSTRAINT fk_ed_emp
        FOREIGN KEY (emp_id)      REFERENCES employees(emp_id)  ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ed_doctype
        FOREIGN KEY (doc_type_id) REFERENCES vault_document_types(doc_type_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ed_uploader
        FOREIGN KEY (uploaded_by) REFERENCES employees(emp_id)  ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 9 ▸ ASSET TRACKING
-- ── 9a. asset_categories ─────────────────────────────────────
-- ============================================================
CREATE TABLE asset_categories (
    cat_id      TINYINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    cat_name    VARCHAR(80)         NOT NULL,

    PRIMARY KEY (cat_id),
    UNIQUE KEY uk_cat_name (cat_name)
);

INSERT INTO asset_categories (cat_name) VALUES
('IT Hardware'), ('Fleet / Vehicles'), ('Office Furniture'),
('Networking'), ('Security Equipment'), ('Other');


-- ── 9b. assets ───────────────────────────────────────────────
CREATE TABLE assets (
    asset_id            INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    asset_code          VARCHAR(20)         NOT NULL,           -- AST-2001, AST-2002 …
    asset_name          VARCHAR(150)        NOT NULL,
    cat_id              TINYINT UNSIGNED,
    serial_number       VARCHAR(100),
    purchase_value      DECIMAL(14,2),
    purchase_date       DATE,
    warranty_expiry     DATE,
    current_custodian   INT UNSIGNED,                           -- FK to employees
    branch_id           SMALLINT UNSIGNED,                      -- Physical location
    status              ENUM('Active','Assigned','Under Repair','Retired','Lost')
                                            NOT NULL DEFAULT 'Active',
    notes               TEXT,
    created_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
                                            ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (asset_id),
    UNIQUE  KEY uk_asset_code      (asset_code),
    UNIQUE  KEY uk_serial          (serial_number),
    INDEX       idx_asset_cat      (cat_id),
    INDEX       idx_asset_custodian(current_custodian),
    INDEX       idx_asset_branch   (branch_id),
    INDEX       idx_asset_status   (status),
    INDEX       idx_asset_warranty (warranty_expiry),           -- Warranty expiry alerts

    CONSTRAINT fk_asset_cat
        FOREIGN KEY (cat_id) REFERENCES asset_categories(cat_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_asset_custodian
        FOREIGN KEY (current_custodian) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_asset_branch
        FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 9c. asset_assignment_history ─────────────────────────────
-- Full log of every custodian change — never deleted.
-- ============================================================
CREATE TABLE asset_assignment_history (
    history_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    asset_id        INT UNSIGNED        NOT NULL,
    from_emp_id     INT UNSIGNED,                               -- Previous custodian (NULL = new assignment)
    to_emp_id       INT UNSIGNED,                               -- New custodian (NULL = returned to stock)
    reassigned_by   INT UNSIGNED,                               -- HR/Admin who made the change
    reassigned_at   TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason          VARCHAR(255),

    PRIMARY KEY (history_id),
    INDEX idx_aah_asset   (asset_id),
    INDEX idx_aah_to_emp  (to_emp_id),
    INDEX idx_aah_from_emp(from_emp_id),

    CONSTRAINT fk_aah_asset
        FOREIGN KEY (asset_id)       REFERENCES assets(asset_id)    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_aah_from
        FOREIGN KEY (from_emp_id)    REFERENCES employees(emp_id)   ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_aah_to
        FOREIGN KEY (to_emp_id)      REFERENCES employees(emp_id)   ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_aah_by
        FOREIGN KEY (reassigned_by)  REFERENCES employees(emp_id)   ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 10 ▸ TALENT ACQUISITION — JOB VACANCIES
-- ============================================================
CREATE TABLE job_vacancies (
    vacancy_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    title           VARCHAR(150)        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    position_id     SMALLINT UNSIGNED,
    branch_id       SMALLINT UNSIGNED,
    type_id         TINYINT UNSIGNED,                           -- Full-Time / Contract …
    job_description TEXT,
    requirements    TEXT,
    posted_date     DATE,
    deadline_date   DATE,
    openings        TINYINT UNSIGNED    NOT NULL DEFAULT 1,
    status          ENUM('Open','On Hold','Filled','Cancelled') NOT NULL DEFAULT 'Open',
    created_by      INT UNSIGNED,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (vacancy_id),
    INDEX idx_vac_dept   (dept_id),
    INDEX idx_vac_status (status),
    INDEX idx_vac_dead   (deadline_date),                       -- Expiry alerts

    CONSTRAINT fk_vac_dept
        FOREIGN KEY (dept_id)     REFERENCES departments(dept_id)   ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_vac_position
        FOREIGN KEY (position_id) REFERENCES job_positions(position_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_vac_branch
        FOREIGN KEY (branch_id)   REFERENCES branches(branch_id)    ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_vac_type
        FOREIGN KEY (type_id)     REFERENCES employment_types(type_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_vac_creator
        FOREIGN KEY (created_by)  REFERENCES employees(emp_id)      ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 11 ▸ JOB APPLICANTS / CANDIDATES
-- ============================================================
CREATE TABLE job_applicants (
    applicant_id    INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    vacancy_id      INT UNSIGNED        NOT NULL,
    full_name       VARCHAR(150)        NOT NULL,
    email           VARCHAR(150),
    phone           VARCHAR(25),
    cv_path         VARCHAR(500),                               -- Uploaded résumé file path
    applied_date    DATE                NOT NULL,
    stage           ENUM('Applied','Screening','Interview','Assessment','Offer','Hired','Rejected')
                                        NOT NULL DEFAULT 'Applied',
    notes           TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (applicant_id),
    INDEX idx_app_vacancy (vacancy_id),
    INDEX idx_app_stage   (stage),

    CONSTRAINT fk_app_vacancy
        FOREIGN KEY (vacancy_id) REFERENCES job_vacancies(vacancy_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 12 ▸ INTERVIEW TRACKER
-- Multiple interview rounds per applicant are supported.
-- ============================================================
CREATE TABLE interviews (
    interview_id    INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    applicant_id    INT UNSIGNED        NOT NULL,
    interviewer_id  INT UNSIGNED,                               -- Internal employee doing the interview
    interview_date  DATE                NOT NULL,
    interview_time  TIME,
    mode            ENUM('In-Person','Video Call','Phone','Written Test') NOT NULL DEFAULT 'In-Person',
    round           TINYINT UNSIGNED    NOT NULL DEFAULT 1,     -- 1st, 2nd … round
    score           TINYINT UNSIGNED,                           -- 0–100
    result          ENUM('Scheduled','Passed','Failed','On Hold','No Show') NOT NULL DEFAULT 'Scheduled',
    feedback        TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (interview_id),
    INDEX idx_int_applicant   (applicant_id),
    INDEX idx_int_interviewer (interviewer_id),
    INDEX idx_int_date        (interview_date),
    INDEX idx_int_result      (result),

    CONSTRAINT fk_int_applicant
        FOREIGN KEY (applicant_id)  REFERENCES job_applicants(applicant_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_int_interviewer
        FOREIGN KEY (interviewer_id) REFERENCES employees(emp_id)           ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 13 ▸ INTERNSHIP MANAGEMENT
-- ============================================================
CREATE TABLE interns (
    intern_id       INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    intern_code     VARCHAR(15)         NOT NULL,               -- INT-26-001
    full_name       VARCHAR(150)        NOT NULL,
    email           VARCHAR(150),
    phone           VARCHAR(25),
    institution     VARCHAR(150),                               -- University name
    dept_id         SMALLINT UNSIGNED,
    mentor_emp_id   INT UNSIGNED,
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    evaluation_score DECIMAL(5,2),                              -- Out of 100
    potential_hire  TINYINT(1)          NOT NULL DEFAULT 0,
    status          ENUM('Active','Completed','Terminated') NOT NULL DEFAULT 'Active',
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (intern_id),
    UNIQUE  KEY uk_intern_code (intern_code),
    INDEX       idx_intern_dept   (dept_id),
    INDEX       idx_intern_mentor (mentor_emp_id),
    INDEX       idx_intern_status (status),

    CONSTRAINT fk_intern_dept
        FOREIGN KEY (dept_id)       REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_intern_mentor
        FOREIGN KEY (mentor_emp_id) REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 14 ▸ ATTENDANCE
-- ── 14a. attendance_records (Daily atomic record per employee)─
-- One row = one employee on one calendar day.
-- The composite UNIQUE key prevents accidental double-entry.
-- ============================================================
CREATE TABLE attendance_records (
    att_id          INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    att_date        DATE                NOT NULL,
    check_in        TIME,
    check_out       TIME,
    hours_worked    DECIMAL(4,2),                               -- e.g. 8.50
    overtime_hours  DECIMAL(4,2)        NOT NULL DEFAULT 0.00,
    status          ENUM('Present','Absent','Late','On Leave','Half Day','Holiday','Sunday Off')
                                        NOT NULL DEFAULT 'Present',
    recorded_by     INT UNSIGNED,                               -- HR user who entered/approved
    notes           VARCHAR(255),
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (att_id),
    UNIQUE  KEY uk_att_emp_date   (emp_id, att_date),           -- Cannot enter same employee twice per day
    INDEX       idx_att_date      (att_date),                   -- Date-range queries
    INDEX       idx_att_status    (status),
    INDEX       idx_att_emp       (emp_id),

    CONSTRAINT fk_att_emp
        FOREIGN KEY (emp_id)      REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_att_recorded_by
        FOREIGN KEY (recorded_by) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 14b. attendance_monthly_summary ──────────────────────────
-- Pre-aggregated monthly roll-up per employee, per department.
-- Rebuilt each time HR commits the monthly ledger.
-- Speeds up the Attendance Reports page dramatically.
-- ============================================================
CREATE TABLE attendance_monthly_summary (
    summary_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    att_year        SMALLINT UNSIGNED   NOT NULL,               -- e.g. 2026
    att_month       TINYINT UNSIGNED    NOT NULL,               -- 1–12
    days_present    TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    days_absent     TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    days_leave      TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    days_late       TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    total_ot_hours  DECIMAL(5,2)        NOT NULL DEFAULT 0.00,
    attendance_rate DECIMAL(5,2),                               -- Computed: present/working_days*100
    committed_at    TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (summary_id),
    UNIQUE  KEY uk_ams_emp_period (emp_id, att_year, att_month), -- One summary row per employee per month
    INDEX       idx_ams_period    (att_year, att_month),
    INDEX       idx_ams_dept      (dept_id),

    CONSTRAINT fk_ams_emp
        FOREIGN KEY (emp_id)  REFERENCES employees(emp_id)   ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ams_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 15 ▸ OVERTIME REQUESTS
-- ============================================================
CREATE TABLE overtime_requests (
    ot_id           INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    ot_date         DATE                NOT NULL,
    ot_hours        DECIMAL(4,2)        NOT NULL,
    reason          VARCHAR(255),
    submitted_date  DATE                NOT NULL,
    approver_emp_id INT UNSIGNED,
    status          ENUM('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending',
    notes           TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (ot_id),
    INDEX idx_ot_emp    (emp_id),
    INDEX idx_ot_status (status),
    INDEX idx_ot_date   (ot_date),

    CONSTRAINT fk_ot_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ot_dept
        FOREIGN KEY (dept_id)         REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ot_approver
        FOREIGN KEY (approver_emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 16 ▸ LEAVE MANAGEMENT
-- ── 16a. leave_types ─────────────────────────────────────────
-- ============================================================
CREATE TABLE leave_types (
    lt_id           TINYINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    type_name       VARCHAR(80)         NOT NULL,
    days_per_year   TINYINT UNSIGNED,                           -- NULL = unlimited / case-by-case
    carryover_days  TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    is_paid         TINYINT(1)          NOT NULL DEFAULT 1,
    needs_approval  TINYINT(1)          NOT NULL DEFAULT 1,
    is_active       TINYINT(1)          NOT NULL DEFAULT 1,

    PRIMARY KEY (lt_id),
    UNIQUE KEY uk_lt_name (type_name)
);

INSERT INTO leave_types (type_name, days_per_year, carryover_days, is_paid, needs_approval) VALUES
('Annual Leave',       20, 5, 1, 1),
('Sick Leave',         10, 0, 1, 0),
('Maternity Leave',    90, 0, 1, 1),
('Paternity Leave',    14, 0, 1, 1),
('Bereavement Leave',   5, 0, 1, 1),
('Unpaid Leave',     NULL, 0, 0, 1),
('Study / Exam Leave',  5, 0, 1, 1),
('Public Holiday',     12, 0, 1, 0);


-- ── 16b. leave_entitlements ──────────────────────────────────
-- Per-employee, per-year leave balance.
-- One row per (employee × leave_type × year).
-- ============================================================
CREATE TABLE leave_entitlements (
    entitle_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    lt_id           TINYINT UNSIGNED    NOT NULL,
    leave_year      SMALLINT UNSIGNED   NOT NULL,               -- e.g. 2026
    total_days      DECIMAL(5,1)        NOT NULL DEFAULT 0,
    used_days       DECIMAL(5,1)        NOT NULL DEFAULT 0,
    carried_over    DECIMAL(5,1)        NOT NULL DEFAULT 0,

    PRIMARY KEY (entitle_id),
    UNIQUE  KEY uk_le_emp_type_year (emp_id, lt_id, leave_year), -- One entitlement per type per year
    INDEX       idx_le_emp   (emp_id),
    INDEX       idx_le_year  (leave_year),

    CONSTRAINT fk_le_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id)    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_le_type
        FOREIGN KEY (lt_id)  REFERENCES leave_types(lt_id)   ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ── 16c. leave_requests ──────────────────────────────────────
CREATE TABLE leave_requests (
    request_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    lt_id           TINYINT UNSIGNED    NOT NULL,
    from_date       DATE                NOT NULL,
    to_date         DATE                NOT NULL,
    days_requested  DECIMAL(5,1)        NOT NULL,
    reason          VARCHAR(255),
    approver_emp_id INT UNSIGNED,
    status          ENUM('Pending','Approved','Rejected','Cancelled') NOT NULL DEFAULT 'Pending',
    notes           TEXT,
    submitted_at    TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at     DATETIME,

    PRIMARY KEY (request_id),
    INDEX idx_lr_emp      (emp_id),
    INDEX idx_lr_status   (status),
    INDEX idx_lr_from     (from_date),                          -- Calendar / overlap checks
    INDEX idx_lr_approver (approver_emp_id),

    CONSTRAINT fk_lr_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_lr_type
        FOREIGN KEY (lt_id)           REFERENCES leave_types(lt_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lr_approver
        FOREIGN KEY (approver_emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 17 ▸ BENEFITS — MEDICAL CLAIMS
-- ============================================================
CREATE TABLE medical_claims (
    claim_id        INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    category        ENUM('Doctor Visit','Specialist','Prescription','Dental','Vision','Hospital','Other')
                                        NOT NULL DEFAULT 'Doctor Visit',
    amount          DECIMAL(14,2)       NOT NULL,
    receipt_number  VARCHAR(80),
    receipt_path    VARCHAR(500),                               -- Scanned receipt file
    submitted_date  DATE                NOT NULL,
    approver_emp_id INT UNSIGNED,
    status          ENUM('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending',
    notes           TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (claim_id),
    INDEX idx_mc_emp    (emp_id),
    INDEX idx_mc_status (status),
    INDEX idx_mc_date   (submitted_date),

    CONSTRAINT fk_mc_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mc_dept
        FOREIGN KEY (dept_id)         REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_mc_approver
        FOREIGN KEY (approver_emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 18 ▸ TRAINING & DEVELOPMENT
-- ── 18a. training_needs_analysis (TNA) ───────────────────────
-- ============================================================
CREATE TABLE training_needs_analysis (
    tna_id          INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    dept_id         SMALLINT UNSIGNED,
    skill_gap       VARCHAR(200)        NOT NULL,               -- 'Leadership', 'Excel Advanced' …
    priority        ENUM('High','Medium','Low') NOT NULL DEFAULT 'Medium',
    affected_count  SMALLINT UNSIGNED,                          -- How many employees affected
    proposed_method ENUM('Workshop','Online Course','Mentoring','Certification','Conference','Other')
                                        NOT NULL DEFAULT 'Workshop',
    status          ENUM('Pending','Approved','Ongoing','Completed') NOT NULL DEFAULT 'Pending',
    submitted_by    INT UNSIGNED,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (tna_id),
    INDEX idx_tna_dept     (dept_id),
    INDEX idx_tna_priority (priority),
    INDEX idx_tna_status   (status),

    CONSTRAINT fk_tna_dept
        FOREIGN KEY (dept_id)      REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tna_submitter
        FOREIGN KEY (submitted_by) REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 18b. training_sessions ───────────────────────────────────
CREATE TABLE training_sessions (
    session_id      INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    course_name     VARCHAR(200)        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    trainer_emp_id  INT UNSIGNED,                               -- Internal trainer (NULL = external)
    trainer_name    VARCHAR(150),                               -- External trainer name if applicable
    session_date    DATE                NOT NULL,
    session_time    TIME,
    venue           VARCHAR(150),
    total_seats     TINYINT UNSIGNED,
    enrolled_count  TINYINT UNSIGNED    NOT NULL DEFAULT 0,
    status          ENUM('Open','Confirmed','Completed','Cancelled') NOT NULL DEFAULT 'Open',
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (session_id),
    INDEX idx_ts_dept   (dept_id),
    INDEX idx_ts_date   (session_date),
    INDEX idx_ts_status (status),

    CONSTRAINT fk_ts_dept
        FOREIGN KEY (dept_id)        REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ts_trainer
        FOREIGN KEY (trainer_emp_id) REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 18c. training_enrollments ────────────────────────────────
-- Resolves the Many-to-Many between employees and sessions.
CREATE TABLE training_enrollments (
    enroll_id       INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    session_id      INT UNSIGNED        NOT NULL,
    emp_id          INT UNSIGNED        NOT NULL,
    enrolled_at     TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed       TINYINT(1)          NOT NULL DEFAULT 0,
    score           DECIMAL(5,2),

    PRIMARY KEY (enroll_id),
    UNIQUE  KEY uk_enroll (session_id, emp_id),                 -- One enrollment per employee per session
    INDEX       idx_enroll_emp (emp_id),

    CONSTRAINT fk_enroll_session
        FOREIGN KEY (session_id) REFERENCES training_sessions(session_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_enroll_emp
        FOREIGN KEY (emp_id)     REFERENCES employees(emp_id)             ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 19 ▸ PERFORMANCE REVIEWS
-- ============================================================
CREATE TABLE performance_reviews (
    review_id       INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    reviewer_emp_id INT UNSIGNED,
    review_period   VARCHAR(20)         NOT NULL,               -- 'Q1 2026', 'Annual 2025' …
    overall_score   DECIMAL(4,2),                               -- 0.00 – 10.00
    rating          ENUM('Exceptional','Exceeds Expectations','Meets Expectations','Below Expectations','Unsatisfactory')
                                        NOT NULL DEFAULT 'Meets Expectations',
    strengths       TEXT,
    improvements    TEXT,
    goals_next      TEXT,
    status          ENUM('Pending','Submitted','Acknowledged') NOT NULL DEFAULT 'Pending',
    submitted_at    DATETIME,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (review_id),
    INDEX idx_pr_emp      (emp_id),
    INDEX idx_pr_reviewer (reviewer_emp_id),
    INDEX idx_pr_period   (review_period),
    INDEX idx_pr_status   (status),

    CONSTRAINT fk_pr_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pr_reviewer
        FOREIGN KEY (reviewer_emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 20 ▸ 360° FEEDBACK
-- subject_emp = person being evaluated; respondent_emp = person giving feedback
-- ============================================================
CREATE TABLE feedback_360 (
    feedback_id         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    subject_emp_id      INT UNSIGNED    NOT NULL,               -- Employee being evaluated
    respondent_emp_id   INT UNSIGNED    NOT NULL,               -- Employee giving feedback
    relationship_type   ENUM('Self','Peer','Manager','Subordinate','External')
                                        NOT NULL DEFAULT 'Peer',
    review_cycle        VARCHAR(20)     NOT NULL,               -- 'Q1 2026' etc.
    score               DECIMAL(4,2),
    comments            TEXT,
    status              ENUM('Pending','Submitted','Closed') NOT NULL DEFAULT 'Pending',
    submitted_at        DATETIME,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (feedback_id),
    UNIQUE  KEY uk_f360_pair_cycle (subject_emp_id, respondent_emp_id, review_cycle),
    INDEX       idx_f360_subject    (subject_emp_id),
    INDEX       idx_f360_respondent (respondent_emp_id),

    CONSTRAINT fk_f360_subject
        FOREIGN KEY (subject_emp_id)    REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_f360_respondent
        FOREIGN KEY (respondent_emp_id) REFERENCES employees(emp_id) ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 21 ▸ EMPLOYEE MOVEMENT
-- ── 21a. promotions_demotions ────────────────────────────────
-- Full history — each change is a new row, never updated.
-- ============================================================
CREATE TABLE promotions_demotions (
    change_id           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    emp_id              INT UNSIGNED    NOT NULL,
    change_type         ENUM('Promotion','Demotion','Lateral Transfer','Grade Adjustment')
                                        NOT NULL DEFAULT 'Promotion',
    from_position_id    SMALLINT UNSIGNED,
    to_position_id      SMALLINT UNSIGNED,
    from_dept_id        SMALLINT UNSIGNED,
    to_dept_id          SMALLINT UNSIGNED,
    from_salary         DECIMAL(14,2),
    to_salary           DECIMAL(14,2),
    effective_date      DATE            NOT NULL,
    approved_by         INT UNSIGNED,
    status              ENUM('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending',
    reason              TEXT,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (change_id),
    INDEX idx_pd_emp    (emp_id),
    INDEX idx_pd_status (status),
    INDEX idx_pd_date   (effective_date),

    CONSTRAINT fk_pd_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id)     ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pd_from_pos
        FOREIGN KEY (from_position_id) REFERENCES job_positions(position_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_pd_to_pos
        FOREIGN KEY (to_position_id)   REFERENCES job_positions(position_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_pd_approver
        FOREIGN KEY (approved_by)      REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 21b. department_transfers ────────────────────────────────
CREATE TABLE department_transfers (
    transfer_id     INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    from_dept_id    SMALLINT UNSIGNED,
    to_dept_id      SMALLINT UNSIGNED,
    from_branch_id  SMALLINT UNSIGNED,
    to_branch_id    SMALLINT UNSIGNED,
    request_date    DATE                NOT NULL,
    effective_date  DATE,
    approved_by     INT UNSIGNED,
    status          ENUM('Pending','Approved','Rejected','Completed') NOT NULL DEFAULT 'Pending',
    reason          TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (transfer_id),
    INDEX idx_tr_emp    (emp_id),
    INDEX idx_tr_status (status),
    INDEX idx_tr_date   (effective_date),

    CONSTRAINT fk_tr_emp
        FOREIGN KEY (emp_id)          REFERENCES employees(emp_id)     ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tr_from_dept
        FOREIGN KEY (from_dept_id)    REFERENCES departments(dept_id)  ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tr_to_dept
        FOREIGN KEY (to_dept_id)      REFERENCES departments(dept_id)  ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tr_from_branch
        FOREIGN KEY (from_branch_id)  REFERENCES branches(branch_id)  ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tr_to_branch
        FOREIGN KEY (to_branch_id)    REFERENCES branches(branch_id)  ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_tr_approver
        FOREIGN KEY (approved_by)     REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 22 ▸ COMPLIANCE & EXIT
-- ── 22a. disciplinary_actions ────────────────────────────────
-- ============================================================
CREATE TABLE disciplinary_actions (
    da_id           INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    action_type     ENUM('Verbal Warning','Written Warning','Final Warning','Suspension','Demotion','Dismissal')
                                        NOT NULL,
    incident_date   DATE                NOT NULL,
    issued_date     DATE                NOT NULL,
    issued_by       INT UNSIGNED,
    description     TEXT                NOT NULL,
    employee_response TEXT,                                     -- Employee's signed acknowledgement
    document_path   VARCHAR(500),                               -- Signed warning letter file
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (da_id),
    INDEX idx_da_emp    (emp_id),
    INDEX idx_da_type   (action_type),
    INDEX idx_da_issued (issued_date),

    CONSTRAINT fk_da_emp
        FOREIGN KEY (emp_id)    REFERENCES employees(emp_id)    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_da_dept
        FOREIGN KEY (dept_id)   REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_da_issuer
        FOREIGN KEY (issued_by) REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 22b. resignations ────────────────────────────────────────
CREATE TABLE resignations (
    resign_id       INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    dept_id         SMALLINT UNSIGNED,
    reason_category ENUM('Harassment','Unfair Treatment','Pay Dispute','Safety Concern',
                         'Discrimination','Work Conditions','Personal','Career Growth','Other')
                                        NOT NULL DEFAULT 'Personal',
    details         TEXT,
    filed_date      DATE                NOT NULL,
    last_working_day DATE,
    assigned_to     INT UNSIGNED,                               -- HR officer handling this
    priority        ENUM('High','Medium','Low') NOT NULL DEFAULT 'Medium',
    status          ENUM('Pending','Under Review','Resolved','Escalated') NOT NULL DEFAULT 'Pending',
    resolution_notes TEXT,
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (resign_id),
    INDEX idx_res_emp      (emp_id),
    INDEX idx_res_status   (status),
    INDEX idx_res_priority (priority),

    CONSTRAINT fk_res_emp
        FOREIGN KEY (emp_id)       REFERENCES employees(emp_id)    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_res_dept
        FOREIGN KEY (dept_id)      REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_res_assigned
        FOREIGN KEY (assigned_to)  REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 22c. separations (Termination / Exit) ────────────────────
CREATE TABLE separations (
    sep_id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    emp_id              INT UNSIGNED    NOT NULL,
    dept_id             SMALLINT UNSIGNED,
    separation_type     ENUM('Resignation','Involuntary Termination','Retirement',
                             'End of Contract','Abandonment','Deceased')
                                        NOT NULL,
    notice_date         DATE,
    last_working_day    DATE            NOT NULL,
    final_settlement    DECIMAL(14,2),
    status              ENUM('In Progress','Complete') NOT NULL DEFAULT 'In Progress',
    initiated_by        INT UNSIGNED,
    notes               TEXT,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (sep_id),
    UNIQUE  KEY uk_sep_emp  (emp_id),                           -- One separation record per employee
    INDEX       idx_sep_type (separation_type),
    INDEX       idx_sep_last (last_working_day),

    CONSTRAINT fk_sep_emp
        FOREIGN KEY (emp_id)        REFERENCES employees(emp_id)    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sep_dept
        FOREIGN KEY (dept_id)       REFERENCES departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_sep_initiator
        FOREIGN KEY (initiated_by)  REFERENCES employees(emp_id)    ON DELETE SET NULL ON UPDATE CASCADE
);


-- ── 22d. exit_clearance ──────────────────────────────────────
-- Tracks department sign-offs during the offboarding process.
-- One header row + one child row per clearance department.
-- ============================================================
CREATE TABLE exit_clearance (
    clearance_id    INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED        NOT NULL,
    sep_id          INT UNSIGNED        NOT NULL,
    it_cleared      TINYINT(1)          NOT NULL DEFAULT 0,
    finance_cleared TINYINT(1)          NOT NULL DEFAULT 0,
    hr_cleared      TINYINT(1)          NOT NULL DEFAULT 0,
    admin_cleared   TINYINT(1)          NOT NULL DEFAULT 0,
    assets_cleared  TINYINT(1)          NOT NULL DEFAULT 0,     -- All assets returned?
    overall_status  ENUM('In Progress','Cleared') NOT NULL DEFAULT 'In Progress',
    completed_at    DATETIME,
    notes           TEXT,

    PRIMARY KEY (clearance_id),
    UNIQUE  KEY uk_clr_emp    (emp_id),
    INDEX       idx_clr_sep   (sep_id),
    INDEX       idx_clr_status(overall_status),

    CONSTRAINT fk_clr_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id)   ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_clr_sep
        FOREIGN KEY (sep_id) REFERENCES separations(sep_id) ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 23 ▸ SYSTEM ADMIN — USER MANAGEMENT
-- System login accounts (separate from employees).
-- An employee can have a user account, but not all employees do.
-- ============================================================
CREATE TABLE system_users (
    user_id         INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    emp_id          INT UNSIGNED,                               -- Linked employee (nullable for service accounts)
    username        VARCHAR(60)         NOT NULL,
    email           VARCHAR(150)        NOT NULL,
    password_hash   VARCHAR(255)        NOT NULL,               -- bcrypt / argon2 hash — NEVER store plain text
    last_login_at   DATETIME,
    status          ENUM('Active','Inactive','Locked') NOT NULL DEFAULT 'Active',
    created_at      TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    UNIQUE  KEY uk_user_username (username),
    UNIQUE  KEY uk_user_email    (email),
    INDEX       idx_user_emp     (emp_id),
    INDEX       idx_user_status  (status),

    CONSTRAINT fk_user_emp
        FOREIGN KEY (emp_id) REFERENCES employees(emp_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Tracks failed login attempts per user (for rate-limiting / lockout)
CREATE TABLE IF NOT EXISTS login_attempts (
    user_id         INT UNSIGNED    NOT NULL,
    attempt_count   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    last_attempt_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    CONSTRAINT fk_attempt_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Stores "remember me" tokens (hashed SHA-256) for persistent sessions
CREATE TABLE IF NOT EXISTS remember_tokens (
    token_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    user_id     INT UNSIGNED    NOT NULL,
    token_hash  CHAR(64)        NOT NULL,   -- SHA-256 hex = always 64 chars
    expires_at  DATETIME        NOT NULL,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (token_id),
    UNIQUE  KEY uk_token_hash (token_hash),
    INDEX       idx_rt_user   (user_id),
    INDEX       idx_rt_expiry (expires_at),

    CONSTRAINT fk_rt_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);
 

-- ============================================================
-- PAGE 24 ▸ ROLES & PERMISSIONS
-- ── 24a. roles ───────────────────────────────────────────────
-- ============================================================
CREATE TABLE roles (
    role_id         TINYINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    role_name       VARCHAR(60)         NOT NULL,
    description     VARCHAR(255),
    is_system_role  TINYINT(1)          NOT NULL DEFAULT 0,     -- 1 = cannot be deleted

    PRIMARY KEY (role_id),
    UNIQUE KEY uk_role_name (role_name)
);

INSERT INTO roles (role_name, description, is_system_role) VALUES
('Super Admin',        'Full system authority — all modules visible and editable', 1),
('HRM User',           'Standard HR operations access',                            0),
('Department Manager', 'Limited to own department data only',                      0);


-- ── 24b. user_roles ──────────────────────────────────────────
-- Links system_users to roles (Many-to-Many).
CREATE TABLE user_roles (
    user_id INT UNSIGNED     NOT NULL,
    role_id TINYINT UNSIGNED NOT NULL,
    assigned_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id, role_id),

    CONSTRAINT fk_ur_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ur_role
        FOREIGN KEY (role_id) REFERENCES roles(role_id)         ON DELETE CASCADE ON UPDATE CASCADE
);


-- ── 24c. modules ─────────────────────────────────────────────
-- Master list of all navigable modules in the app.
-- Matches the sidebar navigation structure exactly.
-- ============================================================
CREATE TABLE modules (
    module_id       TINYINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    module_key      VARCHAR(60)         NOT NULL,               -- 'm-org', 'm-emp' … matches sidebar IDs
    module_name     VARCHAR(100)        NOT NULL,
    parent_id       TINYINT UNSIGNED,                           -- NULL = top-level group
    sort_order      TINYINT UNSIGNED    NOT NULL DEFAULT 0,

    PRIMARY KEY (module_id),
    UNIQUE  KEY uk_module_key  (module_key),
    INDEX       idx_mod_parent (parent_id),

    CONSTRAINT fk_mod_parent
        FOREIGN KEY (parent_id) REFERENCES modules(module_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Seed modules (groups + their sub-pages)
INSERT INTO modules (module_key, module_name, parent_id, sort_order) VALUES
-- Top-level groups
('m-org',   'Company & Structure',  NULL, 1),
('m-emp',   'Employees',            NULL, 2),
('m-rec',   'Talent Acquisition',   NULL, 3),
('m-move',  'Employee Movement',    NULL, 4),
('m-att',   'Attendance',           NULL, 5),
('m-leave', 'Leave Management',     NULL, 6),
('m-ben',   'Benefits',             NULL, 7),
('m-comp',  'Compliance & Exit',    NULL, 8),
('m-train', 'Training & Dev',       NULL, 9),
('m-perf',  'Performance',          NULL, 10),
('m-rep',   'Reports & Analytics',  NULL, 11),
('m-sys',   'System Admin',         NULL, 12);

-- Sub-pages inserted after we know parent IDs (use subquery to get parent_id)
INSERT INTO modules (module_key, module_name, parent_id, sort_order)
SELECT 'company-profile',    'Company Profile',          module_id, 1 FROM modules WHERE module_key='m-org' UNION ALL
SELECT 'org-chart',          'Organization Chart',       module_id, 2 FROM modules WHERE module_key='m-org' UNION ALL
SELECT 'departments',        'Departments',              module_id, 3 FROM modules WHERE module_key='m-org' UNION ALL
SELECT 'job-positions',      'Job Positions',            module_id, 4 FROM modules WHERE module_key='m-org' UNION ALL
SELECT 'branch-offices',     'Branch Offices',           module_id, 5 FROM modules WHERE module_key='m-org' UNION ALL
SELECT 'employee-directory', 'Employee Profile',         module_id, 1 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'employment-types',   'Employment Types',         module_id, 2 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'probation-tracker',  'Probation Tracker',        module_id, 3 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'contract-renewals',  'Contract Renewals',        module_id, 4 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'document-vault',     'Attachment Vault',         module_id, 5 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'asset-tracking',     'Asset Tracking',           module_id, 6 FROM modules WHERE module_key='m-emp' UNION ALL
SELECT 'job-vacancies',      'Add Job Vacancies',        module_id, 1 FROM modules WHERE module_key='m-rec' UNION ALL
SELECT 'candidates',         'Job Applicant List',       module_id, 2 FROM modules WHERE module_key='m-rec' UNION ALL
SELECT 'interview-tracker',  'Interview Tracker',        module_id, 3 FROM modules WHERE module_key='m-rec' UNION ALL
SELECT 'internship',         'Internship Management',    module_id, 4 FROM modules WHERE module_key='m-rec' UNION ALL
SELECT 'Promote/Demote',     'Promote / Demote',         module_id, 1 FROM modules WHERE module_key='m-move' UNION ALL
SELECT 'transfers',          'Department Transfers',     module_id, 2 FROM modules WHERE module_key='m-move' UNION ALL
SELECT 'attendance',         'Record Attendance',        module_id, 1 FROM modules WHERE module_key='m-att' UNION ALL
SELECT 'daily-attendance',   'Daily Attendance',         module_id, 2 FROM modules WHERE module_key='m-att' UNION ALL
SELECT 'attendance-reports', 'Attendance Reports',       module_id, 3 FROM modules WHERE module_key='m-att' UNION ALL
SELECT 'leave-types',        'Leave Types',              module_id, 1 FROM modules WHERE module_key='m-leave' UNION ALL
SELECT 'leave-requests',     'Leave Requests',           module_id, 2 FROM modules WHERE module_key='m-leave' UNION ALL
SELECT 'leave-entitlement',  'Leave Entitlement',        module_id, 3 FROM modules WHERE module_key='m-leave' UNION ALL
SELECT 'medical-claims',     'Medical Claims',           module_id, 1 FROM modules WHERE module_key='m-ben' UNION ALL
SELECT 'overtime-requests',  'Overtime Requests',        module_id, 2 FROM modules WHERE module_key='m-ben' UNION ALL
SELECT 'disciplinary-actions','Disciplinary Actions',    module_id, 1 FROM modules WHERE module_key='m-comp' UNION ALL
SELECT 'resignations',       'Resignations',             module_id, 2 FROM modules WHERE module_key='m-comp' UNION ALL
SELECT 'termination',        'Separation & Exit',        module_id, 3 FROM modules WHERE module_key='m-comp' UNION ALL
SELECT 'exit-clearance',     'Exit Clearance',           module_id, 4 FROM modules WHERE module_key='m-comp' UNION ALL
SELECT 'training-needs',     'Training Needs Analysis',  module_id, 1 FROM modules WHERE module_key='m-train' UNION ALL
SELECT 'training-schedule',  'Training Schedule',        module_id, 2 FROM modules WHERE module_key='m-train' UNION ALL
SELECT 'performance-reviews','Performance Reviews',      module_id, 1 FROM modules WHERE module_key='m-perf' UNION ALL
SELECT '360-feedback',       '360° Feedback',            module_id, 2 FROM modules WHERE module_key='m-perf' UNION ALL
SELECT 'hr-analytics',       'HR Analytics',             module_id, 1 FROM modules WHERE module_key='m-rep' UNION ALL
SELECT 'custom-reports',     'Custom Reports',           module_id, 2 FROM modules WHERE module_key='m-rep' UNION ALL
SELECT 'user-management',    'User Management',          module_id, 1 FROM modules WHERE module_key='m-sys' UNION ALL
SELECT 'roles-permissions',  'Roles & Permissions',      module_id, 2 FROM modules WHERE module_key='m-sys' UNION ALL
SELECT 'audit-logs',         'Audit Logs',               module_id, 3 FROM modules WHERE module_key='m-sys';


-- ── 24d. role_permissions ────────────────────────────────────
-- Defines which modules each ROLE can see (standard access control).
CREATE TABLE role_permissions (
    rp_id       INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    role_id     TINYINT UNSIGNED    NOT NULL,
    module_id   TINYINT UNSIGNED    NOT NULL,
    can_view    TINYINT(1)          NOT NULL DEFAULT 1,
    can_create  TINYINT(1)          NOT NULL DEFAULT 0,
    can_edit    TINYINT(1)          NOT NULL DEFAULT 0,
    can_delete  TINYINT(1)          NOT NULL DEFAULT 0,

    PRIMARY KEY (rp_id),
    UNIQUE  KEY uk_rp (role_id, module_id),
    INDEX       idx_rp_role   (role_id),
    INDEX       idx_rp_module (module_id),

    CONSTRAINT fk_rp_role
        FOREIGN KEY (role_id)   REFERENCES roles(role_id)     ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rp_module
        FOREIGN KEY (module_id) REFERENCES modules(module_id) ON DELETE CASCADE ON UPDATE CASCADE
);


-- ── 24e. user_permission_overrides ───────────────────────────
-- Individual-level overrides (the "Individual Roles" mode in the UI).
-- A row here beats the role_permissions entry for that user+module.
CREATE TABLE user_permission_overrides (
    override_id INT UNSIGNED        NOT NULL AUTO_INCREMENT,
    user_id     INT UNSIGNED        NOT NULL,
    module_id   TINYINT UNSIGNED    NOT NULL,
    can_view    TINYINT(1)          NOT NULL DEFAULT 1,
    can_create  TINYINT(1)          NOT NULL DEFAULT 0,
    can_edit    TINYINT(1)          NOT NULL DEFAULT 0,
    can_delete  TINYINT(1)          NOT NULL DEFAULT 0,
    updated_at  TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (override_id),
    UNIQUE  KEY uk_upo (user_id, module_id),
    INDEX       idx_upo_user   (user_id),
    INDEX       idx_upo_module (module_id),

    CONSTRAINT fk_upo_user
        FOREIGN KEY (user_id)   REFERENCES system_users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_upo_module
        FOREIGN KEY (module_id) REFERENCES modules(module_id)    ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- PAGE 25 ▸ AUDIT LOGS
-- Immutable ledger — no UPDATE or DELETE should ever run on this.
-- Partitioned by year in production for performance.
-- ============================================================
CREATE TABLE audit_logs (
    log_id          BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT,
    user_id         INT UNSIGNED,                               -- NULL if system-generated
    action          ENUM('CREATE','UPDATE','DELETE','LOGIN','LOGOUT','APPROVE','REJECT','EXPORT')
                                        NOT NULL,
    module          VARCHAR(60),                                -- Which page/module
    record_id       VARCHAR(60),                                -- PK of the affected record (stored as string)
    old_value       JSON,                                       -- Previous state (UPDATE/DELETE)
    new_value       JSON,                                       -- New state (CREATE/UPDATE)
    ip_address      VARCHAR(45),                                -- IPv4 or IPv6
    user_agent      VARCHAR(300),
    logged_at       TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (log_id),
    INDEX idx_audit_user   (user_id),
    INDEX idx_audit_action (action),
    INDEX idx_audit_module (module),
    INDEX idx_audit_time   (logged_at),                         -- Date-range queries on the log page

    CONSTRAINT fk_audit_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- ============================================================
-- UTILITY VIEW ▸ v_employee_full
-- A pre-joined view used by most list pages.
-- Avoids writing the same 6-table JOIN everywhere.
-- ============================================================
CREATE OR REPLACE VIEW v_employee_full AS
SELECT
    e.emp_id,
    e.emp_code,
    CONCAT(e.first_name, ' ', COALESCE(e.middle_name,''), ' ', e.last_name) AS full_name,
    e.first_name,
    e.middle_name,
    e.last_name,
    e.gender,
    e.date_of_birth,
    e.hire_date,
    e.contract_end_date,
    e.probation_end_date,
    e.status                        AS emp_status,
    e.gross_salary,
    e.personal_phone,
    e.personal_email,
    d.dept_name,
    jp.title                        AS job_title,
    b.branch_name,
    et.type_name                    AS employment_type,
    CONCAT(m.first_name,' ',m.last_name) AS manager_name
FROM       employees       e
LEFT JOIN  departments     d  ON e.dept_id         = d.dept_id
LEFT JOIN  job_positions   jp ON e.position_id     = jp.position_id
LEFT JOIN  branches        b  ON e.branch_id       = b.branch_id
LEFT JOIN  employment_types et ON e.type_id        = et.type_id
LEFT JOIN  employees       m  ON e.reports_to_emp_id = m.emp_id;


-- ============================================================
-- UTILITY VIEW ▸ v_vault_compliance
-- Shows how many documents each employee has uploaded vs required.
-- Powers the compliance dashboard cards and the vault matrix.
-- ============================================================
CREATE OR REPLACE VIEW v_vault_compliance AS
SELECT
    e.emp_id,
    e.emp_code,
    CONCAT(e.first_name,' ',e.last_name)            AS full_name,
    d.dept_name,
    COUNT(vdt.doc_type_id)                          AS total_required,
    SUM(CASE WHEN ed.status = 'Uploaded' THEN 1 ELSE 0 END) AS uploaded_count,
    SUM(CASE WHEN ed.status = 'Missing'  THEN 1 ELSE 0 END) AS missing_count,
    ROUND(
        SUM(CASE WHEN ed.status = 'Uploaded' THEN 1 ELSE 0 END)
        / COUNT(vdt.doc_type_id) * 100, 1
    )                                               AS compliance_pct
FROM       employees           e
LEFT JOIN  departments         d   ON e.dept_id     = d.dept_id
CROSS JOIN vault_document_types vdt                             -- All required docs
LEFT JOIN  employee_documents  ed  ON ed.emp_id     = e.emp_id
                                  AND ed.doc_type_id = vdt.doc_type_id
WHERE vdt.is_mandatory = 1
  AND vdt.is_active    = 1
  AND e.status         = 'Active'
GROUP BY e.emp_id, e.emp_code, full_name, d.dept_name;


-- ============================================================
-- UTILITY VIEW ▸ v_contract_alerts
-- Employees whose contracts expire within the next 30 days.
-- Used by the Dashboard "Expiring contracts" stat card.
-- ============================================================
CREATE OR REPLACE VIEW v_contract_alerts AS
SELECT
    e.emp_id,
    e.emp_code,
    CONCAT(e.first_name,' ',e.last_name)    AS full_name,
    d.dept_name,
    e.contract_end_date,
    DATEDIFF(e.contract_end_date, CURDATE()) AS days_remaining
FROM  employees   e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.status             = 'Active'
  AND e.contract_end_date  IS NOT NULL
  AND e.contract_end_date  BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)
ORDER BY days_remaining ASC;


-- ============================================================
-- UTILITY VIEW ▸ v_probation_alerts
-- Employees whose probation ends within 14 days.
-- ============================================================
CREATE OR REPLACE VIEW v_probation_alerts AS
SELECT
    e.emp_id,
    CONCAT(e.first_name,' ',e.last_name)    AS full_name,
    d.dept_name,
    p.probation_end,
    DATEDIFF(p.probation_end, CURDATE())    AS days_remaining,
    p.status                                AS prob_status
FROM  probation_records p
JOIN  employees         e ON p.emp_id   = e.emp_id
LEFT JOIN departments   d ON e.dept_id  = d.dept_id
WHERE p.status       = 'Active'
  AND p.probation_end BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 14 DAY)
ORDER BY days_remaining ASC;


-- ============================================================
-- RE-ENABLE FK CHECKS
-- ============================================================
SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
-- QUICK-REFERENCE: TABLE MAP BY UI PAGE
-- ──────────────────────────────────────────────────────────
-- Dashboard            → v_employee_full, v_contract_alerts,
--                         v_probation_alerts, v_vault_compliance
-- Company Profile      → company_profile
-- Org Chart            → departments, job_positions, employees (view)
-- Departments          → departments  + branches + employees (head)
-- Job Positions        → job_positions + departments
-- Branch Offices       → branches + employees (manager)
-- Employee Profile     → employees + all lookup tables + v_employee_full
-- Add Employee         → employees INSERT (6-step wizard maps to 5 sections)
-- Employment Types     → employment_types
-- Probation Tracker    → probation_records + v_probation_alerts
-- Contract Renewals    → contract_renewals + v_contract_alerts
-- Former Employees     → former_employees + employees (history)
-- Attachment Vault     → employee_documents + vault_document_types
--                         + v_vault_compliance
-- Asset Tracking       → assets + asset_categories
--                         + asset_assignment_history
-- Job Vacancies        → job_vacancies
-- Job Applicants       → job_applicants + job_vacancies
-- Interview Tracker    → interviews + job_applicants
-- Internship           → interns + departments + employees (mentor)
-- Record Attendance    → attendance_records
-- Daily Attendance     → attendance_records (filtered by date)
-- Attendance Reports   → attendance_monthly_summary
-- Leave Types          → leave_types
-- Leave Requests       → leave_requests + leave_types + employees
-- Leave Entitlement    → leave_entitlements
-- Medical Claims       → medical_claims
-- Overtime Requests    → overtime_requests
-- Training TNA         → training_needs_analysis
-- Training Schedule    → training_sessions + training_enrollments
-- Performance Reviews  → performance_reviews
-- 360° Feedback        → feedback_360
-- Promote/Demote       → promotions_demotions
-- Dept Transfers       → department_transfers
-- Disciplinary         → disciplinary_actions
-- Resignations         → resignations
-- Separation & Exit    → separations
-- Exit Clearance       → exit_clearance
-- HR Analytics         → Multiple aggregate queries on above tables
-- Custom Reports       → Ad-hoc queries — no dedicated table needed
-- User Management      → system_users + user_roles
-- Roles & Permissions  → roles + modules + role_permissions
--                         + user_permission_overrides
-- Audit Logs           → audit_logs
-- ============================================================
