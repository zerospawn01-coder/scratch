# CI/CD Setup Guide

## GitHub Actions Configuration

This repository includes automated testing via GitHub Actions.

### Setup Instructions

1. **Enable GitHub Actions** (if not already enabled):
   - Go to your repository on GitHub
   - Navigate to Settings → Actions → General
   - Ensure "Allow all actions and reusable workflows" is selected

2. **Verify Workflow File**:
   - The workflow is located at `.github/workflows/test.yml`
   - It runs automatically on push/pull request to main/master/develop branches

3. **View Test Results**:
   - Go to the "Actions" tab in your GitHub repository
   - Click on the latest workflow run
   - View results for each test job

### What Gets Tested

The CI/CD pipeline runs 4 separate test jobs:

1. **aesthetic-resonator**: 17 tests (Score formula, entropy, LEAP/AVE)
2. **post_alignment_lab**: 17 tests (PVL, θ update, meaning divergence)
3. **neuro_symbolic_checker**: 7 tests (Lexeme resolution, P5137)
4. **intuition-layer**: 14 tests (Routing logic, thresholds)

**Total**: 55 tests, expected to pass in < 10 seconds

### Local Testing

Before pushing, run tests locally:

```bash
# Aesthetic-Resonator
cd aesthetic-resonator && python test_leap_score.py

# Post-Alignment Lab
cd post_alignment_lab && python test_post_alignment_phase2.py

# Neuro-Symbolic Checker
cd neuro_symbolic_checker && python test_lexeme_resolver.py

# Intuition-Layer
cd intuition-layer && python test_intuition_router.py
```

### Troubleshooting

**If tests fail in CI but pass locally**:
- Check Python version (CI uses 3.9)
- Verify all dependencies are listed in workflow
- Check for OS-specific issues (CI uses Ubuntu)

**If workflow doesn't trigger**:
- Ensure `.github/workflows/test.yml` is in the repository
- Check branch names match (main/master/develop)
- Verify GitHub Actions is enabled

### Badge (Optional)

Add this to your README.md to show test status:

```markdown
![Tests](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml/badge.svg)
```

Replace `YOUR_USERNAME` and `YOUR_REPO` with your GitHub username and repository name.
