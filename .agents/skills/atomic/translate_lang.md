# Atomic Skill: translate_lang
# .agents/skills/atomic/translate_lang.md
# Type: Primitive — General Utility
# Source: agents_and_skills_design.md §8.3

---

## Purpose

Translates **human language text** (not code) between languages.
Used primarily by the Research Council when processing foreign-language papers, documentation, or community discussions.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | string | ✅ | The text to translate |
| `from` | string | ✅ | Source language code (e.g., `zh`, `de`, `ja`, `fr`) or `auto` for auto-detect |
| `to` | string | ✅ | Target language code (e.g., `en`) |

## Output

Translated text string in the target language.

## Behavior

- Detects source language automatically if `from: "auto"`
- Preserves: paragraph breaks, list formatting, heading markers
- Does NOT translate: code blocks, URLs, technical terms with established English names
- If uncertain about a term translation: preserves original + adds `[original: term]`

## Permission Tier

Tier 1 — Auto-approved. Pure text transformation.

## Primary Use Cases

| Use Case | Context |
|----------|---------|
| Research Council reading foreign-language papers | `/council` command |
| Processing forum discussions in other languages | `crawl_site` results |
| Reading vendor documentation in non-English | `browse_url` results |
| Foreign-language community feedback analysis | Research tasks |

## NOT For Code Translation

This skill does NOT translate between programming languages (e.g., Python → TypeScript).
For code translation, use the implementation skills or simply describe the desired behavior.
