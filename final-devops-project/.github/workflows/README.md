# Where the pipeline lives

GitHub Actions only runs workflow files from the repository root, so the real
pipeline is:

**[`/.github/workflows/final-devops-project.yml`](../../../.github/workflows/final-devops-project.yml)**

`final-devops-project.yml` in this folder is a read-only mirror, kept so the
project folder is self-contained for grading. GitHub never runs it from here.
Always edit the root file, then copy it over:

```bash
# from the repository root
{ echo "# mirror of /.github/workflows/final-devops-project.yml - edit the original, not this copy"; \
  cat .github/workflows/final-devops-project.yml; } > final-devops-project/.github/workflows/final-devops-project.yml
```

It triggers on pushes and pull requests to `main` that touch
`final-devops-project/**` or the workflow file, and on manual
`workflow_dispatch` runs.
