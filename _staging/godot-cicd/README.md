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

In your game repo's `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: Haaanky/godot-cicd/.github/workflows/godot-export-deploy.yml@main
    with:
      godot_version: "4.6.1"
      game_url: "https://your-username.github.io/your-repo/"
    secrets: inherit
    permissions:
      contents: read
      pages: write
      id-token: write
```

In your game repo's `.github/workflows/preview.yml`:

```yaml
name: Branch Preview

on:
  push:
    branches: ["claude/**"]

jobs:
  preview:
    uses: Haaanky/godot-cicd/.github/workflows/godot-preview.yml@main
    with:
      godot_version: "4.6.1"
    secrets: inherit
    permissions:
      contents: write
      pull-requests: write
```

## E2E tests

The `tests/e2e/game.test.js` file is a template for Playwright tests against a Godot WebAssembly export.
Copy it to your project's `tests/playwright/` directory and adapt it to your game's specific UI and interactions.

The test file reads `GAME_URL` from the environment — no hardcoded URLs.

## Directory structure

```
godot-cicd/
├── .github/
│   └── workflows/
│       ├── godot-export-deploy.yml
│       ├── godot-preview.yml
│       ├── godot-preview-cleanup.yml
│       └── playwright-iterate.yml
├── tests/
│   └── e2e/
│       └── game.test.js           # template — copy to your project
├── config/
│   ├── playwright.config.js       # template — copy to your project
│   └── package.json               # template — copy to your project
├── docs/
│   └── README.md
├── .gitignore
└── README.md
```
