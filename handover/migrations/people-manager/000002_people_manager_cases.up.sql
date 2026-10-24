-- People Manager: guidance, manager requests and HR case management.
-- Prefixes: PM (manager request), ER (case), PC/DL (issued disciplinary letter).

CREATE TABLE guidance_topics (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(150) NOT NULL,
    topic_group  VARCHAR(50),
    policy_ref   VARCHAR(255),
    steps        JSONB        NOT NULL DEFAULT '[]',
    forms        JSONB        NOT NULL DEFAULT '[]',
    reviewed_on  DATE,
    views        INT          NOT NULL DEFAULT 0,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE er_case_types (
    case_type  VARCHAR(30) PRIMARY KEY,   -- disciplinary, grievance_formal, grievance_informal, performance, sexual_harassment
    label      VARCHAR(60) NOT NULL,
    timebound  BOOLEAN     NOT NULL,
    steps      JSONB       NOT NULL,      -- [{"label":"Issue show cause letter","days":5}, ...] working days from opening
    updated_by VARCHAR(255),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (case_type NOT IN ('sexual_harassment','grievance_formal') OR timebound)
);
INSERT INTO er_case_types (case_type, label, timebound, steps, updated_by) VALUES   -- sample values: set per policy
 ('disciplinary','Disciplinary',TRUE,'[{"label":"Issue show cause letter","days":5},{"label":"Employee reply due","days":8},{"label":"Complete investigation","days":20},{"label":"Decision issued","days":30}]','seed'),
 ('grievance_formal','Grievance (formal)',TRUE,'[{"label":"Acknowledge","days":2},{"label":"Complete investigation","days":10},{"label":"Outcome issued","days":20}]','seed'),
 ('grievance_informal','Grievance (informal)',FALSE,'[{"label":"Acknowledge","days":3},{"label":"Outcome issued","days":15}]','seed'),
 ('performance','Performance',FALSE,'[{"label":"Improvement plan agreed","days":10},{"label":"Review","days":40}]','seed'),
 ('sexual_harassment','Sexual harassment',TRUE,'[{"label":"Acknowledge","days":1},{"label":"Complete investigation","days":7},{"label":"Outcome issued","days":15}]','seed');

CREATE TABLE manager_requests (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference            VARCHAR(30)  NOT NULL UNIQUE,   -- next_reference('PM')
    kind                 VARCHAR(10)  NOT NULL CHECK (kind IN ('advice','report')),
    issue_type           VARCHAR(50),
    topic_id             UUID REFERENCES guidance_topics(id),
    manager_employee_id  VARCHAR(30)  NOT NULL,
    division             VARCHAR(100) NOT NULL,
    employee_involved    VARCHAR(255),
    urgency              VARCHAR(10)  NOT NULL DEFAULT 'normal' CHECK (urgency IN ('normal','urgent')),
    route_division_chief    BOOLEAN   NOT NULL DEFAULT FALSE,
    route_division_director BOOLEAN   NOT NULL DEFAULT FALSE,
    description          TEXT         NOT NULL,
    status               VARCHAR(20)  NOT NULL DEFAULT 'new' CHECK (status IN ('new','responded','case_opened','closed')),
    case_id              UUID,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (issue_type IS DISTINCT FROM 'Sexual harassment' OR (NOT route_division_chief AND NOT route_division_director))
);

CREATE TABLE manager_request_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID        NOT NULL REFERENCES manager_requests(id),
    author      VARCHAR(10) NOT NULL CHECK (author IN ('manager','hr')),
    body        TEXT        NOT NULL,
    created_by  VARCHAR(255),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE er_cases (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference           VARCHAR(30)  NOT NULL UNIQUE,    -- next_reference('ER'); migrated cases keep their number
    case_type           VARCHAR(30)  NOT NULL REFERENCES er_case_types(case_type),
    formal              BOOLEAN      NOT NULL DEFAULT TRUE,
    employee_id         VARCHAR(30)  NOT NULL,
    employee_name       VARCHAR(255) NOT NULL,
    division            VARCHAR(100) NOT NULL,
    grade               VARCHAR(10),
    source_type         VARCHAR(20)  NOT NULL CHECK (source_type IN ('manager','employee_voice','hr','internal_audit','migrated')),
    source_reference    VARCHAR(30),                     -- PM/… or EV/…
    summary             TEXT         NOT NULL,
    stage               VARCHAR(20)  NOT NULL DEFAULT 'intake'
                        CHECK (stage IN ('intake','investigation','show_cause','dg_committee','decision','closed')),
    route_division_chief    BOOLEAN  NOT NULL DEFAULT FALSE,
    route_division_director BOOLEAN  NOT NULL DEFAULT FALSE,
    dg_referred         BOOLEAN      NOT NULL DEFAULT FALSE,
    dg_hearing_date     DATE,
    dg_decision         VARCHAR(50),
    decision            VARCHAR(50)  CHECK (decision IN ('No action','Counselling','Verbal warning','Written warning','Final written warning','Suspension without pay','Demotion','Termination')),
    case_officer        VARCHAR(255),
    manager_employee_id VARCHAR(30),                     -- employee's line manager (Manager view: stage only)
    migrated            BOOLEAN      NOT NULL DEFAULT FALSE,
    opened_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    closed_at           TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (case_type <> 'sexual_harassment' OR (NOT route_division_chief AND NOT route_division_director)),
    CHECK (stage <> 'dg_committee' OR dg_referred)
);
ALTER TABLE manager_requests ADD CONSTRAINT fk_manager_requests_case FOREIGN KEY (case_id) REFERENCES er_cases(id);

CREATE TABLE er_case_step_completions (
    case_id      UUID        NOT NULL REFERENCES er_cases(id),
    step_index   INT         NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_by VARCHAR(255),
    PRIMARY KEY (case_id, step_index)
);

CREATE TABLE er_case_log (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id    UUID        NOT NULL REFERENCES er_cases(id),
    entry      TEXT        NOT NULL,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Disciplinary letters use templates with category 'disciplinary' from the Automation Bot library.
CREATE TABLE er_letters (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id          UUID         NOT NULL REFERENCES er_cases(id),
    template_code    VARCHAR(50)  NOT NULL,
    template_version INT          NOT NULL,
    body             TEXT         NOT NULL,
    status           VARCHAR(20)  NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','awaiting_check','issued')),
    drafted_by       VARCHAR(255) NOT NULL,
    checked_by       VARCHAR(255),
    reference        VARCHAR(30) UNIQUE,                 -- next_reference('PC/DL') on issue
    issued_at        TIMESTAMPTZ,
    -- Staff view (employee): delivery in My HR letters
    acknowledged_at  TIMESTAMPTZ,
    hand_delivered_at TIMESTAMPTZ,
    hand_delivered_by VARCHAR(255),
    reply_due        DATE,                               -- show cause only: add_working_days(issued_at, reply days)
    reply_body       TEXT,
    reply_at         TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (checked_by IS NULL OR checked_by <> drafted_by)
);

CREATE TABLE er_settings (
    id                      SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    acknowledge_days        INT NOT NULL DEFAULT 2,   -- working days before an unacknowledged letter is flagged
    show_cause_reply_days   INT NOT NULL DEFAULT 3,
    updated_by              VARCHAR(255),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO er_settings (id) VALUES (1);

CREATE TABLE dg_committee_members (
    id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role      VARCHAR(20)  NOT NULL CHECK (role IN ('chair','member','secretary')),
    position  VARCHAR(150) NOT NULL,
    active    BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_er_cases_stage ON er_cases(stage);
CREATE INDEX idx_er_cases_type  ON er_cases(case_type);
CREATE INDEX idx_manager_requests_status ON manager_requests(status);
