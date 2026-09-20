# Contributing to Amgi

Thank you for your interest in contributing. This guide covers how to report
issues, suggest features, and submit code changes.

## Where things are

| You want to | Read |
|---|---|
| Build and run the app, or run the tests | [Documentation/BUILDING.md](Documentation/BUILDING.md) |
| Know how the code is laid out | [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) |
| Write code that matches the project | [Documentation/CODE_STYLE.md](Documentation/CODE_STYLE.md) |
| Surface a new engine method | [Documentation/RUST_BRIDGE.md](Documentation/RUST_BRIDGE.md) |
| Know what the app already does | [Documentation/FEATURES.md](Documentation/FEATURES.md) |

Each package also carries an `AGENTS.md` with the rules that package enforces —
worth reading before your first change there, whether or not you use a coding
agent.

## Reporting bugs

Open a [GitHub Issue](https://github.com/antigluten/amgi/issues/new) with:

- Steps to reproduce
- Expected behavior vs. actual behavior
- iOS version and device/simulator
- Crash logs or screenshots if applicable

## Suggesting features

Open a [GitHub Issue](https://github.com/antigluten/amgi/issues/new) with the
`enhancement` label. Describe the use case and why it would benefit Anki users.

## Branch strategy

- Feature branches off `main`
- Pull requests required for all changes
- PRs should target `main`

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add deck statistics view
fix: correct sync error handling for empty collections
refactor: extract card rendering into separate client
docs: update architecture diagram
test: add unit tests for FSRS scheduling
```

## Pull request guidelines

- Keep PRs focused — one feature or fix per PR
- Include a description of what changed and why
- Add tests for new functionality where possible
- Make sure the simulator test run passes before submitting (see [Documentation/BUILDING.md](Documentation/BUILDING.md#tests))
- Screenshots for UI changes

## Code of conduct

This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating,
you are expected to uphold this code.

## Questions?

Open a [Discussion](https://github.com/antigluten/amgi/discussions) or file an
issue. We are happy to help.
