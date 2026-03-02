---
name: figma-qa
description: Run a parallel Figma-vs-code QA audit across multiple screens. Use when the user wants to compare implemented UI against Figma designs, audit visual consistency, find style discrepancies, or implement design revisions. Accepts a Figma page/frame URL or explicit screen-to-file mappings.
disable-model-invocation: true
user-invocable: true
argument-hint: <figma-url> [--mode=qa|revision] [--screenshots] [--live] [--max-agents=N]
---

# Figma QA Audit

You are an orchestrator that runs a parallel design-vs-implementation audit. Your job is to coordinate sub-agents that each audit one screen, then synthesize their findings into a single actionable report.

## Arguments

Parse `$ARGUMENTS` for:
- **Figma URL** (required): A Figma page URL (auto-discovers frames) or a specific node URL
- `--mode=qa|revision`: Audit mode (default: `qa`)
  - **qa**: Standard consistency check. Assumes the implementation should already be close to the design. Focuses on catching subtle drift and unintentional discrepancies.
  - **revision**: Design has been updated and the implementation needs to catch up. Assumes significant intentional differences. Focuses on cataloging what changed and producing an implementation plan.
- `--screenshots`: Include Figma screenshots in addition to structured design context (default: off)
- `--live`: Capture live UI screenshots from the running app for side-by-side comparison (default: off). See Phase 1b for setup.
- `--max-agents=N`: Max parallel QA agents (default: 10)

If no arguments are provided, ask the user for a Figma URL.

If the user provides explicit mappings instead of a URL, they'll be in the format:
```
<figma-node-url-1> -> <code-file-path-1>
<figma-node-url-2> -> <code-file-path-2>
```

## Orchestration Workflow

### Phase 1a: Gather Project Context

Before spawning any QA agents, you need to build a **shared context brief** that every agent will receive. This ensures consistent, informed auditing.

1. **Read project docs**: Check for `CLAUDE.md` and/or `METHODOLOGY.md` in the project root. Extract:
   - Tech stack (framework, templating language, styling approach)
   - Component patterns (component libraries, utility class systems, design tokens)
   - File structure conventions (where templates/components live)

2. **If project docs are thin or missing**, launch an **Explore agent** to:
   - Identify the tech stack from package.json, requirements.txt, Gemfile, etc.
   - Find the styling approach (Tailwind config, CSS modules, styled-components, theme files)
   - Locate design token definitions (CSS custom properties, theme files, token JSON)
   - Map the component/template directory structure

3. **If anything is still unclear**, ask the user clarifying questions before proceeding. Key things you must know:
   - What styling system is used (Tailwind, CSS modules, etc.)
   - Whether there's a design token / semantic color system
   - Whether the app uses light mode, dark mode, or both (important because Figma MCP extracts light-mode values by default)
   - Where template/component files live

4. **Compose the context brief** — a concise block of text that will be prepended to every QA agent's prompt. Include:
   - Tech stack summary
   - Styling approach and key utility classes or token mappings
   - Any color mode mapping notes (e.g., "Figma shows light-mode tokens; map to dark-mode equivalents using X convention")
   - Component patterns the agent should be aware of
   - **The audit mode** (`qa` or `revision`) and what it means for the agent's task

### Phase 1b: Live UI Setup (only if `--live`)

If the `--live` flag is set, you need a running dev server and a browser so agents can capture screenshots of the current UI.

1. **Determine the dev server command.** Check (in order):
   - `CLAUDE.md` for an explicit dev server command
   - `README.md` for the same
   - `Procfile.dev`, if present, will contain process invocation commands for a full dev environment with all required processes.
     - The dev server can be started using `overmind` if that CLI tool is present regardless of the project's language and framework.
   - `script/dev` if this is a Rails application
   - `package.json` scripts for `dev`, `start`, `serve`
   - Framework-specific conventions (e.g., `next dev`, `vite`, `rails server`)
   - If ambiguous, ask the user

2. **Start the dev server** in a background shell. Wait for it to be ready (watch for "ready on", "listening on", or similar output). Record the local URL (e.g., `http://localhost:3000`).

3. **Determine screen URLs.** For each screen in the audit, you need the route/URL where it can be viewed. Strategies:
   - If the project uses file-based routing (Next.js, Nuxt, SvelteKit), infer routes from file paths
   - Check for a router config file and map screen names to routes
   - If you can't determine routes, ask the user for a mapping or a base URL pattern

