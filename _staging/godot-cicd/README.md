# godot-cicd

Reusable GitHub Actions workflows for Godot 4 projects.

## Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `godot-export-deploy.yml` | `workflow_call` | Export to Web + deploy to GitHub Pages + run E2E tests |
| `godot-preview.yml` | `workflow_call` | Build preview for `claude/**` branches, post link to PR |
| `godot-preview-cleanup.yml` | `workflow_call` | Remove preview directory when PR is closed |
| `playwright-iterate.yml` | `workflow_call` | Scheduled E2E testing, auto-open/close issues on failure |

## Usage in your project

Copy the workflow files from `workflow-templates/` into your game repo's `.github/workflows/` directory and adjust the inputs.

**Example `.github/workflows/deploy.yml` in your game repo:**

```yaml
name: Export, Deploy and E2E Test

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

env:
  GODOT_VERSION: "4.6.1"
  GODOT_RELEASE: "stable"

jobs:
  export:
    name: Export and Deploy
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    # ... (copy from workflow-templates/godot-export-deploy.yml and fill in your GAME_URL)
```

Or copy the file directly:

```bash
mkdir -p .github/workflows
cp path/to/godot-cicd/workflow-templates/godot-export-deploy.yml .github/workflows/deploy.yml
# Edit the file to set your GAME_URL and GODOT_VERSION
```

## E2E tests

The `tests/e2e/game.test.js` file is a template for Playwright tests against a Godot WebAssembly export.
Copy it to your project's `tests/playwright/` directory and adapt it to your game's specific UI and interactions.

The test file reads `GAME_URL` from the environment — no hardcoded URLs.

## Directory structure

```
godot-cicd/
├── workflow-templates/
│   ├── godot-export-deploy.yml    # copy to .github/workflows/ in your game repo
│   ├── godot-preview.yml
│   ├── godot-preview-cleanup.yml
│   └── playwright-iterate.yml
├── tests/
│   └── e2e/
│       └── game.test.js           # template — copy to your project
├── config/
│   ├── playwright.config.js       # template — copy to your project
│   └── package.json               # template — copy to your project
├── .gitignore
└── README.md
```
