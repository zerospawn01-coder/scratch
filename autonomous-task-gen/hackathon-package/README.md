# Autonomous Task Gen Hackathon Package

This directory is a standalone package candidate and should be treated as the
seed of a future dedicated repository rather than a permanent `scratch`
subdirectory.

## Current Role

- Governance-heavy autonomous task generation package
- Includes promotion, rollback, throughput, alerting, and playbook logic
- Organized around TypeScript source under `src/`

## Source Layout

- `src/services/`
  - core service and orchestration logic
- `src/tests/`
  - test surface for the package
- `src/types/`
  - shared contracts and domain types

## What Should Move With This Package

Keep when splitting to a dedicated repo:

- `src/services/`
- `src/tests/`
- `src/types/`
- a future package manifest
- a future build/test configuration

Do not treat these as durable source assets:

- `dist/`
- `node_modules/`
- `out*.txt`
- `test_output.txt`

## Split Guidance

Before promoting this package into its own repository:

1. add a real package manifest (`package.json`)
2. add a reproducible install/build/test entrypoint
3. confirm which generated outputs should remain local-only
4. move only source, tests, and intentional documentation into the new repo

