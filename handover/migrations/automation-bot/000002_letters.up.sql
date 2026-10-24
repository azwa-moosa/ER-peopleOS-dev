-- Automation Bot: reference letter requests and the shared letter template library.
-- Prefixes: PC/RL (request), PC/LTR (issued reference letter), PC/DL (issued disciplinary letter, see People Manager).

CREATE TABLE letter_templates (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code           VARCHAR(50)  NOT NULL,
    name           VARCHAR(150) NOT NULL,
    category       VARCHAR(20)  NOT NULL CHECK (category IN ('reference', 'disciplinary')),
    staff_visible  BOOLEAN      NOT NULL DEFAULT TRUE,  -- always FALSE for disciplinary
    version        INT          NOT NULL DEFAULT 1,
    body           TEXT         NOT NULL,               -- {placeholders} for employee facts and answers
    locked_clauses TEXT,
    request_fields JSONB        NOT NULL DEFAULT '[]',  -- questions staff answer
    needs_consent  BOOLEAN      NOT NULL DEFAULT FALSE, -- salary or ID number included
    needs_endorsement BOOLEAN   NOT NULL DEFAULT FALSE, -- line manager endorses before HR drafts
    active         BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by     VARCHAR(255),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMPTZ,
    UNIQUE (code, version),
    CHECK (category = 'reference' OR staff_visible = FALSE)
);

CREATE TABLE letter_requests (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference          VARCHAR(30)  NOT NULL UNIQUE,     -- next_reference('PC/RL')
    template_id        UUID         NOT NULL REFERENCES letter_templates(id),
    template_version   INT          NOT NULL,
    employee_id        VARCHAR(30)  NOT NULL,
    manager_employee_id VARCHAR(30),                    -- line manager from HRIS at submission (Manager view)
    answers            JSONB        NOT NULL DEFAULT '{}',
    consent_given      BOOLEAN      NOT NULL DEFAULT FALSE,
    status             VARCHAR(30)  NOT NULL DEFAULT 'submitted'
                       CHECK (status IN ('awaiting_manager_endorsement','declined_by_manager','submitted','in_progress','information_needed','awaiting_check','issued','cancelled')),
    endorsed_by        VARCHAR(30),
    endorsed_at        TIMESTAMPTZ,
    endorsement_note   TEXT,                            -- required when declined (enforced in service)
    drafted_by         VARCHAR(255),
    checked_by         VARCHAR(255),
    draft_body         TEXT,
    letter_reference   VARCHAR(30) UNIQUE,              -- next_reference('PC/LTR') on issue
    issued_at          TIMESTAMPTZ,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (checked_by IS NULL OR checked_by <> drafted_by) -- four-eyes control
);

CREATE TABLE letter_request_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID        NOT NULL REFERENCES letter_requests(id),
    author      VARCHAR(10) NOT NULL CHECK (author IN ('staff','manager','hr')),
    body        TEXT        NOT NULL,
    created_by  VARCHAR(255),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_letter_requests_status   ON letter_requests(status);
CREATE INDEX idx_letter_requests_employee ON letter_requests(employee_id);
CREATE INDEX idx_letter_requests_manager  ON letter_requests(manager_employee_id);
