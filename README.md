# Atlas Operations

Standalone AI property-operations SaaS prototype, repurposed from `agent-x`.

## Current state

- React + TypeScript + Vite frontend with responsive operations dashboard.
- Demo task queue, search, status transitions, approvals view and new-task interaction.
- Example property data is hard-coded; task changes exist only in memory and reset on reload.
- No authentication, database, AI service, real communications, payments, or deployment integration yet.
- This is **not production-ready**. Do not use with real tenant data.

## Run

```bash
npm install
npm run dev
npm run build
npm test
```

## Planned milestones

1. Replace demo data with Supabase tenant-scoped schema and RLS policies.
2. Implement authentication and organizations with membership authorization.
3. Implement property, unit, contact, work-order, and document CRUD with validation.
4. Add durable jobs and an auditable approval queue; require explicit approval for external communications and payments.
5. Integrate a supervised AI agent for classification and drafting; never silently execute external actions.
6. Add tests, audit logs, observability, and CI before any production deployment.

## Recovery

Previous macOS Wi-Fi Stabilizer is preserved at branch `backup/wifi-stabilizer-2026-10-26`. The earlier Agent-X Python starter was already preserved at `codex/agent-x-original-20261020`.
