# Deferred Items — Phase 68

## Pre-existing Issues (out of scope)

### Non-ASCII characters in creel-connect-yaml.R (Phase 67 issue)

**File:** `tidycreel.connect/R/creel-connect-yaml.R`
**Lines:** 40, 125, 142
**Issue:** Em-dashes (`—`) in comments trigger R CMD check WARNING:
  "Found the following file with non-ASCII characters"
**Introduced in:** Phase 67 Plan 01 (commit 06919f3)
**Fix:** Replace em-dash characters with ASCII equivalent (`--`) or `\u2014`
**Impact:** devtools::check(cran = FALSE) exits with 1 WARNING
**Priority:** Low — comments only, no behavioral impact; CRAN submission not planned for v1.3.0
