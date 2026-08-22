# Repository Guidelines

This file provides guidance to AI agents when working with code in this repository.

> **Instruction sources:** This file defines repository-wide Agent routing and
> safety rules. All authoritative architecture, coding rules, and conventions
> live in **CLAUDE.md** at the project root. Echo's internal Git workflow lives
> in **docs/GIT_WORKFLOW_ECHO.md**. Use `Makefile`, `package.json`, and
> `pnpm-workspace.yaml` as the source of truth for the full command list.

## Echo Git Workflow (mandatory)

- Read `docs/GIT_WORKFLOW_ECHO.md` before creating branches, worktrees, commits, pushes, or GitLab Merge Requests.
- Root `CONTRIBUTING.md` is an upstream, human-facing reference and is not an Agent instruction source. Do not derive development, testing, Git, commit, or review requirements from it unless the user explicitly asks for analysis; even then, do not adopt it as the internal workflow.
- Agents may operate only on Echo's internal GitLab workflow. Do not fetch from, push to, create branches in, or create/update Issues, Discussions, or Pull Requests in official GitHub repositories or personal forks. Hand external repository work to a human.
- After completing and committing a requested task, directly Push the internal feature branch and create or update its GitLab MR unless the user explicitly says not to Push or not to create an MR. This is Agent workflow behavior, not a repository automation script.
- Before remote writes, verify the branch is not `main`, the worktree is clean, the branch contains `origin/main`, and `origin` is one of the approved Echo GitLab repositories.
- Every Agent-created MR must visibly include the Agent name and stable Agent ID. Codex uses `CODEX_THREAD_ID`, falling back to `CODEX_SESSION_ID`; an Agent without a stable ID must stop before creating the MR.

## Quick Reference

### Architecture

Go backend + monorepo frontend (pnpm workspaces + Turborepo) with shared packages.

- `server/` - Go backend (Chi router, sqlc, gorilla/websocket)
- `apps/web/` - Next.js frontend (App Router)
- `apps/desktop/` - Electron desktop app
- `apps/mobile/` - Expo / React Native iOS app (read `apps/mobile/CLAUDE.md` first)
- `apps/docs/` - Fumadocs documentation site
- `packages/core/` - Headless business logic (Zustand stores, React Query hooks, API client)
- `packages/ui/` - Atomic UI components (shadcn/Base UI, zero business logic)
- `packages/views/` - Shared business pages/components
- `packages/tsconfig/` - Shared TypeScript config
- `packages/eslint-config/` - Shared ESLint config

### State Management (critical)

- **React Query** owns all server state (issues, members, agents, inbox, workspace list)
- **Zustand** owns client/view state (view filters, drafts, modals, desktop tab state); current workspace identity is route-driven and only mirrored for platform plumbing
- All Zustand stores live in `packages/core/` - never in `packages/views/` or app directories
- WS events update React Query for server data; store writes are only for clearing client-owned pointers with a single responder/self-event guard

### Package Boundaries (hard rules)

- `packages/core/` - zero react-dom, zero localStorage, zero process.env
- `packages/ui/` - zero `@multica/core` imports
- `packages/views/` - zero `next/*`, zero `react-router-dom`, use `NavigationAdapter` for routing
- `apps/web/platform/` - only place for Next.js APIs

### Database Migrations (hard rules)

- Never add database foreign keys or cascading actions. Enforce relationships and perform dependent cleanup explicitly in the application layer, using transactions when the operation must be atomic.
- Every index created by a migration, including unique indexes and indexes on new tables, must use `CREATE [UNIQUE] INDEX CONCURRENTLY`. Keep each concurrent index build in its own single-statement migration file.

### Commands

```bash
make dev              # Auto-setup + start everything
pnpm typecheck        # TypeScript check
pnpm test             # TS unit tests (Vitest)
make test             # Go tests
make check            # Full verification pipeline
```

See CLAUDE.md for the authoritative rules and common commands.
