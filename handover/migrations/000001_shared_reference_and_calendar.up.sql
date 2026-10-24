-- Shared by all four module databases (run first in each one).
-- Reference numbers: <PREFIX>/<YEAR>/<4-digit sequence>, e.g. EV/2026/0042.
-- Sequential per prefix and year, atomic under concurrent submissions, never reused.

CREATE TABLE reference_counters (
    prefix      VARCHAR(20) NOT NULL,
    year        INT         NOT NULL,
    last_value  INT         NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (prefix, year)
);

CREATE OR REPLACE FUNCTION next_reference(p_prefix TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_year  INT := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Indian/Maldives'))::INT;
    v_value INT;
BEGIN
    INSERT INTO reference_counters (prefix, year, last_value)
    VALUES (p_prefix, v_year, 1)
    ON CONFLICT (prefix, year)
    DO UPDATE SET last_value = reference_counters.last_value + 1, updated_at = NOW()
    RETURNING last_value INTO v_value;

    RETURN p_prefix || '/' || v_year || '/' || LPAD(v_value::TEXT, 4, '0');
END;
$$;

-- Working days for policy timelines. Weekend is Friday and Saturday;
-- public holidays are maintained by HR in public_holidays.
CREATE TABLE public_holidays (
    holiday_date DATE PRIMARY KEY,
    name         VARCHAR(150) NOT NULL
);

CREATE OR REPLACE FUNCTION add_working_days(p_from DATE, p_days INT)
RETURNS DATE
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    d     DATE := p_from;
    added INT  := 0;
BEGIN
    WHILE added < p_days LOOP
        d := d + 1;
        IF EXTRACT(ISODOW FROM d) NOT IN (5, 6)
           AND NOT EXISTS (SELECT 1 FROM public_holidays h WHERE h.holiday_date = d) THEN
            added := added + 1;
        END IF;
    END LOOP;
    RETURN d;
END;
$$;