4. **Verify browser access.** Open the base URL using the Chrome DevTools MCP (`navigate_page`) and confirm the page loads. Take a quick test screenshot to validate the setup works. Request local login info if you see a login form with username and password fields and it's not specifically called out as a login screen. 

5. **Add to the context brief:**
   - The base URL of the running dev server
   - The screen-to-URL mapping
   - Instructions for agents to use Chrome DevTools MCP tools (`navigate_page`, `take_screenshot`, `take_snapshot`) to capture screenshots

### Phase 2: Discover Screens

**If given a Figma page URL:**
1. Use `get_metadata` with the page's node ID to discover all top-level frames
2. Each frame = one screen to audit
3. Present the discovered screens to the user and ask them to confirm or filter the list

**If given a specific Figma node URL:**
1. Use `get_metadata` to check if it contains child frames
2. If yes, treat each child frame as a screen
3. If no, treat the single node as one screen

**If given explicit mappings:**
1. Parse the `<figma-url> -> <code-file>` pairs
2. Skip to Phase 3 (no file mapping needed)

### Phase 3: Map Screens to Code Files

For auto-discovered screens (no explicit mappings), launch a **single Explore agent** with:
- The list of screen names from Figma
- The project's file structure conventions from Phase 1a
- Instructions to find the corresponding template/component file for each screen

The Explore agent should return a mapping like:
```
"Login Screen" -> src/pages/Login.tsx
"Dashboard" -> src/pages/Dashboard.tsx
"Settings / Profile" -> src/components/settings/Profile.vue
```

If the agent can't confidently map a screen, flag it and ask the user.

### Phase 4: Spawn QA Agents

For each screen (up to `--max-agents` in parallel, default 10), launch a **general-purpose Task agent** with the prompt below. The prompt varies by mode — sections marked `[qa only]` or `[revision only]` are conditionally included.

```
You are auditing a single UI screen: "{screen_name}"

## Project Context
{context_brief_from_phase_1}

## Your Task
1. Use `get_design_context` on Figma node {node_id} to extract the design specification
{if --screenshots: 2. Use `get_screenshot` on node {node_id} for Figma visual reference}
{if --live: N. Navigate to {screen_url} using the Chrome DevTools MCP `navigate_page` tool, then use `take_screenshot` to capture the current live UI}
N. Read the code file: {code_file_path}
N. Compare the implementation against the Figma design
N. Report ALL discrepancies in the structured format below

## What to Look For
- **Spacing**: padding, margin, gap values
- **Typography**: font size, weight, line-height, letter-spacing
- **Colors**: text colors, backgrounds, borders, icon colors (map to project's token system)
- **Border radius**: rounded corners
- **Layout**: flex/grid structure, alignment, sizing
- **Component states**: hover, focus, active, disabled, checked, error states
- **Missing elements**: icons, labels, decorative elements present in design but missing in code
- **Extra elements**: things in code that aren't in the design

[revision only]
## Classifying Changes
For each discrepancy, classify it as one of:
- **Design change**: The Figma design has intentionally changed from what the code implements. This is the primary focus of your audit.
- **Pre-existing inconsistency**: The code didn't match the *previous* design either — this is legacy drift, not part of the current revision. Flag these separately so the user can decide whether to address them now or later.

Use your judgment: if the code and design differ in a way that looks like a deliberate design update (new colors, rearranged layout, changed typography), it's a design change. If it looks like a sloppy implementation detail (off-by-2px padding, wrong font weight that doesn't match any design version), it's pre-existing.

## Report Format — QA Mode
[qa only]
For each discrepancy, report:
- **Location**: file path + line number (or component/element description)
- **Element**: what the discrepancy is on
- **Design**: what Figma shows
- **Code**: what the implementation has
- **Suggested fix**: the specific code change needed

Group findings by severity:
1. **Visual**: clearly visible differences a user would notice
2. **Subtle**: minor spacing/sizing differences
3. **Structural**: layout or component structure differences

## Report Format — Revision Mode
[revision only]
For each discrepancy, report:
- **Location**: file path + line number (or component/element description)
- **Element**: what the discrepancy is on
- **Classification**: design change | pre-existing inconsistency
- **Design (new)**: what the updated Figma shows
- **Code (current)**: what the implementation currently has
- **Suggested fix**: the specific code change needed
- **Effort**: trivial (token/value swap) | minor (small structural change) | major (significant rework)
- **Blast radius**: isolated (this file only) | shared (affects a shared component/style/token)

Group findings into two sections:
1. **Design Changes** — the intentional updates from the revision
2. **Pre-Existing Inconsistencies** — legacy drift (report but don't prioritize)
```

