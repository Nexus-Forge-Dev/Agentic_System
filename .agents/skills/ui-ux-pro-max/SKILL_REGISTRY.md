# ui-ux-pro-max-skill — Skill Registry
# Maps all 7 sub-skills, their SKILL.md entry points, and which agents use them.
# Source: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (cloned, --depth=1)
# Update: git -C .agents/skills/ui-ux-pro-max pull

---

## Sub-Skill Map

| Skill | SKILL.md Path | Primary Agents | Activated By |
|-------|--------------|----------------|-------------|
| **ui-ux-pro-max** (master) | `.claude/skills/ui-ux-pro-max/SKILL.md` | UI Designer, Frontend Developer | All design commands |
| **design** | `.claude/skills/design/SKILL.md` | UI Designer | `/design`, `/design-shotgun` |
| **design-system** | `.claude/skills/design-system/SKILL.md` | Design Systems Engineer | `/design-consultation`, `/design` |
| **ui-styling** | `.claude/skills/ui-styling/SKILL.md` | UI Designer, Frontend Developer | `/design-html`, `/design-review` |
| **brand** | `.claude/skills/brand/SKILL.md` | UI Designer, Design Lead | `/design-consultation` |
| **banner-design** | `.claude/skills/banner-design/SKILL.md` | UI Designer | Marketing asset generation |
| **slides** | `.claude/skills/slides/SKILL.md` | UI Designer | Presentation design |

---

## What Each Skill Contains

### `design` — The Core Design Intelligence Skill
- **161 industry reasoning rules** — matched by product category (spa, SaaS, banking, e-commerce, etc.)
- **67 UI styles** — Glassmorphism, Claymorphism, Minimalism, Brutalism, Bento Grid, etc.
- **Data files:** `cip/industries.csv`, `cip/styles.csv`, `cip/deliverables.csv`
- **Scripts:** `generate.py`, `search.py`, `render-html.py` — active runtime Python scripts
- **Use:** Always inject before any `/design` task to prevent generic "AI slop" output

### `design-system` — Token Architecture
- **Token reference docs** — primitive, semantic, component token hierarchy
- **Scripts:** `generate-tokens.cjs`, `validate-tokens.cjs`, `embed-tokens.cjs`
- **Templates:** `design-tokens-starter.json`
- **Data:** Slide charts, layouts, typography CSV data
- **Use:** When setting up or auditing a project's design token system

### `ui-styling` — 67 Named UI Styles
- **SKILL.md** contains full style definitions and when to use each
- **Canvas fonts** — TTF font files for canvas-based image rendering
- **Use:** When the agent needs to pick a visual style (not industry matching, just aesthetic style)

### `brand` — Brand Identity System
- **References:** Color palette management, typography specs, logo usage rules, visual identity
- **Scripts:** `extract-colors.cjs`, `inject-brand-context.cjs`, `sync-brand-to-tokens.cjs`
- **Use:** When working with an established brand — ensures all AI output respects brand guidelines

### `banner-design` — Banner & Marketing Assets
- **References:** Banner sizes and styles for all major ad platforms
- **Use:** Generating marketing banners, hero images, social media assets

### `slides` — Presentation Design
- **References:** Layout patterns, HTML template, copywriting formulas, strategies
- **Use:** Building presentation slides or deck-style UI layouts

---

## Activation Protocol

When any design-related command runs, the agent reads skills in this order:

```
1. ui-ux-pro-max/SKILL.md     (master context — always first)
2. design/SKILL.md             (industry rules — always for UI tasks)
3. [task-specific sub-skill]   (ui-styling / brand / design-system as needed)
4. design/data/cip/industries.csv  (search for matching industry row)
5. design/data/cip/styles.csv      (match appropriate visual style)
```

**Context optimization:** Only load the matching industry section, not all 161 rules. Use the `search.py` script to retrieve the relevant row by category tag.

---

## Updating the Skill

```powershell
# Pull latest upstream changes
git -C .agents/skills/ui-ux-pro-max pull
```

Run this when upstream releases a new version. Check `CHANGELOG.md` for breaking changes before updating.

---

## Hard Rules When Using This Skill

1. **Industry matching is mandatory** — never generate UI without first matching an industry rule
2. **Anti-patterns are hard blocks** — if the matched rule says "AVOID neon colors", that is not a suggestion
3. **Pre-delivery checklist runs before every output** — no skipping items
4. **No emoji icons** — SVG only (Heroicons or Lucide as specified in the checklist)
5. **Font pairing must come from the 57 curated pairs** — no arbitrary font choices
