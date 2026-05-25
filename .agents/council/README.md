# Council Session Artifacts — Structure Template
# .agents/council/README.md
#
# Every /council run produces a session directory + a permanent verdict file.
#
# Structure:
#
# .agents/council/
# ├── verdicts/
# │   └── <ts>-<question-slug>.md         ← THE permanent verdict (never deleted)
# │
# └── sessions/
#     └── <council-session-id>/
#         ├── evidence_manifest.json        ← all ingested materials + quality tiers
#         ├── positions/
#         │   ├── round1_advocate.md        ← Round 1: Advocate position statement
#         │   ├── round1_skeptic.md         ← Round 1: Skeptic position statement
#         │   ├── round1_devils_advocate.md ← Round 1: Devil's Advocate statement
#         │   ├── round1_domain_expert.md   ← Round 1: Domain Expert statement
#         │   ├── round2_cross_examination.md ← Round 2: All cross-examinations
#         │   └── round3_resolution.md      ← Round 3: (only if disputes ran)
#         └── verdict_ref.md               ← Pointer to verdicts/<ts>-<slug>.md
#
# evidence_manifest.json schema:
# [
#   {
#     "source": "<url or file path>",
#     "type": "URL | PDF | document | code | figma | forum",
#     "tier": 1,
#     "key_claims": ["Claim 1 extracted", "Claim 2 extracted"],
#     "ingested_ts": "<ISO-8601>"
#   }
# ]
#
# Naming conventions:
#   <ts>              = ISO-8601 compact: 20260525T140000Z
#   <question-slug>   = kebab-case of the research question (max 40 chars)
#   <council-session-id> = council_<ulid>
