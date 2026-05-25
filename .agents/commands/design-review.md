# Command: /design-review
# .agents/commands/design-review.md
# Owner: Visual QA Specialist
# Trigger: /design-review — runs after /design completes

## Purpose
Screenshot live component at 3 viewports, compare against design brief / Figma frame,
apply targeted CSS fixes in a loop until delta < 2%.

## Workflow
```
STEP 1 — Start dev server (if not running)
STEP 2 — Screenshot at 375px, 768px, 1280px
  Save: .agents/screenshots/<commit>-<component>-<viewport>-<ts>.png

STEP 3 — Compare against reference
  If Figma frame available: compare pixel-by-pixel against exported Figma PNG
  If no Figma: compare against design brief spec (interpret spacing, colors, typography)
  Calculate delta % for each viewport

STEP 4 — If delta > 2%
  Identify specific CSS properties causing delta (spacing, color, font-size, etc.)
  Apply targeted CSS fix (minimum viable change)
  Return to Step 2 (loop, max 5 iterations)

STEP 5 — If delta <= 2% at all viewports, or max iterations reached
  Write: .agents/reports/visual-<ts>.md
  Contents: before/after screenshots, delta per viewport, fix list applied, verdict

STEP 6 — Report
  Return Result Message to Design Lead: { status: delta < 2% ? "PASS" : "REVIEW_NEEDED" }
```

## Guardrails
- Baselines updated DELIBERATELY only — never auto-update silently
- Max 5 loop iterations — if delta still > 2% after 5, surface to Design Lead for manual review
