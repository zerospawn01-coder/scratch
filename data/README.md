# Scratch Data

This directory is local-only by default.

The current file, `theoretical_predictions.npz`, is treated as generated numeric
output rather than a promoted repository asset.

## Rule

Do not move files from this directory into a destination repository unless all
of the following are true:

1. the generating workflow is documented
2. the owning repository is identified
3. the file is meant to be versioned rather than regenerated locally

Until then, `data/` should remain outside the split repositories.

