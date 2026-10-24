-- Exit Interviews: versioned questionnaire, exit records, answers and follow-up.
-- Prefix: EX.

CREATE TABLE exit_questionnaire_versions (
    version      INT PRIMARY KEY,
    published_by VARCHAR(255),
    published_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE exit_questions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version    INT         NOT NULL REFERENCES exit_questionnaire_versions(version),
    position   INT         NOT NULL,
    kind       VARCHAR(10) NOT NULL CHECK (kind IN ('reasons','rating','text')),
    text       TEXT        NOT NULL,
    UNIQUE (version, position)
);

CREATE TABLE exit_records (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference             VARCHAR(30)  NOT NULL UNIQUE,   -- next_reference('EX') when the invitation is created
    employee_id           VARCHAR(30)  NOT NULL,
    manager_employee_id   VARCHAR(30),                    -- line manager from HRIS (Manager view)
    division              VARCHAR(100) NOT NULL,          -- from HRIS so names stay consistent in reports
    last_working_day      DATE         NOT NULL,
    questionnaire_version INT          NOT NULL REFERENCES exit_questionnaire_versions(version),
    status                VARCHAR(20)  NOT NULL DEFAULT 'invited' CHECK (status IN ('invited','in_progress','completed','no_response')),
    wants_conversation    BOOLEAN      NOT NULL DEFAULT FALSE,
    share_with_manager    BOOLEAN      NOT NULL DEFAULT FALSE,
    invited_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    submitted_at          TIMESTAMPTZ
);

CREATE TABLE exit_answers (
    record_id    UUID     NOT NULL REFERENCES exit_records(id),
    question_id  UUID     NOT NULL REFERENCES exit_questions(id),
    rating       SMALLINT CHECK (rating BETWEEN 1 AND 5),  -- NULL = prefer not to say; excluded from averages
    reasons      JSONB,
    text_answer  TEXT,
    PRIMARY KEY (record_id, question_id)
);

CREATE TABLE exit_notes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id  UUID        NOT NULL REFERENCES exit_records(id),
    body       TEXT        NOT NULL,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE exit_themes (
    record_id UUID        NOT NULL REFERENCES exit_records(id),
    theme     VARCHAR(50) NOT NULL,
    PRIMARY KEY (record_id, theme)
);

CREATE TABLE exit_actions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id  UUID         NOT NULL REFERENCES exit_records(id),
    action     TEXT         NOT NULL,
    owner      VARCHAR(255) NOT NULL,
    owner_type VARCHAR(20)  NOT NULL DEFAULT 'other' CHECK (owner_type IN ('line_manager','hr','division_head','other')),
    owner_employee_id VARCHAR(30),
    due_date   DATE         NOT NULL,
    done_at    TIMESTAMPTZ,
    done_note  TEXT
);
