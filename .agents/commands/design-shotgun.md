# Command: /design-shotgun
# .agents/commands/design-shotgun.md
# Owner: UI Designer
# Trigger: /design-shotgun "<component description>"

## Purpose
Generate 3 visually distinct alternatives for a component using 3 different
named styles from ui-ux-pro-max/ui-styling. Present as a gallery for user selection.

## Workflow
```
STEP 1 — Identify industry and 3 candidate styles
  Identify product industry (from PROJECT.md or user input)
  Select 3 named styles from ui-ux-pro-max/ui-styling/SKILL.md that:
    - All match the industry appropriately
    - Are visually distinct from each other (not variations of the same theme)
  Examples: Glassmorphism | Neomorphism | Brutalist

STEP 2 — Generate 3 implementations
  For each style:
    - Apply the named style's rules to the component
    - Generate HTML/CSS implementation
    - Screenshot the result

STEP 3 — Present gallery
  Show all 3 side by side with:
    - Style name
    - Key visual characteristics
    - When to use this style (industry fit notes)

STEP 4 — User selects
  Wait for user to pick one (or describe modifications)
  Proceed with /design workflow using selected style
```