If you have more screens than `--max-agents`, batch them: run the first batch, collect results, then run the next batch.

### Phase 5: Synthesize Report

Once all agents have reported back, produce a single structured report. The report format depends on the mode.

---

#### QA Mode Report

##### 1. Cross-Cutting Issues
Look across all screen reports for **repeated patterns** — the same type of discrepancy appearing on multiple screens. These are DRY opportunities where a single fix (in a shared CSS class, base template, or component) resolves the issue everywhere.

Format:
```
### Cross-Cutting Issues (fix once, applies everywhere)

1. **[Description]**
   - Affected screens: [list]
   - Fix location: [shared file/class]
   - Design: [what Figma shows]
   - Code: [what's implemented]
   - Suggested fix: [specific change]
```

##### 2. Per-Screen Unique Issues
Issues that only appear on one screen and require a screen-specific fix.

Format:
```
### Screen: [Name]

1. **[Element] — [Description]**
   - Location: [file:line]
   - Design: [what Figma shows]
   - Code: [what's implemented]
   - Suggested fix: [specific change]
```

##### 3. Summary Stats
- Total screens audited: N
- Cross-cutting issues: N (affecting M screens)
- Per-screen issues: N
- Recommended fix order: cross-cutting first, then per-screen

---

#### Revision Mode Report

##### 1. Design System Changes
Look across all screen reports for changes to **shared elements** — tokens, colors, typography, shared components. These should be implemented first because they cascade across multiple screens.

Format:
```
### Design System Changes (implement first — cascading impact)

1. **[Description]**
   - Affected screens: [list]
   - Fix location: [shared file/class/token]
   - Design (new): [what updated Figma shows]
   - Code (current): [what's implemented]
   - Suggested fix: [specific change]
   - Effort: [trivial | minor | major]
```

##### 2. Per-Screen Changes
Changes that are unique to a single screen.

Format:
```
### Screen: [Name]

#### Design Changes
1. **[Element] — [Description]**
   - Location: [file:line]
   - Design (new): [what updated Figma shows]
   - Code (current): [what's implemented]
   - Suggested fix: [specific change]
   - Effort: [trivial | minor | major]

#### Pre-Existing Inconsistencies (optional — address if convenient)
1. **[Element] — [Description]**
   - Location: [file:line]
   - Note: [why this appears to be legacy drift rather than a new change]
```

##### 3. Implementation Plan
Synthesize the above into a recommended implementation order:
```
### Recommended Implementation Order

1. **Design system / shared changes** (N items)
   - [Brief list — these cascade so do them first]
2. **Per-screen changes by effort** (N items)
   - Trivial: [count] (token swaps, value changes)
   - Minor: [count] (small structural tweaks)
   - Major: [count] (significant rework)
3. **Pre-existing inconsistencies** (N items, optional)
   - [Brief list — address if time permits]

Total estimated scope: [N] design changes across [M] screens
```

---

### Important Notes

- **Do NOT implement fixes.** This skill produces a report only. The user decides what to fix and when.
- If a QA agent reports something that looks like a Figma artifact (e.g., auto-layout padding that's clearly a Figma canvas default, not a design intent), note it as "possibly unintentional" rather than a hard discrepancy.
- When the design uses a color value, always try to map it to the project's semantic token system rather than reporting raw hex values.
- If the Figma design appears to be in a different color mode than the implementation (e.g., Figma is light mode, app is dark mode), note this prominently and map colors accordingly.
- **`--live` note**: When using live UI screenshots, agents should capture the screenshot *before* reading the code. This gives an unbiased view of the rendered output. If the live UI clearly differs from what the code suggests (e.g., due to caching, CSS overrides from other files, or runtime state), note the discrepancy between code and rendered output as well — this is valuable context for the user.
- **`--live` cleanup**: The orchestrator is responsible for stopping the dev server background process after all agents have completed.
