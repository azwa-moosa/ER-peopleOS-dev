# OneUI developer handover

How the four prototypes map onto the OneUI starter template (`oneui-starter-kit` for the Next.js 16 frontend, `oneui-starter-api` for the Go/Fiber API, `oneui-libs` for audit). Each app is its own OneUI module with its own CR, frontend, API and database.

## Modules

| App | Frontend module | API module | Cerbos resource kind | Reference prefixes |
| --- | --- | --- | --- | --- |
| Automation Bot | `oneui-pc-letters` | `oneui-pc-letters-api` | `pc_letters` | PC/RL, PC/LTR (PC/DL shared with People Manager) |
| Employee Voice | `oneui-pc-voice` | `oneui-pc-voice-api` | `pc_voice` | EV |
| People Manager | `oneui-pc-people-manager` | `oneui-pc-people-manager-api` | `pc_people_manager` | PM, ER, PC/DL |
| Exit Interviews | `oneui-pc-exit` | `oneui-pc-exit-api` | `pc_exit` | EX |

Clone the starter kit and starter API for each module and work through every `// TODO: Customize` (app name, Cerbos `kind`/`id`, API registry name, env var, navigation, audit source module name in `cmd/main.go`).

## Staff, Manager and HR views

Three views per app, switched by a toggle in `AppHeader` (starter kit `toggle-group`). There is no role model beyond these.

| View | Who qualifies | Source |
| --- | --- | --- |
| Staff | Every authenticated ESS user | JWT `basic_access` |
| Manager | People leaders: users with direct reports (Letters, People Manager, Exit); Division Chiefs and Directors (Voice) | HRIS reporting line and division leadership, resolved at request time from the JWT `employeeId` |
| HR | P&C staff in the ESS HR access group | JWT role `pc_hr` |

- Render only the toggles a user qualifies for: `checkPermission("View Manager")` and `checkPermission("View HR")` in the module layout. If only Staff applies, hide the toggle.
- Keep the view in the URL (`?view=manager`) via `nuqs`.
- Every API route checks the view's permission and scopes data server-side: managers get only their reports' records (or, in Voice, reports routed to their role in their division); employees get only their own. Never filter in the browser.
- Data a view must never receive is excluded in the query, not hidden in the UI: salary and letter contents (Letters manager), confidential reporter IDs and sexual harassment reports (Voice manager, via `voice_reports_for_leaders`), letters/statements/notes (People Manager manager), ratings and unshared answers (Exit manager).

### Suggested Cerbos actions

| Module | Staff | Manager | HR |
| --- | --- | --- | --- |
| pc_letters | `Request Letter`, `View Own Requests` | `View Manager`, `Endorse Letter`, `View Team Requests` | `View HR`, `Draft Letter`, `Check Letter`, `Issue Letter`, `Manage Templates` |
| pc_voice | `Submit Report`, `View Own Reports` | `View Manager`, `View Routed Reports`, `Respond To HR` | `View HR`, `Handle Report`, `Request Identity`, `Approve Identity`, `Manage Settings` |
| pc_people_manager | `View Own Letters`, `Acknowledge Letter`, `Reply Show Cause`, `View Own Cases` | `View Manager`, `View Guidance`, `Submit Manager Request`, `View Team Cases` | `View HR`, `Handle Intake`, `Manage Cases`, `Draft Letter`, `Check Letter`, `Issue Letter`, `Record Hand Delivery`, `Manage Settings` |
| pc_exit | `Complete Exit Feedback` | `View Manager`, `View Team Leavers`, `Complete Assigned Action` | `View HR`, `Manage Leavers`, `Manage Questionnaire` |

The four-eyes rules (checker is not the drafter; identity approver is not the requester) are enforced in the database with CHECK constraints as well as in the service layer.

## Routes (frontend, `app/(module)/…`)

