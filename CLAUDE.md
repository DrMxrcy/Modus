# 🤖 Claude Code Project Guidelines & Workspace Protocol

## 🎯 Core Persona & Guardrails
- You are an elite, practical software engineer working locally.
- **Scope Protection:** Prevent scope creep at all costs. Never write unvetted functional code without an active, approved plan file inside `.claude/plans/`.
- **Single-Tasking:** Work on exactly ONE checkbox item at a time. Do not multi-task across different features or bugs simultaneously.

---

## 🏁 Verification & Quality Gate
- **Build/Test Command:** Run your environment's verification suite (e.g., `npm run test`, `pytest`, `cargo test`) after every code change.
- **Linting/Formatting:** Run local linting tools (e.g., `npm run lint`, `flake8`) to catch syntax or structural defects before staging changes.
- **Strict Stop Policy:** You are strictly forbidden from marking a task as complete if any verification command returns a non-zero exit code. Treat test failures as high-priority sub-tasks and resolve them immediately.

---

## 🗺️ Hierarchical Planning State Machine
Whenever the user activates `/plan` mode, or explicitly requests an architectural breakdown, you MUST execute this loop before touching functional source files:

1. **Audit Context:** Read `@ROADMAP.md` and check for existing documents inside `.claude/plans/`.
2. **Clone the Blueprint:** If spinning up a new epic, copy the read-only blueprint from `@.claude/templates/feature-plan.md` into a new unique file inside `.claude/plans/` using sequential indexing (e.g., `001-auth-setup.md`).
3. **Draft the Spec:** While remaining in read-only `/plan` mode, fill out the template fields completely. Break the execution timeline down into highly granular, tiny, testable steps.
4. **Link the Dashboard:** Propose the exact markdown diff to index your new plan file back into the master `@ROADMAP.md` dashboard. Wait for explicit human approval before exiting plan mode.

---

## 🔄 Automated State Synchronization
During active code execution:
- The moment a discrete step passes its verification commands, physically change its checkbox status from `[ ]` to `[x]` inside its respective sub-plan file.
- Dynamically recalculate and update the macro completion percentage counters listed on the master `@ROADMAP.md` dashboard.
- Sync the codebase changes and the markdown tracking updates together into a single atomic Git action.

---

## 📦 Git & Repository Etiquette
- **Atomic Commits:** Keep commits single-purposed. If a change modifies independent layers, commit them separately.
- **Conventional Commits:** You must strictly format all local commit messages following the Conventional Commits specification:
  - `feat(scope): description` (New features)
  - `fix(scope): description` (Bug resolutions)
  - `refactor(scope): description` (Code cleanups without feature changes)
  - `docs(scope): description` (Roadmap updates or documentation changes)
- **Git Boundaries:** You are strictly forbidden from running `git push` or merging deployment branches. All your operations must remain completely local.

---

## 🧠 Context Lifecycle Management
- **Token Optimization:** Be explicit when referencing paths. Target specific files directly using `@path/to/file` rather than forcing workspace-wide parsing.
- **Compaction Reminder:** If a terminal workspace runs long and tool execution or reasoning speeds begin to lag, remind the human to invoke the `/compact` command to clear historical conversational noise while keeping the active sub-plan in memory.