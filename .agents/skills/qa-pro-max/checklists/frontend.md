# Frontend Layer Testing Checklist
# .agents/skills/qa-pro-max/checklists/frontend.md
#
# Used by: visual-qa-specialist, qa-automation-engineer, frontend-developer
# Activated by: /e2e, /qa, /qa-only, /design-review

---

## USER FLOW COMPLETENESS

```
□ Full user journey tested end-to-end (not just individual component states)
□ All navigation transitions validated (forward, back, deep link, refresh)
□ Form submission: valid data ✅ | invalid data ✅ | partial data ✅ | empty ✅
□ Error states visible in UI — not just HTTP error codes received
□ Loading states present and dismissible (skeleton, spinner, progress)
□ Empty states have content — no blank white screens, no undefined rendering
□ Success states confirmed (toast, redirect, data update — not just no error)
□ Destructive actions require confirmation (delete, logout, cancel subscription)
```

---

## BROWSER STATE CONSISTENCY

```
□ Session persistence verified across page reload (token survives refresh)
□ Local storage and session storage written and read correctly
□ Cookie attributes verified: httpOnly ✅ | secure ✅ | SameSite ✅
□ No broken network requests in console (zero 4xx/5xx on expected flows)
□ No uncaught JavaScript exceptions in console
□ No hydration mismatch errors (React SSR/client mismatch)
□ Back button behavior: navigates to correct state, does not re-submit forms
□ Multi-tab: session changes in one tab reflected correctly in another (or not — per spec)
```

---

## ACCESSIBILITY (WCAG AA MINIMUM — NON-NEGOTIABLE)

```
□ All interactive elements reachable via keyboard Tab navigation
□ Tab order is logical (follows visual reading order)
□ Focus states visible on ALL focusable elements (not just default browser outline)
□ Color contrast ratio ≥ 4.5:1 for normal text
□ Color contrast ratio ≥ 3:1 for large text (≥ 18pt or 14pt bold)
□ All images: meaningful alt text for informational images, alt="" for decorative
□ Form inputs have associated <label> (not just placeholder text)
□ Error messages linked to inputs via aria-describedby
□ Heading hierarchy is logical: h1 → h2 → h3 (no skips, one h1 per page)
□ prefers-reduced-motion: all CSS transitions/animations respect it
□ Screen reader: landmark regions present (main, nav, header, footer)
□ Modal dialogs: focus trapped inside when open, returns to trigger on close
□ Dynamic content changes: aria-live regions used for async updates
```

---

## VISUAL REGRESSION

```
□ Baseline screenshots captured BEFORE the change being tested
□ Visual delta threshold: FAIL if > 2% pixel difference on any critical component
□ Screenshot path: /artifacts/screenshots/<commit>-<component>-<timestamp>.png
□ Baselines updated ONLY with explicit human acknowledgment — never auto-updated by agent
□ Dark mode: tested if project supports it (not just light mode baseline)
□ High DPI (2x/3x): tested for icon and image sharpness
```

---

## SELECTOR STANDARDS

```
□ All test selectors use data-testid attributes ONLY
□ NO CSS class selectors (they change during styling refactors)
□ NO XPath selectors
□ NO visible text string matching for interactive elements (use data-testid)
□ data-testid values are stable, descriptive, and unique per page
□ Naming convention: data-testid="<feature>-<element>-<variant>"
  Examples: data-testid="auth-login-submit-btn"
            data-testid="user-profile-email-input"
            data-testid="nav-settings-link"
```

---

## RESPONSIVE BEHAVIOR

```
□ Breakpoints tested: 375px (mobile) | 768px (tablet) | 1024px (laptop) | 1440px (desktop)
□ No horizontal scroll at any breakpoint
□ Touch targets ≥ 44px × 44px on mobile viewports
□ Images do not overflow their containers at any breakpoint
□ Text does not overflow or truncate incorrectly at narrow widths
□ Tables: horizontal scroll or responsive layout on mobile (not broken overflow)
```

---

## PERFORMANCE (BROWSER-LEVEL)

```
□ Core Web Vitals measured on critical user-facing pages:
    LCP (Largest Contentful Paint): < 2.5s
    CLS (Cumulative Layout Shift): < 0.1
    INP (Interaction to Next Paint): < 200ms
□ Network waterfall reviewed for blocking resources
□ No render-blocking scripts in <head> without async/defer
□ Images: WebP format, lazy loading on below-fold images
□ Critical path CSS inlined or loaded early
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never assert on CSS class names — they change during refactors
❌ Never assert only on HTTP response codes for user flow validation
❌ Never ignore console errors — log them explicitly and decide: allow or fix
❌ Never mock the router — test with real navigation and real URL changes
❌ Never skip accessibility checks citing "we'll fix it later"
❌ Never auto-update visual regression baselines — human must acknowledge delta
❌ Never test only at one viewport width — responsive is not optional
```
