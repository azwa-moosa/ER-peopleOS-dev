-- Employee Voice: reports, routing, policy timelines and confidential identity requests.
-- Prefix: EV. Linked ER cases use ER (People Manager).

CREATE TABLE voice_categories (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL UNIQUE,
    help_text   TEXT,
    routing     VARCHAR(10)  NOT NULL DEFAULT 'any' CHECK (routing IN ('any', 'hr_only')),
    is_sexual_harassment BOOLEAN NOT NULL DEFAULT FALSE,
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (NOT is_sexual_harassment OR routing = 'hr_only')
);

-- HR-maintained timelines in working days, per case type.
CREATE TABLE voice_case_policies (
    case_type        VARCHAR(30) PRIMARY KEY CHECK (case_type IN ('formal_grievance','informal_concern','sexual_harassment')),
    timebound        BOOLEAN NOT NULL,
    acknowledge_days INT     NOT NULL,
    review_days      INT     NOT NULL DEFAULT 0,
    outcome_days     INT     NOT NULL,
    updated_by       VARCHAR(255),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (case_type <> 'sexual_harassment' OR timebound),
    CHECK (case_type <> 'formal_grievance' OR timebound)
);
INSERT INTO voice_case_policies VALUES
    ('formal_grievance',  TRUE,  2, 10, 20, 'seed', NOW()),  -- sample values: set per Grievance Procedure
    ('informal_concern',  FALSE, 3,  0, 15, 'seed', NOW()),
    ('sexual_harassment', TRUE,  1,  7, 15, 'seed', NOW());  -- sample values: set per Sexual Harassment Policy

CREATE TABLE voice_reports (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference             VARCHAR(30)  NOT NULL UNIQUE,   -- next_reference('EV')
    category_id           UUID         NOT NULL REFERENCES voice_categories(id),
    reporter_employee_id  VARCHAR(30)  NOT NULL,          -- held in this table only; never returned to handlers when confidential
    division              VARCHAR(100) NOT NULL,
    confidential          BOOLEAN      NOT NULL DEFAULT FALSE,
    route_division_chief  BOOLEAN      NOT NULL DEFAULT FALSE,
    route_division_director BOOLEAN    NOT NULL DEFAULT FALSE,
    requested_formal      BOOLEAN      NOT NULL DEFAULT FALSE,
    case_type             VARCHAR(30)  NOT NULL REFERENCES voice_case_policies(case_type),
    description           TEXT         NOT NULL,
    status                VARCHAR(30)  NOT NULL DEFAULT 'received'
                          CHECK (status IN ('received','acknowledged','under_review','information_needed','outcome_issued','referred_to_er_case')),
    assignee              VARCHAR(255),
    received_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    acknowledged_at       TIMESTAMPTZ,
    reviewed_at           TIMESTAMPTZ,
    closed_at             TIMESTAMPTZ,
    outcome               TEXT,
    er_case_reference     VARCHAR(30),
    reporter_rating       SMALLINT CHECK (reporter_rating BETWEEN 1 AND 5),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Handlers read reports through this view only: the reporter is masked when confidential.
CREATE VIEW voice_reports_for_handlers AS
SELECT r.*,
       CASE WHEN r.confidential THEN NULL ELSE r.reporter_employee_id END AS visible_reporter_id
FROM voice_reports r;

CREATE TABLE voice_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id   UUID        NOT NULL REFERENCES voice_reports(id),
    author      VARCHAR(10) NOT NULL CHECK (author IN ('reporter','hr')),
    kind        VARCHAR(15) NOT NULL CHECK (kind IN ('message','update','question','outcome','internal_note')),
    body        TEXT        NOT NULL,
    created_by  VARCHAR(255),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (kind <> 'internal_note' OR author = 'hr')
);

-- Manager view: Division Chief / Director acknowledgement and responses (HR only; never shown to the reporter).
CREATE TABLE voice_leader_activity (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id          UUID        NOT NULL REFERENCES voice_reports(id),
    leader_role        VARCHAR(20) NOT NULL CHECK (leader_role IN ('division_chief','division_director')),
    leader_employee_id VARCHAR(30) NOT NULL,
    kind               VARCHAR(10) NOT NULL CHECK (kind IN ('seen','response')),
    body               TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (kind = 'seen' OR body IS NOT NULL)
);

-- Leaders read reports through this view: only those routed to their role, never sexual harassment, reporter masked when confidential.
CREATE VIEW voice_reports_for_leaders AS
SELECT r.id, r.reference, r.category_id, r.division, r.case_type, r.status, r.description, r.received_at, r.closed_at, r.outcome,
       r.route_division_chief, r.route_division_director,
       CASE WHEN r.confidential THEN NULL ELSE r.reporter_employee_id END AS visible_reporter_id
FROM voice_reports r
WHERE r.case_type <> 'sexual_harassment' AND (r.route_division_chief OR r.route_division_director);

CREATE TABLE voice_identity_requests (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id     UUID         NOT NULL REFERENCES voice_reports(id),
    requested_by  VARCHAR(255) NOT NULL,
    reason        TEXT         NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'awaiting_approval' CHECK (status IN ('awaiting_approval','approved','rejected')),
    decided_by    VARCHAR(255),
    decided_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (decided_by IS NULL OR decided_by <> requested_by)   -- second HR user decides
);

CREATE INDEX idx_voice_reports_status ON voice_reports(status);
CREATE INDEX idx_voice_reports_type   ON voice_reports(case_type);
