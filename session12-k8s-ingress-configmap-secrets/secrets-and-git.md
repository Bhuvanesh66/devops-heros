# Why Secrets Should Not Be Committed to Git (Session 12, Task 2)

**Name:** Bhuvanesh M S
**Enrollment number:** 24bcs10134

Part 2 of the [main README](README.md#part-2--secrets) ends with the rule "never commit a
Secret manifest to git". This document explains why, what to do instead, and what to do if it
has already happened.

> **About this repo.** `02-secret.yaml` in this folder **is** committed, on purpose, because the
> homework is to show how a Secret manifest works. Its values (`yatri_admin`,
> `S3cr3t-P@ssw0rd`, `api-key-1234567890`) are **deliberately fake** and are not used anywhere
> real. The same goes for the self-signed `tls.key` from Part 3, which I generated locally and
> did not commit.

---

## 1. base64 is encoding, not encryption

A Secret manifest *looks* protected because the values under `data:` are unreadable at a
glance. They are not protected at all:

```
$ echo 'UzNjcjN0LVBAc3N3MHJk' | base64 -d
S3cr3t-P@ssw0rd
```

No key, no password, one standard command. base64 exists so that binary data can sit in a
JSON/YAML string field. And with `stringData:` the value is not even encoded; it is plain text
in the file. So **committing a Secret manifest is exactly the same as committing the password
in plain text**.

## 2. Git history is permanent

Deleting the file in the next commit does not remove it:

```bash
git log --all --oneline -- 02-secret.yaml     # every commit that touched it
git show <old-commit>:path/to/02-secret.yaml  # the old content, still there
```

- Every commit is part of the history that **every clone** downloads. Each developer laptop,
  CI runner cache and backup holds a full copy.
- **Forks** keep their own copy of the history, and on GitHub you cannot rewrite someone
  else's fork.
- Rewriting history (`git filter-repo`, BFG) changes **your** repository and needs a force
  push, but it cannot reach copies that already exist elsewhere. Hosting platforms can also
  keep old commits reachable by SHA or through pull-request refs for some time.

So once a secret has been pushed, the only safe assumption is: **it is public, permanently**.

## 3. Public repositories are scanned within minutes

Automated scanners watch the public GitHub event stream and pull every new commit looking for
keys (AWS access keys, cloud tokens, database URLs, private keys). Leaked cloud credentials are
commonly reported to be abused **within minutes** of the push, typically for crypto-mining on
the victim's account. The instructor's Secret notes quote a real case of a key found by a bot
in 7 minutes. Making the repository private afterwards does not help either: the scanners
already have the commit.

Private repositories are not safe storage for secrets either. Everyone with read access (and
every integration, CI system and future collaborator) gets the history.

## 4. After a leak, rotation is the only real fix

| Step | Why |
| ---- | --- |
| 1. **Revoke / rotate the credential immediately** at its source (database user, cloud key, API token) | This is the step that actually stops abuse. Everything else is cleanup |
| 2. Update the real Secret in the cluster with the new value and restart the consumers | Env-var consumers only read it at start; file mounts update but the app must re-read |
| 3. Check the provider's logs for use of the old credential | Find out whether it was already used |
| 4. Remove it from the repository history (`git filter-repo`) and force-push | Reduces further exposure, but **does not undo** the leak |
| 5. Add scanning so it cannot happen again (section 6) | Prevention |

Removing the file from history **without rotating** is the common mistake: the old value is
still valid and still in somebody's clone.

## 5. What to commit instead

The pattern is always the same: **git holds a reference or an encrypted blob, never the
plain value**, and something inside the cluster turns it into a normal Secret.

| Approach | What goes in git | How the real Secret is produced | Good fit |
| -------- | ---------------- | -------------------------------- | -------- |
| **Sealed Secrets** (Bitnami) | A `SealedSecret` encrypted with the cluster controller's **public** key (`kubeseal`) | The controller in the cluster decrypts it with its private key and creates the Secret | GitOps, small teams, no cloud secret manager |
| **External Secrets Operator** | An `ExternalSecret` that only **names** the secret (e.g. `prod/db/password`) and a `SecretStore` | The operator reads the value from **AWS Secrets Manager, GCP Secret Manager, Azure Key Vault or HashiCorp Vault** and keeps the Secret in sync (including rotation) | Production on a cloud; secrets managed centrally |
| **SOPS** | The YAML with **values encrypted** (keys stay readable for review), using age, PGP or a cloud KMS key | Decrypted at deploy time (Flux supports it natively; Argo CD and Helm via plugins) | GitOps where encrypted files in git are acceptable |
| **Secrets Store CSI Driver** | A `SecretProviderClass` reference | Mounts the value from the external store straight into the Pod as a file | When you want to avoid a Kubernetes Secret object at all |
| **CI/CD secret store** | Nothing; the pipeline references a variable | GitHub Actions secrets, Azure DevOps variable groups (optionally linked to Azure Key Vault), GitLab CI variables; the pipeline runs `kubectl create secret ... --from-literal` at deploy time | Simple pipelines; matches the instructor's `azure-pipelines.yml` example, which reads `POSTGRES_USER1` from the `dev1` variable group |

All of them still end in a normal Kubernetes Secret (or a mounted file), so the Pod spec does
not change. That is the point made in Part 2 of the README: the Secret is the **interface**,
not the security boundary. Encryption at rest for etcd (`EncryptionConfiguration`, or a KMS
provider) and tight RBAC on `get secrets` are still needed on the cluster side.

## 6. Prevention: `.gitignore` and pre-commit secret scanning

**`.gitignore`** stops the obvious files from ever being staged:

```gitignore
# local secrets and keys
.env
.env.*
*.key
*.pem
*.p12
*-secret.local.yaml
```

**A pre-commit hook** catches what `.gitignore` cannot (a password pasted into a normal YAML
file). Gitleaks ships a hook for the `pre-commit` framework:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1          # the version my session 17 pipeline uses
    hooks:
      - id: gitleaks
```

```bash
pip install pre-commit
pre-commit install        # now runs on every git commit
```

Hooks run on the developer's machine and can be skipped, so the same scanner should run again
in CI, where it cannot be skipped. I already do this in
[session 17](../session17-devsecops-pipeline/README.md): the Gitleaks stage scans the files and
the git history, and the security gate fails the pipeline on **any** finding. GitHub's own
secret scanning and push protection add one more layer on hosted repositories.

## Summary

- base64 is not protection; a committed Secret manifest is a committed plain-text password.
- Git history is copied to every clone and fork and cannot be reliably erased.
- Public commits are scanned by bots within minutes.
- After a leak, **rotate first**; history rewriting is only cleanup.
- Commit references or encrypted blobs (Sealed Secrets, External Secrets Operator, SOPS), or
  inject from the CI secret store, and enforce it with `.gitignore`, a Gitleaks pre-commit hook
  and a Gitleaks stage in CI.
