# OpenClaw App Audit

OpenClaw has been configured with a local project workspace at:

`.openclaw/workspace`

That local state is ignored by git because it contains runtime config and tokens.

## Start OpenClaw

Terminal 1:

```bash
cd /Users/msagastya/Desktop/spend-analyzer
./openclaw-local.sh gateway run --port 18789 --bind loopback
```

Terminal 2:

```bash
cd /Users/msagastya/Desktop/spend-analyzer
./openclaw-local.sh tui
```

## First Prompt To Give OpenClaw

```text
Start a fresh VittaraFinOS audit. First inspect only app structure, dashboard UX, and first-time entry flow. Do not run broad scans or full flutter analyze yet. Use targeted file reads and produce initial findings with P0/P1/P2 severity.
```

## Important Scope

- App path: `/Users/msagastya/Desktop/spend-analyzer/finance_app`
- Do not commit or push unless explicitly asked.
- Do not expose secrets or private data.
- Prefer evidence from code, tests, builds, screenshots, and runtime behavior.

## Follow-Up Prompts

Run these one by one after the first report:

```text
Now audit AI Entry, Voice command, and Quick Entry handoff only.
```

```text
Now audit transactions, custom filters, reports, calculator, and manage/lending pages only.
```

```text
Now audit security, backup/export, performance, analyzer/test/build signals, and release readiness only.
```

```text
Now combine all findings into the final 9-section report from BOOTSTRAP.md.
```
