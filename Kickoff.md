Execute Phase 0.3 "Development Environment" per this enhanced protocol:

1. **Pre-Execution Validation**
- Verify SHA-256 checksum of todo.md matches last verified state
- Confirm CONTRIBUTING.md alignment with .roo/config.yaml's CI/CD settings through direct parameter comparison
- Validate task sequence integrity: No line reordering or content drift since Phase 0.2 completion

2. **Task Processing**
- Process unchecked items in strict line-order sequence using RFC 5545 recurrence rules for prioritization
- For each task:
  a. Cross-reference with CONTRIBUTING.md §3.2 (Coding Standards) and §4.1 (PR Guidelines)
  b. Apply .roo/config.yaml path mappings using POSIX.1-2017 compliant substitutions
  c. Generate atomic operation plan with:
     - Pre-operation backup via `tar --anchored --exclude=.roo/checksums -cpf backup_$(date +%s).tar`
     - Dry-run diff output using unified format with 3-line context anchors
     - Dependency graph validation through `renv::hydrate()` and `devtools::check()`

3. **GitHub API Operations**
- Implement branch protections using strictly typed JSON payloads:
  ```shell
  gh api -X PUT repos/{owner}/{repo}/branches/main/protection --input - <<EOF
  {
    "required_status_checks": {
      "strict": $(jq '.ci_cd.require_strict_status' .roo/config.yaml),
      "contexts": $(jq -c '.ci_cd.required_checks | map(.name)' .roo/config.yaml)
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "dismiss_stale_reviews": $(jq '.code_review.auto_dismiss' .roo/config.yaml),
      "required_approving_review_count": $(jq '.code_review.min_approvals' .roo/config.yaml)
    },
    "restrictions": null
  }
  EOF
  ```
- Escape JSON special characters using \uXXXX notation for Zsh/GH CLI compatibility

4. **Conflict Resolution**
- Duplicate tasks: Mark earliest occurrence complete via `sed -i '' '${LINE}s/\[ \]/[x]/' todo.md` after checksum verification
- File conflicts: Use `git merge-file --diff3 --ours` with .roo/config's conflict_resolution matrix

5. **Post-Execution**
- Generate machine-readable report containing:
  - Task completion matrix (CSV format)
  - Environment delta report via `diff -ruN --label BEFORE --label AFTER pre.env post.env`
  - Compliance checklist against CONTRIBUTING.md §7.3
- Update todo.md with:
  `[x] $(date -u +%FT%TZ) $(git rev-parse --short HEAD)`
  using BSD date/GNU coreutils compatibility layer

6. **Failure Protocols**
- Halt on non-zero exit code with:
  `trap 'echo "ERR:$(jq -n --arg cmd "$BASH_COMMAND" --arg lno "$LINENO" '\''{error: $cmd, line: $lno, stack: $(stack)}'\'')" >&2' ERR`
- Preserve failed state using `tar --exclude='*.tar' -czf crashdump_$(date +%s)_${RANDOM}.tgz`

7. **State Transition**
- Initiate Phase 0.4 only after:
  `[ $(git diff --name-only HEAD~1 | grep -c '^\.roo/') -gt 0 ] && make validate-config`
  returns 0 exit status
