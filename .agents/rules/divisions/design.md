# Design Division Rules
# .agents/rules/divisions/design.md
# AUTHORITY: LAYER 3 — Division-level constraints.
# Read by: Design Lead + all Design specialists at session start.

---

## Hard Design Rules (cannot be overridden by PROJECT.md)

### Pre-Design Requirements
- No component implementation begins without a reviewed design brief or Figma frame
- Industry matching is MANDATORY before any design generation — identify the product's
  industry (fintech, healthtech, SaaS, e-commerce, etc.) before selecting visual style
- The ui-ux-pro-max pre-delivery checklist must pass before any design is handed to Engineering

### Typography
- No arbitrary font choices — fonts must come from the approved curated pairs in ui-ux-pro-max
- Font pairing: one display font + one body font maximum per project (override in PROJECT.md)
- System fonts (`-apple-system`, `BlinkMacSystemFont`) are not acceptable for premium products

### Color & Visual Style
- No generic colors (plain red #FF0000, plain blue #0000FF, plain green #00FF00)
- Colors must come from a curated HSL-based palette with at least 5 tonal steps
- Dark mode variants are REQUIRED unless PROJECT.md explicitly opts out with justification
- All interactive elements must have visible focus states (accessibility requirement, not optional)

### Components
- All components must be responsive by default — no fixed-width desktop-only components
- Animation durations: micro (100-200ms), transition (200-400ms), entrance (300-600ms)
- Hover/active states required on all interactive elements
- No placeholder content (Lorem Ipsum, generic stock photos) in deliverables

### Design System
- New design tokens must follow the naming convention: `--color-{scale}-{step}`, `--space-{n}`, `--radius-{size}`
- Token files are the single source of truth — no hardcoded values in component styles
- Component variants are defined in token space, not as separate component files

---

## Design Division Guardrails (Tier 2)

Enforced by Design Lead before accepting specialist output:
- Industry was identified and matched before any visual generation
- ui-ux-pro-max pre-delivery checklist was run and passed
- No arbitrary fonts — from approved pairs only
- All components are responsive
- Dark mode variants exist (unless PROJECT.md opts out)

---

## ui-ux-pro-max Integration

The system uses the `ui-ux-pro-max` skill suite located at `.agents/skills/ui-ux-pro-max/`.
Before any design task, the Design Lead activates the appropriate sub-skill:

| Task Type | Sub-Skill to Activate |
|-----------|----------------------|
| New product/brand design | `brand/SKILL.md` |
| UI component design | `design/SKILL.md` (161 industry rules) |
| Design system tokens | `design-system/SKILL.md` |
| Visual styling direction | `ui-styling/SKILL.md` (67 named styles) |
| UI implementation (HTML/CSS) | (Design Systems Engineer executes) |
| Presentation slides | `slides/SKILL.md` |
| Banner/marketing assets | `banner-design/SKILL.md` |
