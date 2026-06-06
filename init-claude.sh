#!/bin/bash

# Ensure directories exist
mkdir -p .claude/plans .claude/templates

# Prompt for Project Name
echo "============================================="
echo "🤖 Claude Code Local Tracking Initializer"
echo "============================================="
printf "Enter the name of your project: "
read -r PROJECT_NAME

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="My Project"
fi

# 1. Create root CLAUDE.md
cat << 'EOF' > CLAUDE.md
# 🤖 Project Guidelines & Tracking Protocol

## 🎯 Core Persona & Guardrails
- You are an elite, practical software engineer working locally.
- Prevent scope creep. Never write unvetted functional code without an active, approved plan file in `.claude/plans/`.
- Work on exactly ONE checkbox item at a time. Do not multi-task across different features or bugs.

## 🗺️ Hierarchical Planning State Machine
Whenever the user activates `/plan` mode, or requests a design breakdown, you MUST follow this protocol before entering execution mode:
1. **Audit Files:** Check `@ROADMAP.md` and look for the specific sub-plan in `@.claude/plans/`.
2. **Clone the Pattern:** If initializing a new epic, copy `@.claude/templates/feature-plan.md` into a new unique filename in `.claude/plans/` (e.g., `001-auth-setup.md`).
3. **Draft the Spec:** Fill out the template fields completely while in read-only `/plan` mode. Show the step-by-step checklist of tiny, testable units.
4. **Propose the Update:** Show the markdown diff to link this new plan file back into the master `@ROADMAP.md` dashboard.

## 🔄 Automated State Synchronization
Once planning is verified and you are executing code blocks:
- Run the build/test commands (`npm run test`, `pytest`, etc.) immediately after finishing a checklist item.
- As soon as a task passes its tests, physically change its status from `[ ]` to `[x]` inside the relevant active plan file.
- Update the macro progress counters up on the master `@ROADMAP.md`.
- Commit the written code and the updated documentation together in a single micro-commit.
EOF

# 2. Create .claude/templates/roadmap.md
cat << 'EOF' > .claude/templates/roadmap.md
# 🗺️ Master Project Roadmap: [Project Name]

## 📊 Global Milestone Tracker
<!-- Claude will calculate progress dynamically by auditing individual sub-plan files -->
- [ ] 🟩 Phase 1: Core App MVP (Progress: 0%) -> *See [.claude/plans/](.claude/plans/)*
- [ ] 🟦 Phase 2: Scaling & Optimization (Progress: 0%) -> *See [.claude/plans/](.claude/plans/)*

## 📋 Idea Incubator & Scope Backlog
<!-- Drop loose ideas, features, or future pivots here so they don't break active context -->
- [ ] Initial Task: Parse raw project notes into detailed Phase 1 plan specs.
EOF

# 3. Create .claude/templates/feature-plan.md
cat << 'EOF' > .claude/templates/feature-plan.md
# 📑 Plan [ID]: [Epic Name]
> **Status:** Planning / Active | **Parent Milestone:** [Phase Name]

## 🎯 1. Target Scope & Boundaries
- **Core Objective:** What problem does this specific sub-plan solve?
- **Out of Scope:** What are we strictly avoiding touching during this implementation?

## 🏗️ 2. Architectural Blueprint
- **Files to Create:** [List paths or None]
- **Files to Modify:** [List paths or None]
- **Data Model/Schema Changes:** [Note any database or interface adjustments]
- **Downstream Impact:** [List dependencies that might experience breakages]

## 🚶‍♂️ 3. Step-by-Step Execution Checklist
*Break the implementation down into the smallest logical, testable commits.*
- [ ] Step 1: [Task description] -> *Target: File Path*
- [ ] Step 2: [Task description] -> *Target: File Path*
EOF

# 4. Create .claude/templates/bug-investigation.md
cat << 'EOF' > .claude/templates/bug-investigation.md
# 🐛 Issue Tracker: [Short Bug Description]
> **Triggered By:** [Test Failure / Manual Report] | **Target Plan Link:** [Link]

## 🔍 1. Symptom & Reproduction
- **Observed Behavior:** What is broken?
- **Expected Behavior:** What should happen?
- **Reproduction Steps:** Provide the exact steps or commands to trigger the issue locally.

## 🩺 2. Root Cause Analysis
- **The Culprit:** Line, file, or lifecycle stage causing the error.
- **Why it Happened:** Technical reason for the breakdown.

## 🛠️ 3. Resolution Steps
- [ ] Step 1: Write a reproduction test that isolates the error.
- [ ] Step 2: Apply the code fix in the target file.
- [ ] Step 3: Verify the entire test suite stays green.
EOF

# 5. Create .claude/templates/refactor-debt.md
cat << 'EOF' > .claude/templates/refactor-debt.md
# ⚙️ Refactor Spec: [Target Module]
> **Objective:** [Optimization / Code Cleanups / Modernization]

## 📉 1. Current State Pain Points
- Detail the current architectural constraints or high token-cost areas requiring cleanup.

## 📈 2. Proposed Target State
- Layout the clean design patterns or structural modifications we are implementing.

## 🛡️ 3. Backward Compatibility & Verification
- **Required Baseline Tests:** [List specific test files that MUST remain functional]

## 📋 4. Migration Checklist
- [ ] Step 1: Isolate current functional pathways.
- [ ] Step 2: Scaffold new implementation architecture.
- [ ] Step 3: Run full regression and performance testing checks.
EOF

# 6. Instantiate the live root ROADMAP.md from the template
cp .claude/templates/roadmap.md ROADMAP.md
# Replace template project name placeholder with user input
sed -i.bak "s/\[Project Name\]/$PROJECT_NAME/g" ROADMAP.md && rm ROADMAP.md.bak

echo "============================================="
echo "🟩 Workspace generated successfully!"
echo "============================================="
echo "📁 Created: CLAUDE.md"
echo "📁 Created: ROADMAP.md (Project: $PROJECT_NAME)"
echo "📁 Populated: .claude/templates/"
echo "🚀 Run 'claude' to begin tracking."