| Module | Staff and Manager routes | HR routes |
| --- | --- | --- |
| Letters | `/request`, `/my-requests` · Manager: `/team` | `/hr/requests`, `/hr/requests/[id]`, `/hr/templates`, `/hr/report` |
| Voice | `/raise`, `/my-concerns` · Manager: `/sent-to-me` | `/hr/inbox`, `/hr/inbox/[id]`, `/hr/settings`, `/hr/report` |
| People Manager | `/my-letters`, `/my-cases` · Manager: `/guidance`, `/guidance/[id]`, `/ask`, `/my-requests`, `/team-cases` | `/hr/intake`, `/hr/cases`, `/hr/cases/[id]`, `/hr/topics`, `/hr/settings`, `/hr/insights` |
| Exit | `/feedback` · Manager: `/team-leavers` | `/hr/leavers`, `/hr/leavers/[id]`, `/hr/questionnaire`, `/hr/insights` |

## API endpoints (Fiber, `/api/v1`)

**Letters**: `GET/POST /letter-requests`, `GET /team/letter-requests`, `POST /letter-requests/:id/{endorse,decline}`, `GET /letter-requests/:id`, `POST /letter-requests/:id/{cancel,messages,pickup,send-for-check,return,issue}`, `GET/POST /templates`, `PUT /templates/:id` (creates a new version), `POST /templates/:id/{retire,restore}`, `GET /reports/letters`.

**Voice**: `GET/POST /reports`, `GET /leader/reports`, `POST /leader/reports/:id/{seen,responses}`, `GET /reports/:id`, `POST /reports/:id/{acknowledge,messages,route,case-type,outcome,er-case,rating}`, `POST /reports/:id/identity-requests`, `POST /identity-requests/:id/{approve,reject}`, `GET/PUT /settings/categories`, `GET/PUT /settings/policies`, `GET /reports/summary`.

**People Manager**: `GET /my/letters`, `POST /my/letters/:id/{acknowledge,reply}`, `GET /my/cases`, `GET /team/cases`, `POST /letters/:id/hand-delivery`, `GET /topics`, `GET /topics/:id`, `POST /topics/:id/view`, `GET/POST /manager-requests`, `POST /manager-requests/:id/{messages,open-case,close}`, `GET/POST /cases`, `GET /cases/:id`, `POST /cases/:id/{stage,steps/:index/done,route,dg,decision,log}`, `POST /cases/:id/letters`, `POST /letters/:id/{send-for-check,issue}`, `GET/PUT /settings/case-types`, `GET /insights`.

**Exit**: `GET /team/leavers`, `POST /team/actions/:id/done`, `GET /my-exit`, `PUT /my-exit/answers` (save), `POST /my-exit/submit`, `GET /leavers`, `GET /leavers/:id`, `POST /leavers/:id/{remind,notes,themes,actions}`, `GET/POST /questionnaire/versions`, `GET /insights`.

Responses follow the starter API format (`success`, `data`, `error`, plus `total/page/limit` for lists). Every state change publishes an audit event through `oneui-libs/auditclient`.

## Reference numbers

`migrations/000001_shared_reference_and_calendar.up.sql` adds `next_reference(prefix)`, which returns `<PREFIX>/<YEAR>/<0000>` atomically. Call it inside the same transaction that inserts the record:

```go
var ref string
if err := tx.Raw("SELECT next_reference(?)", "EV").Scan(&ref).Error; err != nil { return err }
report.Reference = ref
```

Request references are created on submission; letter references (PC/LTR, PC/DL) only when a letter is issued, so drafts never consume numbers.

## Timelines

`add_working_days(date, n)` skips Friday, Saturday and rows in `public_holidays`. Due dates are calculated at read time from the case's opening date and the current policy row, so a change HR makes in Settings applies to open cases immediately. Formal grievances and sexual harassment are always timebound (CHECK constraints).

## Routing

HR always receives every report and case. `route_division_chief` and `route_division_director` add those recipients, who see the report in their Manager view; HRIS supplies who holds each role per division. Sexual harassment is HR only (CHECK constraints). A confidential reporter's ID is never sent to recipients or returned to handlers; read reports through `voice_reports_for_handlers`.

## Migrations

Run `000001_shared_reference_and_calendar` and then the module's own `000002_*` in each module database (golang-migrate format, matching the starter API). All four were tested up and down against PostgreSQL. `import/` covers moving the 30 existing ER cases into People Manager.

## Microsoft 365 (later phase)

Not part of these CRs. Planned: Entra ID sign-in, Outlook notices and D&G hearing invites, Teams notices to HR, Chiefs and Directors, SharePoint storage for case evidence. Keep notification sending behind one interface in each API so the M365 adapter can be added without touching workflows.
