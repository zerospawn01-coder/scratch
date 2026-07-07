# CRISIS ACTOR

Godot port of the `crisis-actor-rules-&-session-simulator` zip.

## What is included
- role / phase / noise / incident / blackout data
- dice-pool simulation
- card workshop
- administrative report editor with forbidden-word replacement
- audit log

## Run
Open `project.godot` in Godot 4.7 or newer and press Play.

## Test & CI
This project uses automated tests to guarantee the integrity of core VTT mechanics.

Install dependencies and run linting/testing:
```bash
npm run lint
npm run build
npm test
```

### Guaranteed Mechanics (Test Specifications)
1. **Scenario Presets Loader**: Correctly loads and switches scenario presets (EP2 / EP3). Re-initializes cards, resets counters (audit debt, budget, conspiracy clock), and maps dynamic clock stage names (e.g. `未招集` for EP2, `未分類` for EP3).
2. **Session Flow Controller**: Manages 7 phases progression (`Setup` -> `Debrief`). Automatically increments the conspiracy clock upon entering `Phase 3` and `Phase 4 / Climax` with audit trail log records.
3. **Card Lifecycle Actions**: Verifies card creation, deletion, and enforces strict transition validation (e.g. Grey cards can only become White/Black; Black cards can only become Investigation/Protected/Classification; other illegal transitions are safely rejected with fail logs).
4. **Safety Kernel**: Enforces the execution of Safety Checks, Audit Pauses, and a single Emergency Injunction (which converts a Black card to Protected and decreases Audit Debt by 1).
5. **Multi-Ending & Markdown Exporter**: Saves session logs locally to `user://session_log.md` and copies them to the clipboard. Validates the generated Markdown structure, metadata, final counters state, safety counters, endings, and complete audit trail logs concluding with a `SESSION_CLOSED` event.
6. **Scenario-specific Forbidden Words**: Auto-replaces custom forbidden words based on the loaded scenario (e.g., replaces "祟り" and "人身御供" with "地域資源" and "円滑な合意形成" respectively when scenario EP3 is loaded).

## Source reference
The source zip was extracted into `crisis_actor_zip_extract/` during project setup and used to seed the Godot data tables and UI copy.

