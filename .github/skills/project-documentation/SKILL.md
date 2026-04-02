---
name: project-documentation
description: "Project documentation and reporting patterns for Aurix. Use when: writing bug reports, error documentation, changelogs, incident reports, decision records, or organizing project documents."
---

# Project Documentation for Aurix

## When to Use
- Documenting a bug or error encountered during development
- Writing incident or post-mortem reports
- Creating changelogs or release notes
- Maintaining decision records (ADRs)
- Organizing and indexing project documents

## Document Types

### Bug Report (`docs/bugs/BUG-{number}.md`)
```markdown
# BUG-{number}: {Short Title}

- **Status**: open | investigating | fixed | closed
- **Severity**: critical | high | medium | low
- **Component**: auth | wallet | transactions | etl | frontend | devops
- **Discovered**: {date}
- **Fixed**: {date or N/A}
- **Fixed In**: {commit hash or PR}

## Description
{What is the bug?}

## Steps to Reproduce
1. {Step 1}
2. {Step 2}

## Expected Behavior
{What should happen}

## Actual Behavior
{What actually happens}

## Root Cause
{Why it happened — fill in after investigation}

## Fix
{How it was fixed — fill in after resolution}

## Impact
{What was affected — users, data, services}
```

### Error Documentation (`docs/errors/{error_code}.md`)
```markdown
# Error: {error_code}

- **HTTP Status**: {status}
- **Component**: {which service returns this}
- **Since**: {version or date}

## When This Occurs
{Conditions that trigger this error}

## Response Body
{Example JSON response}

## Resolution
{Steps to fix from the user or operator perspective}

## Related Errors
{Links to related error codes}
```

### Incident Report (`docs/incidents/INC-{number}.md`)
```markdown
# INC-{number}: {Title}

- **Date**: {date}
- **Duration**: {how long}
- **Severity**: P1 | P2 | P3 | P4
- **Status**: resolved | monitoring

## Summary
{One-paragraph summary}

## Timeline
| Time | Event |
|------|-------|
| {time} | {what happened} |

## Root Cause
{Technical root cause}

## Resolution
{What was done to fix it}

## Lessons Learned
{What to improve to prevent recurrence}

## Action Items
- [ ] {Action 1}
- [ ] {Action 2}
```

### Architecture Decision Record (`docs/decisions/ADR-{number}.md`)
```markdown
# ADR-{number}: {Decision Title}

- **Date**: {date}
- **Status**: proposed | accepted | deprecated | superseded

## Context
{What is the issue or decision needed?}

## Decision
{What was decided}

## Consequences
{Positive and negative outcomes}

## Alternatives Considered
{What else was evaluated and why it was rejected}
```

### Changelog (`docs/CHANGELOG.md`)
```markdown
## [{version}] - {date}

### Added
- {New feature}

### Changed
- {Modified behavior}

### Fixed
- {Bug fix with BUG reference}

### Security
- {Security-related change}
```

## Directory Structure
```
docs/
├── bugs/              # Bug reports
├── errors/            # Error code documentation
├── incidents/         # Incident/post-mortem reports
├── decisions/         # Architecture Decision Records
├── CHANGELOG.md       # Release changelog
├── API_DESIGN.md      # (existing)
├── DATABASE_SCHEMA.md # (existing)
└── ...
```

## Naming Conventions
- Bug reports: `BUG-001.md`, `BUG-002.md` (sequential)
- Incidents: `INC-001.md`, `INC-002.md` (sequential)
- Decisions: `ADR-001.md`, `ADR-002.md` (sequential)
- Error docs: `{error_code}.md` matching API error codes

## Auto-Generated Index
When creating new documents, update the relevant index file (e.g., `docs/bugs/INDEX.md`) with a link and one-line summary.
