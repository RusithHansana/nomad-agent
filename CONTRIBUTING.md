# Contributing to NomadAgent

First off, thank you for considering contributing to NomadAgent! It's people like you that make NomadAgent such a great tool. We welcome contributions from everyone.

By participating in this project, you agree to abide by our [Code of Conduct](./CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to see if the problem has already been reported. If you find an open issue that matches your problem, you can leave a comment with any additional information you have.

When you are creating a bug report, please include as many details as possible:

- Use a clear and descriptive title for the issue to identify the problem.
- Describe the exact steps which reproduce the problem in as much detail as possible.
- Describe the behavior you observed after following the steps and point out what exactly is the problem with that behavior.
- Explain which behavior you expected to see instead and why.
- Include screenshots or animated GIFs if applicable.
- Note your OS, Flutter/Python version, device model (if mobile), and any other relevant environment details.

### Suggesting Enhancements

If you have an idea for a new feature or an improvement to an existing one, please create an issue with the following information:

- Use a clear and descriptive title for the issue to identify the suggestion.
- Provide a step-by-step description of the suggested enhancement in as much detail as possible.
- Explain why this enhancement would be useful to most users.
- List any alternative solutions or features you've considered.

### Pull Requests

We actively welcome your pull requests.

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints correctly.
6. Issue that pull request!

## Development Setup

Please refer to the [Getting Started](README.md#getting-started) section in our README for instructions on how to set up the project locally.

## Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes and commit them (see [Commit Messages](#commit-messages) below)
4. Push to your fork: `git push origin feature/your-feature-name`
5. Open a Pull Request against `main`

### Branch Naming Convention

Use the following prefixes for branch names:

- `feature/` — New features or enhancements
- `fix/` — Bug fixes
- `docs/` — Documentation changes
- `refactor/` — Code refactoring
- `test/` — Adding or updating tests

## Coding Standards

This project uses the following tools to maintain code quality:

### Backend (Python)

- **Linter & Formatter:** [Ruff](https://docs.astral.sh/ruff/) (line length: 100, Python 3.10 target)
- **Testing:** [Pytest](https://docs.pytest.org/) with async support (`pytest-asyncio`)
- **Type Checking:** Python type hints (enforced via Pydantic models)

Before submitting a PR, ensure your backend code passes all checks:

```bash
cd api
ruff check src/ tests/
ruff format --check src/ tests/
pytest
```

### Frontend (Flutter)

- **Linter:** [flutter_lints](https://pub.dev/packages/flutter_lints) (configured in `analysis_options.yaml`)
- **Formatter:** `dart format`

Before submitting a PR, ensure your Flutter code passes all checks:

```bash
cd app
dart analyze
dart format --set-exit-if-changed lib/
flutter test
```

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/).

Format: `<type>(<optional scope>): <description>`

Examples:

- `feat(agent): add hybrid relevance scoring to researcher node`
- `fix(extractor): resolve venue deduplication merging stale coordinates`
- `docs(readme): add architecture diagram and API reference table`
- `refactor(streaming): replace list-length deltas with monotonic cursor buffer`
- `test(compiler): add test cases for tiered venue verification scoring`
- `chore(deps): bump langchain-google-genai to v4.3.0`
- `feat(app): implement PDF export with share sheet integration`

## Code Review Process

All submissions, including those by project members, require review. We use GitHub pull requests for this purpose. Consult [GitHub Help](https://help.github.com/articles/about-pull-requests/) for more information on using pull requests.

### What we look for:

- **Correctness** — Does the code do what it's supposed to do?
- **Tests** — Are there adequate tests? Do they pass?
- **Style** — Does the code follow the project's coding standards (Ruff for Python, flutter_lints for Dart)?
- **Documentation** — Are any new features or changes documented?
- **Performance** — Are there any obvious performance concerns, especially in the agent pipeline?
- **Streaming safety** — Do changes to event handling preserve bounded buffer semantics?

## Recognition

Contributors who make significant contributions will be recognized in our README under the Acknowledgements section. We value every contribution, no matter how small!

---

Thank you for contributing! 🎉
