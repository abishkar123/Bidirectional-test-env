# Bidirectional — Infrastructure & CI/CD Reference

## Azure Resources

| Resource | Name | Type |
|---|---|---|
| Resource Group | `rg-bidirectional-dev-app` | Resource Group |
| App Service Plan | `plan-app-bidirectional-dev-api` | Standard S1 |
| App Service | `app-bidirectional-dev-api` | Windows |
| Staging Slot | `app-bidirectional-dev-api/staging` | Deployment Slot |
| Key Vault | `kv-bidirectional-dev` | RBAC-enabled |
| Storage Account | `stbidirectionalaudit` | Standard LRS |
| Log Analytics | `law-bidirectional-dev` | PerGB2018, 90d retention |
| Application Insights | `appi-bidirectional-dev` | Workspace-based |
| Action Group | `ag-bidirectional-dev-oncall` | Email alerts |

**Subscription:** `156c186b-44ba-4fb4-98c1-4ff26e131d41`
**Tenant:** `2af8d889-64c7-4f4d-b04e-2075b906803f`
**Region:** `australiaeast`

**App URL:** https://app-bidirectional-dev-api.azurewebsites.net
**Staging URL:** https://app-bidirectional-dev-api-staging.azurewebsites.net

---

## Audit Storage Containers

All containers are **Private** (no public access).

| Container | Purpose |
|---|---|
| `release-audit` | Release evidence JSON + cosign bundle per run |
| `sbom-archive` | SPDX 2.2 SBOM + cosign bundle per run |
| `provenance-archive` | SLSA v1.0 provenance JSON + cosign bundle per run |
| `policy-evidence` | Azure Policy compliance state snapshot per run |
| `scan-results` | Scan summary JSON per run |

---

## Service Principal

| Property | Value |
|---|---|
| Name | `sp-bidirectional-dev-deploy` |
| Object ID | `e21d55bf-c19d-492d-8952-1ffd5cb73c02` |
| App (Client) ID | `d3380b54-39c9-4939-9908-c93e1d9aa826` |

### RBAC Assignments

| Role | Scope |
|---|---|
| Website Contributor | `rg-bidirectional-dev-app` |
| Storage Blob Data Contributor | `stbidirectionalaudit` |

### OIDC Federated Credentials

| Name | Subject |
|---|---|
| `github-staging` | `repo:abishkar123/Bidirectional-test-env:environment:staging` |
| `github-production` | `repo:abishkar123/Bidirectional-test-env:environment:production` |
| `github-branch-development` | `repo:abishkar123/Bidirectional-test-env:ref:refs/heads/development` |
| `github-branch-main` | `repo:abishkar123/Bidirectional-test-env:ref:refs/heads/main` |

---

## App Service Managed Identity

| Property | Value |
|---|---|
| Object ID | `06f480c6-375d-47e9-94f1-0c5fcf13bb8d` |
| Type | System-assigned |

### RBAC Assignments

| Role | Scope |
|---|---|
| Key Vault Secrets User | `kv-bidirectional-dev` |
| Storage Blob Data Reader | `stbidirectionalaudit` |

---

## GitHub Repository Secrets

Go to: **Settings → Secrets and variables → Actions**

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | `d3380b54-39c9-4939-9908-c93e1d9aa826` |
| `AZURE_TENANT_ID` | `2af8d889-64c7-4f4d-b04e-2075b906803f` |
| `AZURE_SUBSCRIPTION_ID` | `156c186b-44ba-4fb4-98c1-4ff26e131d41` |

## GitHub Environments

Go to: **Settings → Environments**

| Environment | Protection Rules |
|---|---|
| `staging` | None |
| `production` | Required reviewer |

---

## CI/CD Pipelines

### Branch Strategy

```
development  →  staging slot  (auto deploy on push)
main         →  staging slot  →  manual approval  →  production slot swap
```

### deploy-staging.yml (development branch)

Triggers on push to `development`.

```
build → deploy-staging → smoke-test → release-evidence
```

| Job | Description |
|---|---|
| `build` | Restore, build, test, publish, upload artifact |
| `deploy-staging` | Deploy to staging slot (`environment: staging`) |
| `smoke-test` | `/health/live`, `/health/ready`, dashboard 200 check |
| `release-evidence` | Cosign-sign evidence + generate/sign SPDX SBOM → upload to blob |

### deploy-prod.yml (main branch)

Triggers on push to `main`.

```
build → policy-gate → deploy-staging → smoke-test → slot-swap → release-evidence
```

| Job | Description |
|---|---|
| `build` | Restore, build, test, publish, upload artifact |
| `policy-gate` | Check Azure Policy compliance, upload snapshot to `policy-evidence` |
| `deploy-staging` | Deploy to staging slot (`environment: staging`) |
| `smoke-test` | Health + dashboard checks on staging slot |
| `slot-swap` | Swap staging → production (`environment: production`, requires approval) |
| `release-evidence` | Cosign evidence + SBOM + SLSA v1.0 provenance → upload to blob |

### deploy-infra.yml (infra/** changes)

Triggers on push to `main` or `development` when `infra/**` files change, or manually via `workflow_dispatch`.

```
resolve-env → whatif → deploy-infra
```

| Job | Description |
|---|---|
| `resolve-env` | Maps branch → environment (development=staging, main=production) |
| `whatif` | Bicep what-if preview for both policy initiative and main stack |
| `deploy-infra` | Deploy policy initiative (subscription scope) then main stack (RG scope) |

---

## Bicep Stack

All infrastructure is defined as code under `infra/`.

```
infra/
├── main.bicep              # Orchestrator (resource group scope)
├── main.bicepparam         # Parameter values
├── modules/
│   ├── app-service.bicep   # App Service Plan + App Service (S1)
│   ├── key-vault.bicep     # Key Vault (RBAC, soft-delete, purge protection)
│   ├── storage.bicep       # Audit storage account
│   ├── audit-storage.bicep # 5 private blob containers
│   ├── observability.bicep # Log Analytics + Application Insights
│   ├── alerts.bicep        # Monitor alert rules + action group
│   ├── log-export.bicep    # Log Analytics → storage continuous export
│   ├── deployment-slot.bicep # Staging slot + sticky env settings
│   └── rbac.bicep          # All role assignments
└── policies/
    └── initiative.bicep    # Custom policy initiative (subscription scope)
                            # 7 controls — APRA CPS 234 / ASIC RG271
```

### Deploy manually

```bash
# Policy initiative (subscription scope)
az deployment sub create \
  --name "bidirectional-policy-$(date +%Y%m%d%H%M%S)" \
  --location australiaeast \
  --template-file infra/policies/initiative.bicep

# Main stack (resource group scope)
az deployment group create \
  --name "bidirectional-main-$(date +%Y%m%d%H%M%S)" \
  --resource-group rg-bidirectional-dev-app \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --mode Incremental
```

Or use the helper script: `bash pipelines/deploy.sh`

---

## Security Artifacts (per release)

| Artifact | Tool | Transparency |
|---|---|---|
| Release evidence JSON | cosign keyless | Sigstore Rekor |
| SPDX 2.2 SBOM | Microsoft SBOM Tool | cosign bundle |
| SLSA v1.0 provenance | hand-crafted in-toto | cosign bundle |

All signing is **keyless** via GitHub OIDC — no stored private keys anywhere. Each bundle contains the signature, certificate chain, and Rekor log entry for independent verification.

### Verify a bundle

```bash
cosign verify-blob <file> \
  --bundle <file>.bundle \
  --certificate-identity-regexp "https://github.com/abishkar123/Bidirectional-test-env" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```
