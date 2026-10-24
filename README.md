# People & Culture apps: prototypes and handover

Four separate apps, each with its own CR, each with a Staff view, a Manager view and an HR view switched by a toggle.

| App | File | What it covers |
| --- | --- | --- |
| Automation Bot | `apps/automation-bot.html` | Reference letter requests; line managers endorse where needed; HR drafts, checks and issues. Holds the disciplinary letter templates. |
| Employee Voice | `apps/employee-voice.html` | Concerns, formal and informal grievances and sexual harassment reports, routed to HR, Division Chief or Director (who see them in the Manager view), with policy timelines. |
| People Manager | `apps/people-manager.html` | Employees: My HR letters (acknowledge, reply to show cause) and My cases. Managers: guidance, issue reporting, team cases. HR: intake, ER cases, D&G Committee, disciplinary letters. |
| Exit Interviews | `apps/exit-interviews.html` | Exit questionnaire for leavers; line managers see shared summaries and complete actions; HR review and insights. |

These are clickable prototypes with sample data. They are not connected to ESS or HRIS. Changes are kept in each viewer's own browser (Reset sample data restores them). **Do not enter real employee information.**

## Run it

Pick one.

**1. Just open it.** Double-click `index.html`. Everything works offline except the web fonts, which fall back to system fonts.

**2. Node (no install needed beyond Node 18+).**

```bash
node server.js            # http://localhost:8080
PORT=3000 node server.js  # another port
```

**3. Docker.**

```bash
docker compose up -d --build   # http://<server>:8080
```

Health check: `GET /health` returns `{"status":"ok"}`.

## Host it on your own server

- Any static web server works: copy `index.html`, `brief.html` and the `apps/` folder to the web root (Nginx, Apache, IIS, an internal file share with HTTP).
- With Docker, `docker compose up -d --build` on the server, then put your reverse proxy or load balancer in front of port 8080. `nginx.conf` already sets basic security headers.
- With Node, run `node server.js` under a service manager (systemd, pm2) and proxy to it. It serves only `index.html`, `brief.html` and `apps/`.
- Keep the site on the internal network. It needs no database and stores nothing on the server.

## What else is in here

| Folder | Contents |
| --- | --- |
| `handover/ONEUI_HANDOVER.md` | How each app maps onto the OneUI starter kit and starter API: the three views, Cerbos actions, routes, endpoints, reference numbers, timelines, routing. |
| `handover/migrations/` | PostgreSQL migrations (golang-migrate format): a shared reference-number and working-day migration, then one per app. Tested up and down. |
| `handover/import/` | Template and steps to bring the 30 existing ER cases into People Manager. |
| `brief.html` | Interactive brief: objectives, step-by-step flows per view, who sees what, routing, case lifecycle, timelines. |
| `deck/` | The briefing deck (PowerPoint). |

## Reference number formats

| Prefix | Example | Used for |
| --- | --- | --- |
| PC/RL | PC/RL/2026/0042 | Letter request |
| PC/LTR | PC/LTR/2026/0119 | Issued reference letter |
| PC/DL | PC/DL/2026/0038 | Issued disciplinary letter |
| EV | EV/2026/0042 | Employee Voice report |
| PM | PM/2026/0022 | Manager request or report |
| ER | ER/2026/0042 | ER case |
| EX | EX/2026/0044 | Exit record |

Sequential per prefix and year, created automatically, never reused, not editable.

## Notes

- Timelines in the prototypes are sample values. HR sets them in Settings to match the Disciplinary Procedure, Grievance Procedure and Sexual Harassment Policy.
- The 30 cases in People Manager are generated samples standing in for the real tracker.
- Microsoft 365 (Entra ID, Outlook, Teams, SharePoint) is a later phase and not part of the CRs.
