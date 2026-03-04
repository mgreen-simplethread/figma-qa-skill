---
name: figma-qa-component
description: Run a component-level Figma QA audit on a single screen. Use when the user wants to zoom in on specific components and compare rendered DOM elements against their Figma counterparts using CSS selectors. Requires a running or startable dev server.
disable-model-invocation: true
user-invocable: true
argument-hint: --template=TEMPLATE_PATH [--base-url=URL] [--max-agents=N] <newline> FIGMA_NODE_URL -> CSS_SELECTOR ...
---

# Figma Component QA Audit

You are an orchestrator that runs a parallel component-level design-vs-implementation audit on a single screen. Each component mapping pairs a Figma node with a CSS selector in the live DOM. Your job is to coordinate sub-agents that each audit one component, then synthesize their findings into a single actionable report.

## Arguments

Parse `$ARGUMENTS` for:
- `--template=TEMPLATE_PATH` (required): The entrypoint file for the screen being audited (e.g., `src/pages/Dashboard.tsx`)
- `--base-url=URL` (optional): The URL where this screen is accessible (e.g., `http://localhost:3000/dashboard`). If omitted, the skill will attempt to infer the route or ask the user.
- `--max-agents=N`: Max parallel QA agents (default: 10)

Following the flags, expect one or more component mappings, one per line:
```
FIGMA_NODE_URL -> CSS_SELECTOR
FIGMA_NODE_URL -> CSS_SELECTOR
```

Example:
```
/figma-qa-component --template=src/pages/Dashboard.tsx --base-url=http://localhost:3000/dashboard
https://figma.com/design/abc123/MyApp?node-id=42:100 -> .sidebar-nav
https://figma.com/design/abc123/MyApp?node-id=42:200 -> .metrics-grid
https://figma.com/design/abc123/MyApp?node-id=42:300 -> header .user-menu
```

If no mappings are provided, ask the user for them.

## Orchestration Workflow

### Phase 1: Gather Project Context

Before spawning any QA agents, build a **shared context brief** that every agent will receive.

1. **Read project docs**: Check for `CLAUDE.md` and/or `METHODOLOGY.md` in the project root. Extract:
   - Tech stack (framework, templating language, styling approach)
   - Component patterns (component libraries, utility class systems, design tokens)
   - File structure conventions (where templates/components live)

2. **If project docs are thin or missing**, launch an **Explore agent** to:
   - Identify the tech stack from package.json, requirements.txt, Gemfile, etc.
   - Find the styling approach (Tailwind config, CSS modules, styled-components, theme files)
   - Locate design token definitions (CSS custom properties, theme files, token JSON)
   - Map the component/template directory structure

3. **If anything is still unclear**, ask the user. Key things you must know:
   - What styling system is used (Tailwind, CSS modules, etc.)
   - Whether there's a design token / semantic color system
   - Whether the app uses light mode, dark mode, or both
   - Where template/component files live

4. **Compose the context brief** — a concise block of text prepended to every QA agent's prompt. Include:
   - Tech stack summary
   - Styling approach and key utility classes or token mappings
   - Any color mode mapping notes
   - Component patterns the agent should be aware of

### Phase 2: Dev Server & Browser Setup

A live browser is **required** for this skill — every agent needs to evaluate CSS selectors against the rendered DOM.

1. **Determine the dev server command.** Check (in order):
   - `CLAUDE.md` for an explicit dev server command
   - `README.md` for the same
   - `Procfile.dev` — can be started with `overmind` if available
   - `script/dev` if this is a Rails application
   - `package.json` scripts for `dev`, `start`, `serve`
   - Framework-specific conventions (e.g., `next dev`, `vite`, `rails server`)
   - If ambiguous, ask the user

2. **Start the dev server** in a background shell. Wait for it to be ready (watch for "ready on", "listening on", or similar output). Record the local URL.

3. **Determine the screen URL.** Use `--base-url` if provided. Otherwise:
   - If the project uses file-based routing, infer the route from `--template` path
   - Check for a router config file
   - If you can't determine it, ask the user

4. **Verify browser access.** Navigate to the screen URL using Chrome DevTools MCP (`navigate_page`) and confirm it loads. Take a test screenshot. Request local login info if you encounter a login form.

5. **Validate all CSS selectors.** Run a quick script via `evaluate_script` to confirm every selector matches at least one element:
   ```js
   () => {
     const selectors = [/* all selectors from mappings */];
     return selectors.map(s => ({
       selector: s,
       count: document.querySelectorAll(s).length
     }));
   }
   ```
   If any selector matches zero elements, warn the user and ask whether to skip it or provide a corrected selector. If a selector matches multiple elements, note it — the agent will audit all matches.

### Phase 3: Map Components to Source Code

Launch a **single Explore agent** to trace from the screen entrypoint (`--template`) and find the source file for each component targeted by a CSS selector.

Give the agent:
- The screen entrypoint file path
- The list of CSS selectors and a brief description of what each targets (inferred from the selector or the Figma node name)
- Instructions to trace imports, follow component references, and identify which source file renders each selector's DOM element

The agent should return a mapping like:
```
.sidebar-nav -> src/components/SidebarNav.tsx
.metrics-grid -> src/components/dashboard/MetricsGrid.tsx
header .user-menu -> src/components/layout/UserMenu.tsx
```

If the agent can't confidently map a selector, flag it and ask the user.

### Phase 4: Spawn QA Agents

For each component mapping (up to `--max-agents` in parallel, default 10), launch a **general-purpose Task agent** with the prompt below.

