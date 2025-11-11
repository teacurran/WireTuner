# Contributing to WireTuner

Thank you for your interest in contributing to WireTuner! This document provides guidelines and workflows for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Architecture Decision Records (ADRs)](#architecture-decision-records-adrs)
5. [Code Standards](#code-standards)
6. [Testing Requirements](#testing-requirements)
7. [Pull Request Process](#pull-request-process)
8. [Documentation](#documentation)

---

## Code of Conduct

WireTuner is committed to fostering an inclusive and respectful community. All contributors are expected to:

- Be respectful and considerate in communications
- Welcome diverse perspectives and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the project and community

---

## Getting Started

### Prerequisites

- **Dart SDK**: 3.0.0 or later
- **Flutter**: 3.10.0 or later
- **Melos**: For monorepo management (`dart pub global activate melos`)
- **Git**: For version control

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/wiretuner/wiretuner.git
cd wiretuner

# Bootstrap the monorepo
melos bootstrap

# Run tests to verify setup
melos run test
```

---

## Development Workflow

### Branch Strategy

- **main**: Production-ready code, protected branch
- **develop**: Integration branch for features (if using GitFlow)
- **feature/**: Feature branches (`feature/add-gradient-support`)
- **bugfix/**: Bug fix branches (`bugfix/fix-path-rendering`)
- **docs/**: Documentation-only changes (`docs/update-adr-template`)

### Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring without behavior change
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, build config)
- `perf`: Performance improvements

**Example**:
```
feat(undo): add configurable undo depth limits

Implement three undo modes (default, extended, unlimited) with memory
thresholds and warning toasts. Addresses power-user workflows requiring
deep history while protecting against memory bloat.

Closes #142
Refs ADR-0004
```

---

## Architecture Decision Records (ADRs)

### What are ADRs?

Architecture Decision Records (ADRs) document significant architectural decisions, their context, rationale, and consequences. ADRs provide:

- **Traceability**: Link decisions to requirements and implementation
- **Knowledge Sharing**: Onboard new team members with decision context
- **Change Management**: Track architectural evolution over time

### When to Write an ADR

Create an ADR when making decisions about:

- **Core Architecture**: Event sourcing, state management, persistence strategies
- **Technology Choices**: Databases, frameworks, libraries with project-wide impact
- **Cross-Cutting Concerns**: Security, performance, scalability patterns
- **API Contracts**: Public APIs, file formats, network protocols
- **Controversial Decisions**: Choices with significant trade-offs or team disagreement

**Do NOT write ADRs for**:
- Minor implementation details (function naming, local refactoring)
- Temporary workarounds or experiments
- Decisions easily reversible without cross-cutting impact

### ADR Workflow

#### 1. Proposal Phase

**Check for Existing ADRs**:
```bash
# Search for related ADRs
grep -r "keyword" docs/adr/

# Review ADR index (if available)
cat docs/adr/README.md
```

**Create ADR from Template**:
```bash
# Copy template
cp docs/adr/template.md docs/adr/ADR-00XX-descriptive-name.md

# Edit with your content
# See template.md for structure guidance
```

**ADR Numbering Convention**:
- Use zero-padded format: `ADR-0001`, `ADR-0002`, etc.
- Increment from highest existing number
- Check current highest: `ls docs/adr/ADR-*.md | sort | tail -1`

#### 2. Content Requirements

**Required Sections** (see `docs/adr/template.md`):

1. **Anchor Comment**: `<!-- anchor: adr-XXX-descriptive-name -->`
2. **Title**: `# XXX. [Descriptive Title]`
3. **Metadata**: Status, Date, Deciders
4. **Context**: Problem, requirements, constraints
5. **Decision**: What was decided (active voice)
6. **Rationale**: Why this decision (most important section)
7. **Consequences**: Positive, negative, mitigations
8. **Alternatives Considered**: Rejected options with rationale
9. **References**: Links to requirements, tasks, implementation

**Traceability Requirements**:
- **Requirement IDs**: Reference FR-XXX, NFR-XXX from specifications
- **Task IDs**: Reference IX.TY from iteration plans
- **Related ADRs**: Cross-link to ADR-XXX documents
- **Implementation**: File paths and line numbers for key code

**Example Reference Section**:
```markdown
## References

- **FR-042**: Unlimited undo/redo requirement (`.codemachine/inputs/specifications.md#fr-042`)
- **Architecture Blueprint Section 1.4**: Undo depth assumptions (`docs/architecture/02_System_Structure_and_Data.md#key-assumptions`)
- **Task I4.T3**: Undo UI implementation (`.codemachine/artifacts/plan/02_Iteration_I4.md#task-i4-t3`)
- **ADR-003**: Event Sourcing Architecture (`docs/adr/003-event-sourcing-architecture.md`)
- **Implementation**: `packages/app_shell/lib/src/undo/undo_navigator.dart:42-67`
```

#### 3. Review Process

**Required Reviewers** (by decision scope):

| Decision Type | Required Reviewers | Approval Count |
|--------------|-------------------|----------------|
| Core Architecture | Lead Architect + Tech Lead | 2 |
| Package-Level | Package Owner + 1 Peer | 2 |
| Documentation-Only | 1 Team Member | 1 |
| Breaking Changes | Lead Architect + Product Owner | 2 |

**Review Checklist**:
- [ ] ADR follows template structure
- [ ] All required sections present and complete
- [ ] Decision clearly stated in active voice
- [ ] Rationale explains "why" not just "what"
- [ ] Alternatives considered with rejection rationale
- [ ] References include FR/NFR IDs and task IDs
- [ ] Anchor comment present for deep linking
- [ ] No spelling or grammar errors
- [ ] Consequences section includes mitigations

**Submitting for Review**:
```bash
# Create feature branch
git checkout -b docs/adr-0042-undo-depth

# Add ADR file
git add docs/adr/ADR-0042-undo-depth.md

# Commit with ADR reference
git commit -m "docs(adr): add ADR-0042 for undo depth configuration

Proposes configurable undo depth with default 100-op limit,
extended 500-op mode, and unlimited mode with memory warnings.

Refs #142"

# Push and create PR
git push -u origin docs/adr-0042-undo-depth
gh pr create --title "docs(adr): ADR-0042 Undo Depth Configuration" \
  --body "Proposes undo depth policy with three modes. See ADR for details."
```

#### 4. Status Lifecycle

**ADR Status Values**:

- **Proposed**: Under review, not yet accepted
- **Accepted**: Approved and implemented (or being implemented)
- **Deprecated**: No longer recommended, superseded by newer decision
- **Superseded by ADR-YYY**: Replaced by specific newer ADR

**Status Transitions**:
```
Proposed ──review──> Accepted
            │
            └──reject──> [Delete or archive]

Accepted ──evolve──> Deprecated / Superseded by ADR-YYY
```

**Updating Status**:
```markdown
<!-- Update metadata block -->
**Status:** Deprecated (Superseded by ADR-0123)
**Date:** 2025-11-15  <!-- Original date -->
**Deprecated Date:** 2025-12-01  <!-- New field -->
```

#### 5. Post-Acceptance Process

**After ADR Acceptance**:

1. **Update Status**: Change `Proposed` → `Accepted` in ADR
2. **Link Implementation**: Add file paths and line numbers to References section
3. **Update Documentation**: Reflect decision in README, architecture docs
4. **Create Tasks**: Generate implementation tasks in iteration plans (if needed)
5. **Notify Team**: Announce in team channel/meeting with ADR link

**Implementation Traceability**:
```dart
// In code, reference ADR in comments where applicable
/// Undo depth enforcement per ADR-0004.
/// See docs/adr/ADR-0004-undo-depth.md for rationale.
class UndoNavigator {
  void enforceDepthLimit(UndoConfiguration config) {
    // Implementation...
  }
}
```

---

## Code Standards

### Style Guide

WireTuner follows the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

**Key Points**:
- Use `dart format` before committing
- Maximum line length: 120 characters (configured in `analysis_options.yaml`)
- Prefer `const` constructors where possible
- Use trailing commas for multi-line parameter lists

### Architecture Principles

**Clean Architecture Layers** (see Architecture Blueprint):

```
┌────────────────────────────────────┐
│  Presentation (UI, Widgets)        │
├────────────────────────────────────┤
│  Application (Use Cases, Services) │
├────────────────────────────────────┤
│  Domain (Entities, Events)         │  ← Dependency direction: inward only
├────────────────────────────────────┤
│  Infrastructure (Persistence, I/O) │
└────────────────────────────────────┘
```

**Dependency Rules**:
- **Domain** depends on nothing (pure business logic)
- **Application** depends on Domain only
- **Presentation** depends on Application and Domain
- **Infrastructure** depends on Domain (implements domain interfaces)

**Violations Will Be Rejected**:
- ❌ Domain importing Flutter widgets
- ❌ Domain importing `dart:io` or `dart:html`
- ❌ Application importing Presentation

### Immutability

All domain models MUST be immutable using `freezed`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'document.freezed.dart';

@freezed
class Document with _$Document {
  const factory Document({
    required String id,
    required String title,
    required List<Path> paths,
  }) = _Document;
}
```

---

## Testing Requirements

### Coverage Requirements

| Package Type | Minimum Coverage | Enforcement |
|-------------|------------------|-------------|
| Domain | 90% | Blocking |
| Application | 80% | Blocking |
| Infrastructure | 70% | Warning |
| Presentation | 60% | Warning |

**Check Coverage**:
```bash
# Run tests with coverage
melos run coverage

# View HTML report
open coverage/html/index.html
```

### Test Types

**Unit Tests** (required for all non-trivial functions):
```dart
// test/domain/entities/document_test.dart
void main() {
  group('Document', () {
    test('creates document with valid properties', () {
      final doc = Document(id: '123', title: 'Test', paths: []);
      expect(doc.id, '123');
      expect(doc.title, 'Test');
    });
  });
}
```

**Integration Tests** (required for critical workflows):
```dart
// test/integration/undo_redo_test.dart
void main() {
  testWidgets('undo/redo workflow with 100 operations', (tester) async {
    // Test end-to-end undo/redo behavior
  });
}
```

**Golden Tests** (required for visual components):
```dart
// test/golden/toolbar_test.dart
void main() {
  testWidgets('toolbar renders correctly', (tester) async {
    await tester.pumpWidget(Toolbar());
    await expectLater(find.byType(Toolbar), matchesGoldenFile('toolbar.png'));
  });
}
```

---

## Pull Request Process

### Before Submitting

**Pre-Flight Checklist**:
- [ ] All tests pass locally (`melos run test`)
- [ ] Code formatted (`dart format .`)
- [ ] No linter warnings (`melos run analyze`)
- [ ] Coverage meets minimum thresholds
- [ ] Documentation updated (README, ADRs, inline comments)
- [ ] Commit messages follow Conventional Commits

### PR Template

**Title Format**: `<type>(<scope>): <description>`

**Description Template**:
```markdown
## Summary
[Brief description of changes]

## Motivation
[Why is this change needed? Link to issue/task]

## Changes
- [Bullet list of key changes]
- [Include file paths for major modifications]

## Testing
- [Describe testing performed]
- [Link to test coverage report if applicable]

## References
- Closes #XXX
- Refs ADR-YYYY
- Related to Task IX.TY
```

### Review Process

**Automated Checks** (must pass):
- ✅ All tests pass
- ✅ Code coverage meets thresholds
- ✅ Linter warnings resolved
- ✅ No merge conflicts with `main`

**Manual Review**:
- At least 1 approving review from team member
- For breaking changes or ADRs: 2 approving reviews (see ADR Review Process)

**Merge Strategy**:
- **Squash and Merge**: For feature branches (default)
- **Rebase and Merge**: For clean, atomic commits
- **Merge Commit**: For release branches only

---

## Documentation

### Required Documentation

**Code-Level Documentation**:
- Public APIs MUST have DartDoc comments
- Complex algorithms SHOULD have inline explanation comments
- ADR references in code where applicable

**Package-Level Documentation**:
- Each package MUST have README.md with:
  - Purpose and scope
  - Usage examples
  - API overview
  - Testing instructions

**Architecture Documentation**:
- Keep `docs/diagrams/` PlantUML files up to date with code
- Update Architecture Blueprint when making structural changes
- Create ADRs for significant architectural decisions

### Documentation Standards

**DartDoc Style**:
```dart
/// Applies undo depth limit based on configuration.
///
/// When the undo stack exceeds the configured depth limit, the oldest
/// operations are truncated (but remain in the event log). This prevents
/// unbounded memory growth in long editing sessions.
///
/// Example:
/// ```dart
/// final config = UndoConfiguration(mode: UndoMode.default_);
/// navigator.enforceDepthLimit(config);
/// ```
///
/// See ADR-0004 for rationale on depth limits and memory thresholds.
void enforceDepthLimit(UndoConfiguration config);
```

---

## Questions or Issues?

- **GitHub Issues**: https://github.com/wiretuner/wiretuner/issues
- **Discussions**: https://github.com/wiretuner/wiretuner/discussions
- **Slack/Discord**: [Link to team communication channel]

Thank you for contributing to WireTuner! 🎨
