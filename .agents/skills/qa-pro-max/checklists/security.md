# Security Testing Checklist
# .agents/skills/qa-pro-max/checklists/security.md
#
# Used by: security-engineer, sdet
# Activated by: /review, /e2e, /pipeline-audit

---

## AUTH & SESSION SECURITY

```
□ JWT signature tampered → 401 (payload with valid structure but bad sig = rejected)
□ JWT algorithm confusion attack:
    RS256 token validated as HS256 using public key → rejected
    Algorithm field in header locked server-side (not taken from token)
□ JWT "none" algorithm attack: token with alg: "none" → rejected
□ Token replay after logout:
    Token invalidated server-side (blacklist or session store)
    Replaying post-logout token → 401
□ Concurrent session limit enforced (if configured):
    Exceeding limit → oldest session invalidated
□ Refresh token rotation:
    Old refresh token invalid after use (one-time use)
    Refresh token theft detection (reuse of rotated token → revoke all sessions)
□ Password reset tokens:
    Single-use only (second use → 401)
    Expire within configured window (e.g., 15 minutes)
    Scoped to specific account (cannot reset different account's password)
```

---

## INJECTION SURFACES

```
□ SQL injection — test at every string input that reaches DB queries:
    Classic: ' OR '1'='1; --
    UNION: ' UNION SELECT username, password FROM users--
    Stacked: '; DROP TABLE users; --
    Assert: application returns 400 or sanitized result — NOT DB data or 500

□ NoSQL injection (if applicable):
    MongoDB operator injection: { "$where": "..." }
    Assert: operator treated as literal string, not executed

□ HTML/XSS injection — test in API responses rendered in UI:
    Stored: submit <script>alert(document.cookie)</script> via API → retrieve via UI
    Reflected: URL parameter echoed in response without encoding
    Assert: output is HTML-encoded, script does not execute

□ Path traversal — test in any file or resource path parameter:
    ../../../../etc/passwd
    ..%2F..%2F..%2Fetc%2Fpasswd (URL encoded)
    Assert: 400 or 404, never file system contents

□ Command injection — test in any input passed to shell commands:
    ; ls -la
    | cat /etc/passwd
    Assert: input treated as data, never executed

□ SSRF (Server-Side Request Forgery) — test in URL input fields:
    http://169.254.169.254/latest/meta-data (AWS metadata endpoint)
    http://localhost/admin
    Assert: blocked by allowlist or rejected with 400
```

---

## SECRETS & DATA EXPOSURE

```
□ No secrets in logs:
    API keys, tokens, passwords, PII not visible in any log output
    Log scrubbing verified by reviewing actual log output during test runs
□ No stack traces in API error responses (any environment):
    Trigger a server error deliberately → assert no stack trace in body
□ No internal infrastructure details in responses:
    No internal hostnames, IP addresses, or ports
    No DB connection strings or schema details
    No internal service names or routes
□ OAuth tokens stored encrypted at rest:
    Never plaintext in DB column
    Never logged
    Never returned to client after initial exchange
□ Sensitive fields in API responses:
    Passwords: never returned (not even hashed)
    Full card numbers: never returned (masked if returned)
    SSN/PII: masked or excluded from responses not requiring them
□ Secrets in code: pre-commit hook verified (no hardcoded API keys/passwords)
□ .env files: excluded from git (.gitignore verified)
```

---

## RATE LIMITING & BRUTE FORCE PREVENTION

```
□ Auth endpoints rate-limited:
    login, password-reset, token-refresh, OTP-verify
    Retry-After header present on 429
    Rate limit window and threshold documented in PROJECT.md
□ Brute force simulation:
    100 rapid login attempts → account protection triggered
    (Lockout, CAPTCHA, or Retry-After — per project design)
□ Distributed rate limiting:
    Rate limit works across multiple service instances
    Redis-backed counter (not in-memory per-instance)
    Verified by hitting different instances with same IP/user
□ Rate limit bypass attempts:
    X-Forwarded-For spoofing rejected or sanitized
    Rate limit keyed on authenticated user ID (not just IP for authenticated routes)
```

---

## ACCESS CONTROL

```
□ IDOR (Insecure Direct Object Reference):
    Resource ID in URL: user A cannot access /users/[user-B-id]
    Resource ID in body: user A cannot modify resource owned by user B
    Tested for all resource types (not just primary resources)
□ Privilege escalation:
    Regular user cannot call admin-only endpoints
    Modifying role field in request body rejected (server-side role assignment only)
□ Mass assignment:
    Sending extra fields (e.g., role: "admin") in request body → ignored
    is_admin, role, tenant_id in request body → ignored
□ Function-level access control:
    All administrative functions tested with non-admin token → 403
□ Horizontal access control (same role, different resource):
    User A cannot read User A's colleague's private data
```

---

## DEPENDENCY & STATIC ANALYSIS

```
□ SARIF report generated for every pipeline run
□ Critical/High severity SAST findings block protected branch merges
□ Dependency audit: zero known critical CVEs in any deployed dependency
□ License compliance: all dependency licenses acceptable per project policy
□ Container image scan (if applicable):
    Zero critical CVEs in base image
    Running as non-root user
    No secrets embedded in image layers
□ Outdated dependencies: Medium+ severity advisories tracked and scheduled for patch
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never skip auth boundary tests citing "it's covered in unit tests"
❌ Never commit secrets to repo — not in tests, fixtures, or comments
❌ Never use real PII (names, emails, SSNs, phone numbers) in test data
    Use synthetic data generators (faker, chance, etc.)
❌ Never ignore SAST/SCA findings without explicit documented exception
❌ Never use production OAuth credentials in test environments
❌ Never trust client-supplied role, tenant, or admin fields — always server-side
```
