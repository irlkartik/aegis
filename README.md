# Aegis — Website, Mobile & Scam-Call Security

One evidence-based security platform:

| Module | What it really does | Status |
|---|---|---|
| **Website security** | Scans an uploaded `.zip` or public GitHub repo for hardcoded secrets (masked), vulnerable dependencies (OSV.dev), and risky config/code patterns. Passive live-site header check. Repair prompt, Markdown report, re-scan + diff. | Working, tested |
| **APK analysis** | Parses the binary manifest, permissions, exported components, network-security config, v1/v2/v3 signing certs, embedded secrets; optional hash reputation. Never installs or runs the APK. | Working, tested |
| **Android companion** | Installed-app inventory + permission-pattern risk, periodic re-checks (WorkManager), install/update detection (`getChangedPackages`), native call screening (`CallScreeningService`), pairing + sync, send an installed app's base APK for analysis. | Built (signed APK), not run on a device here |
| **AI scam-call screening** | Honest-identity screening assistant → deterministic signals (+ optional Claude review with quote verification) → separate policy engine → action. Runs against a **development adapter (simulated caller)**. | Pipeline working & tested; **no live telephony** |
| **Dashboard** | Devices, monitoring health (active / delayed / paused / stale), app risk, call decisions, activity feed from real records only. | Working |

## Run it (Windows)

1. Install Python 3.11+ (tick "Add to PATH").
2. Double-click **`start.bat`** (first run installs dependencies, ~1 min, needs internet).
3. Open **http://localhost:8000**, create an account.

Linux/macOS: `./start.sh`. Tests: `run-tests.bat` (or `cd backend && pytest -v`).

Optional environment variables (set before starting):

| Variable | Enables |
|---|---|
| `ANTHROPIC_API_KEY` | AI remediation per finding, AI review of call transcripts (`AEGIS_AI_MODEL`, default `claude-sonnet-5-5`) |
| `VIRUSTOTAL_API_KEY` | APK hash reputation |
| `AEGIS_OSV=0` | Disable OSV.dev lookups (offline demo) |
| `DATABASE_URL` | e.g. `postgresql+psycopg://…` (SQLite by default; install a Postgres driver) |
| `AEGIS_SECRET` | HMAC key for phone-number hashing (auto-generated in `backend/data/` otherwise) |

## Android companion

* Install **`Aegis-Companion-1.0.0.apk`** on an Android 10+ phone (allow "install unknown apps" for your file manager).
* Laptop and phone on the same Wi-Fi. Find the laptop IP with `ipconfig` (e.g. `192.168.1.20`). Allow Python through Windows Firewall when prompted.
* Dashboard → Devices → **Connect device** → enter `http://192.168.1.20:8000` and the 6-digit code in the app.
* Calls tab → **Set Aegis as call-screening app** to enable native screening.

Rebuild: open `android/` in Android Studio, or `gradlew assembleRelease`. The signing key is in `android/keystore/` (git-ignored — keep it private; you need it to ship updates with the same signature).

**Fest Wi-Fi blocks device-to-device traffic?** Expose the server over HTTPS with Cloudflare Tunnel: `cloudflared tunnel --url http://localhost:8000`, then use the `https://…trycloudflare.com` address in the app.

## Deploy to Vercel

Double-click **`deploy.bat`** (needs Node.js 18+; opens a browser once for `vercel login`). It copies the UI to `public/`, links/creates the Vercel project **aegis-security**, stores `DATABASE_URL` and `AEGIS_SECRET` as encrypted env vars (from the git-ignored `.vercel-secrets/`), and deploys to production in the Mumbai region (`bom1`). Then open `<your-url>/api/health` — it must say `"database":"reachable"`.

What changes on Vercel (serverless):
* **Database:** Supabase Postgres (project *store-preview*), isolated schema `aegis` with its own login role `aegis_app`. It has no grants on your existing tables, and the schema is not exposed through Supabase's REST API.
* **Scans run inside the request** (no background workers), and live call-screening state is stored in the database, so any instance can continue a call.
* **Uploads are capped at 4.4 MB** (Vercel's request-body limit). Most real APKs are larger: analyse those with the local server (`start.bat`). The phone app's "Analyse APK" hits the same limit when paired with the Vercel URL.
* The phone app can pair over HTTPS with the `*.vercel.app` URL — no shared Wi-Fi needed.

## Platform capability matrix

| Capability | Web | Android app | iOS |
|---|---|---|---|
| List installed apps + permissions | ✗ (impossible from a browser) | ✓ `QUERY_ALL_PACKAGES` (Play Store needs a policy declaration) | ✗ not allowed |
| Detect installs/updates | ✗ | ✓ on next scheduled check (`getChangedPackages`) — not instant | ✗ |
| Continuous monitoring | ✗ shows last reported state only | ✓ periodic; Android may delay (Doze, battery saver, force-stop) | ✗ |
| Full static analysis | ✓ uploaded APK | ✓ base APK of an installed app (splits excluded) | ✗ |
| Screen calls before ringing | ✗ | ✓ allow / silence / reject by number + carrier verification | Call Directory label/block only (not built) |
| AI talks to caller | via telephony provider only | ✗ no API exists | ✗ no API exists |
| Read SMS/contacts/other apps' data | ✗ | ✗ not requested | ✗ |

## Safety design (call screening)

* Assistant always says it is automated; never impersonates; refuses to share codes.
* Signals are deterministic regex rules (English + Hinglish), never accent/language/gender/tone.
* Claude (if configured) returns JSON validated by a Pydantic schema; every cited quote must exist verbatim in the transcript; AI can raise a call to "needs review" but **can never create a high-risk verdict or trigger blocking**.
* `calls/policy.py` is the only component that chooses an action. Auto-block is **off by default** and requires rule-based evidence above a threshold. Failures/uncertainty → forward with warning, never block. Allow-listed numbers with scam indicators → warning (caller ID can be spoofed).
* No audio stored. Transcripts stored only if the user enables it. Numbers stored masked + HMAC hash.

## Configuring genuine telephony

See [docs/TELEPHONY.md](docs/TELEPHONY.md). Not done here: needs a paid Twilio account, a number, and carrier call-forwarding. The dev adapter is labelled everywhere and never presented as live.

## Tests (35 passing)

`backend/tests/`: secret detection & masking, false-positive guards, zip-slip/binary handling, OSV success/offline (mocked), SSRF blocking, real compiled APK fixtures (risky, benign debug-signed, Aegis release), malformed/truncated APKs, local-blocklist reputation, labelled scam-signal cases, scenario evaluation (FP/FN = 0 on 8 synthetic scenarios), policy matrix, AI hallucination/schema guards, session lifecycle & transcript privacy, device pairing/sync/delayed status, cross-user isolation, delete-data confirmation, security headers.

## Known limitations (be upfront with judges)

* Synthetic scenarios are few (8) — real-world accuracy is **not measured**. Expect misses on novel scripts and other languages.
* APK analysis is static only: no decompilation (JADX not bundled), no library-version CVEs, no dynamic analysis, no native `.so` inspection.
* Metadata-only device assessment cannot prove a phone is malware-free.
* Website scan is pattern-based; it does not find business-logic or auth flaws.
* Android app compiled & signed but not exercised on a physical device in this build environment — test pairing and screening on your phone before the demo.
* The Android app permits cleartext HTTP at the platform level for LAN demos (the app itself rejects `http://` for public hosts). Aegis's own APK scanner flags this — use HTTPS in production.
* In-memory rate limiting; single-process server. Use Postgres + a real queue for multi-user deployment.
