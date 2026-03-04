# figma-qa

A Claude Code skill that runs parallel design-vs-implementation audits across multiple screens. Point it at a Figma page or frame URL and it automatically discovers screens, maps them to your code files, then spawns parallel agents that each compare one screen's implementation against the Figma design. The results are synthesized into a single structured report with cross-cutting issues, per-screen findings, and suggested fixes.

The skill supports two modes. **QA mode** (default) is a consistency check — it assumes your implementation should already be close to the design and focuses on catching subtle drift like wrong spacing, mismatched colors, or missing states. **Revision mode** is for when a designer has updated the Figma and your code needs to catch up. It assumes significant intentional differences, classifies each finding as a design change vs. pre-existing inconsistency, rates implementation effort, and produces a prioritized implementation plan. Both modes can optionally capture Figma screenshots, live browser screenshots of the running app (via Chrome DevTools MCP), or both for a three-way comparison.

## Usage Examples

Basic QA audit (default mode, code-only):
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200
```

QA with Figma screenshots for visual reference:
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --screenshots
```

QA with live UI screenshots (spins up dev server, captures browser):
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --live
```

Full QA with both Figma and live screenshots (three-way comparison — Figma design, rendered UI, code):
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --screenshots --live
```

Revision mode — designer updated the Figma, need an implementation plan:
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --mode=revision
```

Revision mode with everything on — the full picture:
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --mode=revision --screenshots --live
```

Explicit screen-to-file mappings (skip auto-discovery):
```
/figma-qa --mode=revision
https://www.figma.com/design/abc123/MyApp?node-id=5-100 -> src/pages/Dashboard.tsx
https://www.figma.com/design/abc123/MyApp?node-id=5-200 -> src/pages/Settings.tsx
```

Limit parallelism (useful on resource-constrained machines or large audits):
```
/figma-qa https://www.figma.com/design/abc123/MyApp?node-id=1-200 --mode=revision --max-agents=3
```
