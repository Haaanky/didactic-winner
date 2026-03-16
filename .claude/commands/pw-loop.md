# /pw-loop — Schedule recurring Playwright iteration

Schedule a recurring Playwright test loop that keeps iterating until the game
meets the SRS requirements defined in `scripts/playwright_iterate.js`.

## What to do

1. Make sure the local game server is running (or use the GitHub Pages URL).
2. Call CronCreate with:
   - cron: `*/30 * * * *`  (every 30 minutes)
   - prompt: `Run GAME_URL=http://localhost:8080 node scripts/playwright_iterate.js and report which SRS requirements are failing. For each failing test, read the relevant game script, identify the root cause, fix it, run the GUT tests headless, then re-run the Playwright suite. Commit and push any fixes to branch claude/complete-game-implementation-wqF1i.`
   - recurring: true
3. Confirm the job ID so it can be cancelled later with CronDelete.

If CronCreate is not available (Agent SDK environment), fall back to the GitHub
Actions scheduled workflow at `.github/workflows/playwright-iterate.yml` which
runs on the same 30-minute cadence automatically once merged to main.
