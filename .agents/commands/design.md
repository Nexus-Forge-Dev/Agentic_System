# Command: /design
# .agents/commands/design.md
# Owner: Design Lead → UI Designer → Design Systems Engineer → Engineering Lead → Frontend Developer
# Trigger: /design "<component or screen description>"

---

## Purpose
Full design-to-code pipeline: industry match → visual style selection →
component spec → design token generation → HTML/CSS/JSX implementation →
visual QA loop until pixel-perfect.

---

## Workflow

```
INPUT: Component or screen description

STEP 1 — Design Lead: Industry Match (mandatory)
  Identify the product's industry from PROJECT.md or user input:
    e.g. fintech, healthtech, SaaS, e-commerce, developer tool, social, gaming
  Select the matching rule set from ui-ux-pro-max/design/SKILL.md (161 rules)
  Select visual style from ui-ux-pro-max/ui-styling/SKILL.md (67 named styles)
  Confirm selection with user if not obvious

STEP 2 — UI Designer: Design Brief
  Produce a design brief document:
    - Component name and purpose
    - Visual style selected (with reference to style name in ui-styling)
    - Color palette: primary, accent, surface, background, error, success
    - Typography: display font + body font (from curated pairs)
    - States: default, hover, active, focus, disabled, loading, error
    - Responsive behavior: 375px / 768px / 1280px
    - Animation: entrance, interaction, exit (durations from design rules)
    - Accessibility: WCAG AA minimum (contrast ratios, focus rings, ARIA)

STEP 3 — Design Systems Engineer: Token Generation
  Run ui-ux-pro-max/design-system/ scripts for token generation
  Output: CSS custom property tokens file at src/design-tokens/<component>.css
  Token naming: --color-{scale}-{step}, --space-{n}, --radius-{size}

STEP 4 — Frontend Developer: Implementation (/design-html)
  Read design brief + generated tokens
  Implement component as HTML/CSS (or JSX + CSS Modules or Tailwind)
  Implement all states (hover, focus, disabled, loading, error)
  Make responsive at all 3 breakpoints
  Add ARIA attributes and keyboard navigation
  Start local dev server for Visual QA

STEP 5 — Visual QA Specialist: /design-review loop
  Screenshot component at 375px, 768px, 1280px
  Compare against design brief spec (if Figma frame exists, compare against it)
  Apply targeted CSS fixes for any delta > 2%
  Loop until delta < 2% at all viewports

STEP 6 — Design Lead: Final approval
  Confirm ui-ux-pro-max pre-delivery checklist passed
  Forward to Orchestrator: Result Message { status: "APPROVED", artifacts: [...] }
```

---

## Output Artifacts
- `src/design-tokens/<component>.css` — generated CSS tokens
- `src/components/<Component>/<Component>.tsx` — implementation
- `.agents/reports/visual-<ts>.md` — Visual QA report

---

## Guardrails
- Industry match happens BEFORE any visual work — never skip
- No implementation before design brief is written
- Visual QA loop always runs — no "looks good to me" without screenshots