```
You are auditing a single UI component: "{component_description}"
on the screen "{screen_name}" ({screen_url}).

## Project Context
{context_brief_from_phase_1}

## Your Mapping
- Figma node: {figma_node_id} (from URL: {figma_node_url})
- CSS selector: `{css_selector}`
- Source file: {component_source_file}
- Screen entrypoint: {screen_entrypoint}

## Your Task

### Step 1 — Capture the rendered component
1. Navigate to {screen_url} using `navigate_page` (if not already there)
2. Use `evaluate_script` to check `document.querySelectorAll('{css_selector}')` and confirm the element(s) exist
3. Use `take_screenshot` with the uid of the element matching `{css_selector}` to capture the rendered component
4. Use `take_snapshot` to get the a11y tree for structural comparison

### Step 2 — Extract Figma design spec
1. Use `get_design_context` on Figma node {figma_node_id} to get the full design specification
2. Use `get_screenshot` on Figma node {figma_node_id} for visual reference
3. If the design context lacks detail on a specific child element, use `get_metadata` to find its node ID, then `get_design_context` on that child

### Step 3 — Read the source code
1. Read the component source file: {component_source_file}
2. If the component imports sub-components relevant to the discrepancy, read those too
3. If needed, also read the screen entrypoint ({screen_entrypoint}) for prop-passing context

### Step 4 — Compare and report
Compare the rendered component + source code against the Figma design spec. Report ALL discrepancies in the format below.

## What to Look For
- **Spacing**: padding, margin, gap values
- **Typography**: font size, weight, line-height, letter-spacing
- **Colors**: text colors, backgrounds, borders, icon colors (map to project's token system)
- **Border radius**: rounded corners
- **Layout**: flex/grid structure, alignment, sizing
- **Component states**: hover, focus, active, disabled, checked, error states
- **Missing elements**: icons, labels, decorative elements present in design but missing in code
- **Extra elements**: things in code that aren't in the design
- **Content/text**: placeholder text, labels, or copy that differ between design and implementation

**IMPORTANT — Exact tokens, not prose**: When reporting Design values, quote the raw token or CSS values directly from `get_design_context` output. Do NOT paraphrase. Example:
- GOOD: `padding: 4px`, `border-radius: 8px`, `font-size: 14px / line-height: 20px`, `color: #1E1E1E`
- BAD: "small padding", "slightly rounded corners", "medium-sized text", "dark text color"

## Report Format
For each discrepancy, report:
- **Figma node**: the node ID of the specific element (e.g., `123:456`)
- **Location**: file path + line number
- **Element**: what the discrepancy is on
- **Design**: exact token/CSS values from `get_design_context`
- **Rendered**: what the live UI shows (from screenshot/snapshot)
- **Code**: what the implementation has in source
- **Suggested fix**: the specific code change needed

Group findings by severity:
1. **Visual**: clearly visible differences a user would notice
2. **Subtle**: minor spacing/sizing differences
3. **Structural**: layout or component structure differences

If the rendered output differs from what the source code suggests (e.g., due to CSS overrides, inherited styles, or runtime state), note this as a separate observation — it's valuable debugging context.
```

If you have more mappings than `--max-agents`, batch them.

### Phase 5: Synthesize Report

Once all agents have reported back, produce a single structured report.

#### 1. Cross-Component Issues
Look across all component reports for **repeated patterns** — the same type of discrepancy appearing in multiple components. These indicate a shared style, token, or base component that needs fixing once.

Format:
```
### Cross-Component Issues (fix once, applies to multiple components)

1. **[Description]**
   - Figma nodes: [node IDs]
   - Affected components: [list with selectors]
   - Fix location: [shared file/class/token]
   - Design: [exact token/CSS values]
   - Code: [what's implemented]
   - Suggested fix: [specific change]
```

#### 2. Per-Component Issues
Issues unique to a single component.

Format:
```
### Component: [description] (`CSS_SELECTOR`)

1. **[Element] — [Description]**
   - Figma node: [node ID]
   - Location: [file:line]
   - Design: [exact token/CSS values]
   - Rendered: [what the live UI shows]
   - Code: [what's implemented]
   - Suggested fix: [specific change]
```

#### 3. Rendered vs. Source Discrepancies
If any agent found cases where the rendered output doesn't match what the source code implies (CSS overrides, inherited styles, runtime transformations), list them separately. These may indicate issues outside the component's own source file.

Format:
```
### Rendered vs. Source Discrepancies

1. **[Component] — [Description]**
   - Selector: [CSS selector]
   - Source says: [what the code has]
   - Browser shows: [what actually renders]
   - Likely cause: [CSS override / inherited style / runtime state / etc.]
```

#### 4. Summary Stats
```
### Summary
- Components audited: N
- Cross-component issues: N
- Per-component issues: N
- Rendered vs. source discrepancies: N
- Recommended fix order: cross-component first, then per-component
```

---

### Important Notes

- **Do NOT implement fixes.** This skill produces a report only. The user decides what to fix and when.
- If a discrepancy looks like a Figma artifact (e.g., auto-layout padding that's a canvas default, not design intent), note it as "possibly unintentional" rather than a hard finding.
- When the design uses a color value, always try to map it to the project's semantic token system rather than reporting raw hex values.
- If the Figma design appears to be in a different color mode than the implementation, note this prominently and map colors accordingly.
- **Selector matching multiple elements**: If `querySelectorAll` returns multiple matches, the agent should audit the first match and note how many total matches exist. If the elements differ from each other (e.g., list items with different content), note that as well.
- **Cleanup**: The orchestrator is responsible for stopping the dev server background process after all agents have completed.
