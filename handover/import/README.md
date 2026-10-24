# Importing the 30 existing ER cases

1. Export the current case tracker to CSV and map its columns to `er_cases_import_template.csv`. Delete the example row.
2. Allowed values:
   - `case_type`: `disciplinary`, `grievance_formal`, `grievance_informal`, `performance`, `sexual_harassment`
   - `stage`: `intake`, `investigation`, `show_cause`, `dg_committee`, `decision`, `closed`
   - `decision`: `No action`, `Counselling`, `Verbal warning`, `Written warning`, `Final written warning`, `Suspension without pay`, `Demotion`, `Termination` (blank while open)
   - `stage` can only be `dg_committee` when `dg_referred` is `true`; sexual harassment cases cannot be routed to a Chief or Director.
3. Keep each case's existing reference number. Load into the People Manager database:

```sql
CREATE TEMP TABLE er_import (LIKE er_cases INCLUDING DEFAULTS);
\copy er_import (reference, case_type, formal, employee_id, employee_name, division, grade, source_type, source_reference, summary, stage, route_division_chief, route_division_director, dg_referred, dg_hearing_date, dg_decision, decision, case_officer, opened_at, closed_at) FROM 'er_cases.csv' CSV HEADER

INSERT INTO er_cases SELECT * FROM er_import ON CONFLICT (reference) DO NOTHING;
UPDATE er_cases SET migrated = TRUE, source_type = 'migrated' WHERE reference IN (SELECT reference FROM er_import);
INSERT INTO er_case_log (case_id, entry, created_by)
SELECT id, 'Imported from the current case tracker.', 'migration' FROM er_cases WHERE migrated;
```

4. Move the ER counter past the highest imported number so new cases never reuse one:

```sql
INSERT INTO reference_counters (prefix, year, last_value)
SELECT 'ER', split_part(reference, '/', 2)::INT, MAX(split_part(reference, '/', 3)::INT)
FROM er_cases GROUP BY split_part(reference, '/', 2)
ON CONFLICT (prefix, year) DO UPDATE SET last_value = GREATEST(reference_counters.last_value, EXCLUDED.last_value);
```

If the current tracker uses a different numbering format, keep the old number in `source_reference` and let `next_reference('ER')` issue new ones.
