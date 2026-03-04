# Figma QA Skills

Claude Code skills for comparing implemented UI against Figma designs. Two skills at different zoom levels — run the screen-level audit first to get the big picture, then zoom into specific components that need closer inspection.

## Skills

### `figma-qa` — Screen-level audit
**Skill file:** `figma-qa-screen/SKILL.md`

Runs parallel design-vs-implementation audits across multiple screens. Point it at a Figma page or frame URL and it automatically discovers screens, maps them to your code files, then spawns parallel agents that each compare one screen's implementation against the Figma design. Results are synthesized into a single structured report with cross-cutting issues, per-screen findings, and suggested fixes.

Supports two modes:
- **QA mode** (default): Consistency check — catches subtle drift like wrong spacing, mismatched colors, or missing states.
- **Revision mode**: For when a designer has updated the Figma and your code needs to catch up. Classifies findings as design changes vs. pre-existing inconsistencies and produces a prioritized implementation plan.

Both modes can optionally capture Figma screenshots, live browser screenshots (via Chrome DevTools MCP), or both.

```
# Basic QA audit
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200

# With live UI screenshots
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --live

# Revision mode — designer updated the Figma
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --mode=revision --screenshots --live

# Explicit screen-to-file mappings
/figma-qa --mode=revision
https://www.figma.com/design/abc123/MyApp?node-id=5-100 -> src/pages/Dashboard.tsx
https://www.figma.com/design/abc123/MyApp?node-id=5-200 -> src/pages/Settings.tsx
```

### `figma-qa-component` — Component-level audit
**Skill file:** `figma-qa-component/SKILL.md`

Zoomed-in QA for specific components on a single screen. Maps individual Figma nodes to CSS selectors, evaluates them against the live DOM via Chrome DevTools MCP, and compares both the rendered output and source code against the Figma design spec. QA-only — designed for fixing inaccuracies surfaced by the screen-level audit.

Requires a running or startable dev server (the skill handles startup/teardown).

```
# Audit specific components on the dashboard
/figma-qa-component --template=src/pages/Dashboard.tsx --base-url=http://localhost:3000/dashboard
https://figma.com/design/abc123/MyApp?node-id=42:100 -> .sidebar-nav
https://figma.com/design/abc123/MyApp?node-id=42:200 -> .metrics-grid
https://figma.com/design/abc123/MyApp?node-id=42:300 -> header .user-menu
```

## Installation

Copy or symlink the skill files into your project's `.claude/skills/` directory:

```bash
# Screen-level skill
cp figma-qa-screen/SKILL.md /path/to/your-project/.claude/skills/figma-qa.md

# Component-level skill
cp figma-qa-component/SKILL.md /path/to/your-project/.claude/skills/figma-qa-component.md
```

Both skills require the [Figma Desktop MCP server](https://www.npmjs.com/package/@anthropic-ai/claude-code-figma-mcp) to be configured. The component-level skill additionally requires the [Chrome DevTools MCP server](https://www.npmjs.com/package/@anthropic-ai/chrome-devtools-mcp).
