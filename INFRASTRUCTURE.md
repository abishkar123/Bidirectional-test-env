# CI/CD & Azure Infrastructure

## Azure Environment

| Property | Value |
|---|---|
| Subscription ID | `156c186b-44ba-4fb4-98c1-4ff26e131d41` |
| Resource Group | `rg-bidirectional-dev-app` |
| Location | `australiaeast` |
| Environment param | `dev` |

All Bicep deployments target this resource group unless noted as subscription-scope (policy initiative).

---

## Azure Resources

### App Service Plan

| Property | Value |
|---|---|
| Name | `plan-app-bidirectional-dev-api` |
| SKU | S1 Standard |
| OS | Windows |

The S1 tier is the cheapest App Service plan that supports deployment slots. Slots are required for the blue-green staging→production swap strategy, so B1 Basic is not an option despite being cheaper.

---

### App Service

| Property | Value |
|---|---|
| Name | `app-bidirectional-dev-api` |
| Plan | `plan-app-bidirectional-dev-api` |
| Runtime | .NET 9 (`netFrameworkVersion: v9.0`) |
| HTTPS only | Enforced at platform level |
| Minimum TLS version | 1.2 |
| FTPS state | Disabled (no legacy FTP access) |
| Identity | System-assigned managed identity |
| Production URL | `https://app-bidirectional-dev-api.azurewebsites.net` |
| Staging slot URL | `https://app-bidirectional-dev-api-staging.azurewebsites.net` |

**App settings injected by Bicep at infrastructure deploy time:**

| Setting | Value | Purpose |
|---|---|---|
| `ASPNETCORE_ENVIRONMENT` | `Development` (prod slot) / `Staging` (staging slot) | Controls which `appsettings.{env}.json` the runtime loads |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Read from `appi-bidirectional-dev` resource | Wires Application Insights SDK without hardcoding the key |
| `KeyVault__Name` | `kv-bidirectional-dev` | Tells the app which vault to resolve secrets from at runtime |
| `AuditStorage__AccountName` | `stbidirectionalaudit` | Tells the dashboard which storage account to read audit blobs from |

`ASPNETCORE_ENVIRONMENT` is declared as a slot-sticky setting — it remains bound to each slot when a swap occurs, so the production slot always runs `Development` (or `Production` once promoted) and the staging slot always runs `Staging`, regardless of how many swaps are performed.

---

### Deployment Slot (staging)

| Property | Value |
|---|---|
| Name | `staging` |
| Parent app | `app-bidirectional-dev-api` |
| HTTPS only | Enforced |
| Purpose | Pre-production validation target; swapped to production after smoke tests pass |

The slot eliminates cold-start risk for production: the application warms up in the staging slot before the swap. If the swap introduces a regression, `az webapp deployment slot swap` can be re-run in the reverse direction to roll back in under 2 minutes with no redeployment.

The `ASPNETCORE_ENVIRONMENT=Staging` value is written to the slot's own `appsettings` config block and is also registered in `slotConfigNames` as sticky. This prevents the production value from bleeding into the staging slot or vice versa during any future swap.

---

### Key Vault

| Property | Value |
|---|---|
| Name | `kv-bidirectional-dev` |
| SKU | Standard |
| Authorization model | RBAC (not legacy access policies) |
| Soft delete | Enabled |
| Soft delete retention | 90 days |
| Purge protection | Enabled (secrets cannot be permanently deleted until retention expires) |
| Network default action | Allow |
| Network bypass | AzureServices |

RBAC authorization means access is controlled entirely through Azure role assignments rather than vault-level access policies. This makes permission grants auditable in the same place as all other Azure RBAC.

Purge protection prevents a compromised or mistaken `az keyvault purge` from destroying secrets before the 90-day retention window. This is required for regulated data environments.

The App Service reads secrets at runtime using its system-assigned managed identity (Key Vault Secrets User role). The deployment SP has no Key Vault role — it cannot read or write secrets, only deploy infrastructure.

---

### Log Analytics Workspace

| Property | Value |
|---|---|
| Name | `law-bidirectional-dev` |
| SKU | PerGB2018 (pay per GB ingested) |
| Retention | 90 days |
| Access control | Resource-permission model (`enableLogAccessUsingOnlyResourcePermissions: true`) |

The workspace is the backend store for Application Insights (workspace-based mode). All telemetry — traces, requests, exceptions, dependencies — flows through Log Analytics so it can be queried with KQL alongside Azure Activity logs.

The resource-permission model means users can only query logs for resources they already have RBAC access to. This prevents a Log Analytics Contributor from reading logs for resources they don't own.

**Continuous data export** (`export-audit-logs` rule) streams five tables to `stbidirectionalaudit` storage in near real-time:

| Table | Contents |
|---|---|
| `AzureActivity` | All control-plane operations (who changed what resource and when) |
| `AppTraces` | Application `ILogger` output |
| `AppRequests` | HTTP request telemetry (latency, status codes) |
| `AppExceptions` | Unhandled and handled exceptions with stack traces |
| `AzureDiagnostics` | Platform-level diagnostic logs (App Service, Key Vault) |

The export exists because Log Analytics retention can be shortened or the workspace deleted. Exporting to immutable blob storage makes the audit trail legally defensible under APRA CPS 234 and ASIC RG271 — regulators can request evidence independently of whether the workspace still exists.

---

### Application Insights

| Property | Value |
|---|---|
| Name | `appi-bidirectional-dev` |
| Kind | `web` |
| Mode | Workspace-based (backed by `law-bidirectional-dev`) |
| Retention | 90 days |
| Public ingestion | Enabled |
| Public query | Enabled |

The connection string (not the instrumentation key) is injected into the App Service at Bicep deploy time. The SDK auto-configures from `APPLICATIONINSIGHTS_CONNECTION_STRING` without any code changes needed.

---

### Audit Storage Account

| Property | Value |
|---|---|
| Name | `stbidirectionalaudit` |
| SKU | Standard_LRS (locally redundant) |
| Kind | StorageV2 |
| Access tier | Hot |
| HTTPS only | Enforced |
| Minimum TLS | 1.2 |
| Public blob access | Disabled globally |
| Shared key access | Enabled (required by Log Analytics diagnostic export; cannot use managed identity for this specific feature) |

All five blob containers are private with no public access. Access is controlled by RBAC roles assigned to specific identities.

**Blob containers:**

| Container | Populated by | Contents |
|---|---|---|
| `release-audit` | `release-evidence` job (both workflows) | `release-evidence.json` — deployment metadata; `release-evidence.json.bundle` — cosign signature bundle |
| `sbom-archive` | `release-evidence` job (both workflows) | `sbom.spdx.json` — full SPDX 2.2 dependency manifest; `sbom.spdx.json.bundle` — cosign signature bundle |
| `provenance-archive` | `release-evidence` job (prod workflow only) | `provenance.json` — SLSA v1.0 provenance document; `provenance.json.bundle` — cosign signature bundle |
| `policy-evidence` | `policy-gate` job (prod workflow only) | `policy-state-{timestamp}.json` — Azure Policy compliance state snapshot for all resources in the resource group |
| `scan-results` | `release-evidence` job (prod workflow only) | `scan-summary.json` — summary of all signing and scanning outcomes for the run |

**Blob key format:**
- Production: `{run_number}/{filename}` (e.g. `42/sbom.spdx.json`)
- Staging: `{run_number}-attempt{run_attempt}/{filename}` (e.g. `42-attempt2/sbom.spdx.json`)

The staging format includes the attempt number to avoid `BlobAlreadyExists` errors when a job is re-run after a transient failure. The `--overwrite` flag is also set on all upload commands as a secondary guard.

---

### Azure Monitor Alerts

**Action group:** `ag-bidirectional-dev-oncall`
- Short name: `dev-oncall`
- Receivers: one email receiver (`email-on-call`) using the common alert schema

**Alert rules:**

#### `alert-bidirectional-dev-error-rate` (Severity 1)
- **Source:** Application Insights (`appi-bidirectional-dev`)
- **Metric:** `requests/failed`
- **Condition:** count > 5 in a 5-minute window, evaluated every 1 minute
- **Purpose:** Soak gate trip wire — a spike in failed requests during the post-swap observation period indicates a regression. Severity 1 pages immediately.

#### `alert-bidirectional-dev-5xx` (Severity 2)
- **Source:** App Service (`app-bidirectional-dev-api`)
- **Metric:** `Http5xx`
- **Condition:** total > 0 in a 1-minute window, evaluated every 1 minute
- **Purpose:** Catches any server-side error at the platform level. Threshold is zero — any 5xx is actionable.

Both alerts fire to the same action group. Severity 1 is used when the metric implies a sustained error rate (failed requests aggregated over 5 min). Severity 2 is used for the platform-level Http5xx because any single 5xx warrants investigation even if it doesn't represent a sustained trend.

---

## RBAC

### Deployment Service Principal (`sp-bidirectional-dev-deploy`)

Object ID: `e21d55bf-c19d-492d-8952-1ffd5cb73c02`

This is the service principal the GitHub Actions workflows use to authenticate to Azure via OIDC. It has the minimum roles required to deploy the application and upload pipeline evidence — it cannot read secrets or modify policies.

| Role | Scope | Role ID | Purpose |
|---|---|---|---|
| Website Contributor | Resource group `rg-bidirectional-dev-app` | `de139f84-...` | Deploy and configure App Service, swap deployment slots |
| Storage Blob Data Contributor | `stbidirectionalaudit` storage account | `ba92f5b4-...` | Upload release evidence, SBOM, provenance, and policy snapshots during pipeline runs |

Website Contributor replaces the broader Contributor role. Contributor gives write access to all resource types in the group including Key Vault — Website Contributor is scoped to `Microsoft.Web/*` only, following the principle of least privilege.

Role assignments use deterministic GUIDs (`guid(resourceGroup().id, principalId, roleId)`) so re-running the Bicep deployment is idempotent — it will not create duplicate assignments.

---

### App Service Managed Identity

Object ID: `06f480c6-375d-47e9-94f1-0c5fcf13bb8d`

This is the system-assigned managed identity automatically created when the App Service is deployed. It is used at runtime — not during deployment. The application code uses `DefaultAzureCredential` to authenticate to Azure services without storing any credentials.

| Role | Scope | Role ID | Purpose |
|---|---|---|---|
| Key Vault Secrets User | `kv-bidirectional-dev` | `4633458b-...` | Read secrets at runtime (e.g. connection strings, API keys) |
| Storage Blob Data Reader | `stbidirectionalaudit` storage account | `2a2b9908-...` | Read audit blob containers for the dashboard |

Both assignments are **conditional** in Bicep — they are only deployed when `appServiceManagedIdentityObjectId` is non-empty. This is because the managed identity Object ID is not known until the App Service is first deployed and the system-assigned identity is enabled (Stage 8 of the deployment sequence). The workflow is:

1. Deploy infra with `appServiceManagedIdentityObjectId = ''` — App Service is created, managed identity is assigned by Azure.
2. Go to the Azure portal → App Service → Identity → copy the Object (principal) ID.
3. Set `appServiceManagedIdentityObjectId` in `infra/main.bicepparam`.
4. Re-run the infrastructure deployment — the two RBAC assignments are now created.

---

## Azure Policy Initiative

**Initiative name:** `enterprise-regulated-platform-baseline`
**Assignment name:** `bidirectional-dev-baseline`
**Scope:** Subscription `156c186b-44ba-4fb4-98c1-4ff26e131d41`
**Enforcement mode:** `Audit` — evaluates resources and reports compliance state; does **not** block non-compliant deployments in the dev environment.
**Compliance frameworks:** APRA CPS 234 (operational resilience), ASIC RG271 (financial services technology)

The initiative is assigned at subscription scope so it covers all current and future resource groups, not just `rg-bidirectional-dev-app`. This ensures that any new resource group created under the subscription is automatically subject to the same baseline controls.

**Policies included:**

| Reference ID | Built-in policy | What it checks |
|---|---|---|
| `storage-tls12` | Storage accounts require min TLS 1.2 | Flags any storage account with `minimumTlsVersion` below 1.2 |
| `storage-secure-transfer` | Secure transfer enabled | Flags any storage account with `supportsHttpsTrafficOnly: false` |
| `storage-no-public-blob` | Disallow public blob access | Flags any storage account with `allowBlobPublicAccess: true` |
| `appservice-latest-tls` | App Service requires latest TLS | Flags any App Service with TLS < 1.2 |
| `kv-soft-delete` | Key Vault soft delete must be enabled | Flags any vault without soft delete |
| `kv-resource-logs` | Key Vault diagnostic logs | Flags any vault without a diagnostic settings rule sending resource logs |
| `appservice-resource-logs` | App Service diagnostic logs | Flags any App Service without diagnostic settings configured |

**How the policy gate works in CI/CD:**

During each production deploy (`deploy-prod.yml`, job `policy-gate`), the pipeline runs:

```
az policy state list \
  --resource-group rg-bidirectional-dev-app \
  --filter "complianceState eq 'NonCompliant'" \
  --query "length(@)" -o tsv
```

If the count is greater than zero, the pipeline emits a `::warning::` annotation in GitHub Actions (visible in the run summary) but does not fail. The current behaviour is advisory — the team reviews the count before approving the slot-swap gate. A future change can switch the warning to an `exit 1` to make the gate blocking.

The full compliance state (resource IDs, policy names, states) is serialised to JSON and uploaded to `policy-evidence/{run_number}/policy-state-{timestamp}.json` so the audit record is preserved regardless of what happens to the Azure Policy state later.

---

## GitHub Actions Workflows

### Authentication

All three workflows use **OIDC federation** — no client secrets or certificates are stored in GitHub. Each workflow uses `azure/login@v2` with these three secrets:

| Secret | Value stored in GitHub | What it contains |
|---|---|---|
| `AZURE_CLIENT_ID` | App registration / service principal client ID | Identifies which service principal to authenticate as |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Identifies the Azure AD directory |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | Scopes the session to the correct subscription |

GitHub's OIDC provider issues a short-lived token for each workflow run. Azure AD validates that the token was issued by GitHub for the correct repository, branch, and environment before granting access. The token expires when the job ends.

---

### `deploy-infra.yml` — Infrastructure (Bicep)

**File:** `.github/workflows/deploy-infra.yml`

**Triggers:**
- Push to `main` or `development` when any file under `infra/**` changes
- Manual via `workflow_dispatch` — presents a dropdown to choose `staging` or `production`

**Purpose:** Keeps Azure infrastructure in sync with the Bicep source. Runs a what-if preview before applying any changes.

#### Job 1 — `resolve-env`

Determines which GitHub environment (`staging` or `production`) this run targets. This controls which environment's OIDC federation and approval rules apply.

| Event | Logic | Result |
|---|---|---|
| `workflow_dispatch` | Reads the `environment` input; validates it is exactly `staging` or `production` — any other value fails the job | User-selected value |
| Push to `main` | Branch name is `main` | `production` |
| Push to `development` | Any other branch | `staging` |

The environment name is written to the job output (`$GITHUB_OUTPUT`) so downstream jobs can reference it as `${{ needs.resolve-env.outputs.environment }}`.

#### Job 2 — `whatif`

Runs a dry-run preview against Azure before any real changes are made. Requires `resolve-env` to complete first so it runs in the correct environment context.

**Step 1 — Azure login:** Authenticates using OIDC with the three secrets above.

**Step 2 — Policy initiative what-if (subscription scope):**
```
az deployment sub what-if \
  --name "infra-policy-whatif-{run_number}" \
  --location australiaeast \
  --template-file infra/policies/initiative.bicep \
  --parameters appResourceGroupName=rg-bidirectional-dev-app
```
Shows what policy definitions and assignments would be created, modified, or deleted at the subscription level.

**Step 3 — Main stack what-if (resource group scope):**
```
az deployment group what-if \
  --name "infra-main-whatif-{run_number}" \
  --resource-group rg-bidirectional-dev-app \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```
Shows all resource changes across all Bicep modules. The output is visible in the GitHub Actions run log and can be reviewed before the deploy job runs.

#### Job 3 — `deploy-infra`

Runs only on `push` or `workflow_dispatch` events (not on PRs). Requires both `resolve-env` and `whatif` to succeed.

**Step 1 — Azure login:** Same OIDC authentication as the whatif job.

**Step 2 — Deploy policy initiative (subscription scope):**
```
az deployment sub create \
  --name "infra-policy-{run_number}" \
  --location australiaeast \
  --template-file infra/policies/initiative.bicep \
  --parameters appResourceGroupName=rg-bidirectional-dev-app
```
Creates or updates the policy set definition and its subscription-level assignment. Deployment name includes `run_number` for traceability in Azure Deployments history.

**Step 3 — Deploy main stack (resource group scope):**
```
az deployment group create \
  --name "infra-main-{run_number}" \
  --resource-group rg-bidirectional-dev-app \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --mode Incremental
```
`Incremental` mode means resources not mentioned in the template are left untouched. This is the safe default — `Complete` mode would delete any resource in the group not declared in Bicep.

**Step 4 — Show deployment outputs:**
```
az deployment group show \
  --resource-group rg-bidirectional-dev-app \
  --name "infra-main-{run_number}" \
  --query properties.outputs
```
Prints the Bicep outputs (app service name, URL, Key Vault name, storage account name) to the run log for verification.

---

### `deploy-staging.yml` — Staging (development branch)

**File:** `.github/workflows/deploy-staging.yml`

**Triggers:**
- Push to `development`
- Pull request targeting `development` (build and test only — deploy steps are gated on `github.ref == 'refs/heads/development'`)

**Purpose:** Validates every commit on the development branch by building, testing, deploying to the staging slot, smoke testing, and recording a signed evidence pack.

#### Job 1 — `build`

Runs on every push and PR.

**Step 1 — Checkout (`fetch-depth: 0`):** Full history is fetched so `git rev-parse --short HEAD` produces an accurate short SHA for the version string.

**Step 2 — Set up .NET 9:** Uses `actions/setup-dotnet@v4` to install the exact version specified by `DOTNET_VERSION: "9.0.x"`.

**Step 3 — Restore:** `dotnet restore` — downloads NuGet packages. Runs first so subsequent steps can use `--no-restore` and skip repeated network calls.

**Step 4 — Build:** `dotnet build --no-restore -c Release` — compiles in Release configuration. Fails fast on compilation errors before running slower test or publish steps.

**Step 5 — Test:**
```
dotnet test --no-build -c Release \
  --collect:"XPlat Code Coverage" \
  --results-directory TestResults \
  --logger "trx;LogFileName=test-results.trx"
```
Runs all test projects in the solution. `XPlat Code Coverage` generates a `coverage.cobertura.xml` file. Results are written in `.trx` format for GitHub Actions test report parsers. The `--no-build` flag reuses the compiled output from the build step.

**Step 6 — Upload test results:** Uploads the `TestResults/` directory as a GitHub artifact (3-day retention on staging, 7-day on prod). Runs with `if: always()` so results are preserved even when tests fail.

**Step 7 — Derive version:** `git rev-parse --short HEAD` — produces an 8-character commit SHA used as the version identifier throughout the evidence pack and SBOM.

**Step 8 — Publish:**
```
dotnet publish src/Bidirectional.Web/Bidirectional.Web.csproj \
  --no-build -c Release \
  -o publish \
  /p:SourceRevisionId={sha}
```
Writes the deployable output to `publish/`. The `SourceRevisionId` property embeds the commit SHA into the assembly metadata, making it verifiable at runtime.

**Step 9 — Upload build artifact:** Uploads `publish/` as `web-publish` (3-day retention). Downstream jobs download this artifact rather than re-building.

#### Job 2 — `deploy-staging` *(push to `development` only)*

**Step 1 — Download artifact:** Downloads the `web-publish` artifact produced by the `build` job.

**Step 2 — Azure login:** OIDC authentication under the `staging` GitHub environment.

**Step 3 — Set ASPNETCORE_ENVIRONMENT on slot:**
```
az webapp config appsettings set \
  --resource-group rg-bidirectional-dev-app \
  --name app-bidirectional-dev-api \
  --slot staging \
  --settings ASPNETCORE_ENVIRONMENT=Staging
```
Sets the environment variable directly on the slot's configuration before deploying the package. This ensures the correct environment is active from the first request after deploy, even before Bicep has been re-run.

**Step 4 — Deploy to staging slot:**
```
uses: azure/webapps-deploy@v3
  app-name: app-bidirectional-dev-api
  slot-name: staging
  package: publish/
```
Zips the publish directory and pushes it to the staging slot via the Kudu deploy API. The slot stays warm throughout — no restart except the normal recycle from the new deployment.

#### Job 3 — `smoke-test`

Runs after `deploy-staging` completes. Tests against the staging slot URL.

**Step 1 — Wait for warmup:** `sleep 15` — allows the .NET process to start and the DI container to initialize before health probes are sent.

**Step 2 — Liveness check:**
```
curl --fail --retry 5 --retry-delay 5 \
  https://app-bidirectional-dev-api-staging.azurewebsites.net/health/live
```
`/health/live` should return 200 as long as the process is running. Retries 5 times with 5-second delays (up to 25 seconds total). Fails the job if all retries are exhausted.

**Step 3 — Readiness check:**
```
curl --fail --retry 5 --retry-delay 5 \
  https://app-bidirectional-dev-api-staging.azurewebsites.net/health/ready
```
`/health/ready` checks that the application's dependencies (database connections, Key Vault access, etc.) are healthy. A live but not-ready app would not be safe to receive production traffic.

**Step 4 — Dashboard page check:**
```
curl --silent --output /dev/null --write-out "%{http_code}" \
  https://app-bidirectional-dev-api-staging.azurewebsites.net/
```
Fetches the root page and asserts the HTTP status code is exactly `200`. This verifies the application renders a real response, not just a platform health page.

#### Job 4 — `release-evidence` *(only if smoke-test succeeds)*

Condition: `if: always() && needs.smoke-test.result == 'success'`

**Step 1–3 — Setup:** Checkout, set up .NET 9, install cosign v2.4.1 via `sigstore/cosign-installer@v3.7.0`.

**Step 4 — Azure login:** OIDC authentication.

**Step 5 — Build and sign release evidence:**

Constructs `release-evidence.json` with the following fields:

| Field | Value |
|---|---|
| `runNumber` | `${{ github.run_number }}` |
| `version` | Short commit SHA |
| `commit` | Full commit SHA |
| `branch` | `development` |
| `actor` | GitHub username who triggered the run |
| `deployedAt` | UTC timestamp |
| `appName` | `app-bidirectional-dev-api` |
| `slot` | `staging` |
| `environment` | `Staging` |
| `slotSwap` | `false` |

Then signs it:
```
cosign sign-blob release-evidence.json \
  --bundle release-evidence.json.bundle \
  --yes
```
The `--bundle` flag writes a JSON file containing the signature, certificate chain, and Rekor transparency log entry. The `--yes` flag accepts the Rekor upload without an interactive prompt.

Both files are uploaded to `release-audit/{run_number}-attempt{run_attempt}/`.

**Step 6 — Generate and sign SBOM:**

```
sbom-tool generate \
  -b src/Bidirectional.Web \
  -bc src/Bidirectional.Web \
  -pn Bidirectional.Web \
  -pv {short-sha} \
  -ps Bidirectional \
  -nsb https://bidirectional.example.com/sbom \
  -m sbom-output
```

Flags explained:
- `-b`: build drop path (where compiled output lives)
- `-bc`: build component path (source root for dependency scanning)
- `-pn`: package name
- `-pv`: package version (short commit SHA)
- `-ps`: package supplier
- `-nsb`: namespace base URI for SPDX document identifiers
- `-m`: manifest output directory (tool writes to `-m/_manifest/spdx_2.2/manifest.spdx.json`)

The generated `manifest.spdx.json` is copied to `sbom.spdx.json` and then signed with cosign. Both the SBOM and its bundle are uploaded to `sbom-archive/{run_number}-attempt{run_attempt}/`.

---

### `deploy-prod.yml` — Production (main branch)

**File:** `.github/workflows/deploy-prod.yml`

**Triggers:**
- Push to `main`
- Pull request targeting `main` (build and test only)

**Permissions:** `id-token: write` (OIDC) and `packages: write` (future GHCR use) at the workflow level.

**Purpose:** Full regulated deployment pipeline — builds, validates policy compliance, deploys to staging slot, smoke tests, requires a human to approve the slot swap, then records a complete supply chain evidence pack.

#### Job 1 — `build`

Identical to the staging workflow with two differences:
- Artifact retention is **7 days** (vs 3 days on staging)
- Runs on every push and PR to `main` (build failures are visible before merge)

#### Job 2 — `policy-gate` *(push to `main` only)*

Runs after `build` succeeds. Gated on `if: github.ref == 'refs/heads/main'`.

**Step 1 — Azure login:** OIDC authentication.

**Step 2 — Check policy compliance:**
```
az policy state list \
  --resource-group rg-bidirectional-dev-app \
  --filter "complianceState eq 'NonCompliant'" \
  --query "length(@)" -o tsv
```
Counts the number of non-compliant resources. If the count is greater than zero, a `::warning::` annotation is written to the run log. The job does not fail — non-compliance is advisory at the current dev stage.

**Step 3 — Upload policy evidence:**

Queries the full compliance state:
```
az policy state list \
  --resource-group rg-bidirectional-dev-app \
  --query "[].{resource:resourceId,policy:policyDefinitionName,state:complianceState}" \
  -o json > policy-state-{timestamp}.json
```
Uploads the JSON to `policy-evidence/{run_number}/policy-state-{timestamp}.json` in audit storage. The timestamp in the filename ensures the blob is unique even if the run number collides across environments.

#### Job 3 — `deploy-staging` *(push to `main` only, after policy-gate)*

Identical to the staging workflow's `deploy-staging` job. Deploys the production build to the staging slot so smoke tests run against production code in a production-adjacent environment before the real swap.

#### Job 4 — `smoke-test`

Identical to the staging workflow's `smoke-test` job — same three probes (`/health/live`, `/health/ready`, `/`) against the staging slot URL.

#### Job 5 — `slot-swap` *(requires manual approval)*

**GitHub environment:** `production` — this environment must be configured in GitHub repository settings with at least one required reviewer. The job will pause at this step and send a notification to the configured reviewers. The swap only proceeds after a reviewer approves.

**Step 1 — Azure login:** OIDC authentication.

**Step 2 — Swap staging → production:**
```
az webapp deployment slot swap \
  --resource-group rg-bidirectional-dev-app \
  --name app-bidirectional-dev-api \
  --slot staging \
  --target-slot production
```
Azure swaps the routing rules between the staging and production slots atomically. From this point, the `staging` slot serves the previous production code (available for rollback) and the `production` slot serves the new code.

**To roll back:** Re-run the same swap command — it swaps the slots back in under 2 minutes without redeploying.

#### Job 6 — `release-evidence` *(only if slot-swap succeeds)*

Condition: `if: always() && needs.slot-swap.result == 'success'`

Produces the full supply chain evidence pack for the production release. This job has `id-token: write` permission at the job level to allow cosign keyless signing.

**Steps 1–3 — Setup:** Checkout, .NET 9, cosign v2.4.1.

**Step 4 — Azure login:** OIDC authentication.

**Step 5 — Build and sign release evidence:**

Same structure as the staging evidence job, with these differences:
- `"slot": "production"`
- `"environment": "Production"`
- `"slotSwap": true`
- Blob prefix is `{run_number}/` (no attempt suffix — prod runs are not expected to be retried)

**Step 6 — Generate SBOM:**

Same `sbom-tool generate` command as staging. Uploaded to `sbom-archive/{run_number}/sbom.spdx.json` and `sbom-archive/{run_number}/sbom.spdx.json.bundle`.

**Step 7 — Sign SBOM with cosign:**
```
cosign sign-blob sbom.spdx.json \
  --bundle sbom.spdx.json.bundle \
  --yes
```
Cosign uses the GitHub OIDC token as the certificate identity. The certificate (issued by Fulcio) and the signature are recorded in the Rekor public transparency log. Anyone with the bundle file can verify the signature without contacting Cosign infrastructure.

**Step 8 — Generate SLSA provenance:**

Constructs a SLSA v1.0 provenance document with:

| Field | Value |
|---|---|
| `_type` | `https://in-toto.io/Statement/v1` |
| `subject[0].name` | `sbom.spdx.json` |
| `subject[0].digest.sha256` | SHA-256 hash of `sbom.spdx.json` |
| `predicateType` | `https://slsa.dev/provenance/v1` |
| `buildDefinition.buildType` | GitHub Actions workflow build type URI |
| `externalParameters.workflow.ref` | `refs/heads/main` |
| `externalParameters.workflow.repository` | GitHub repository full name |
| `externalParameters.workflow.path` | `.github/workflows/deploy-prod.yml` |
| `resolvedDependencies[0].uri` | `git+https://github.com/{repo}@refs/heads/main` |
| `resolvedDependencies[0].digest.gitCommit` | Full commit SHA |
| `runDetails.builder.id` | GitHub Actions run URL |
| `runDetails.metadata.invocationId` | `github.run_id` |

The SBOM digest (`sha256sum sbom.spdx.json`) links the provenance document to the specific SBOM generated in the previous step. This creates a chain: provenance → SBOM → built artifact.

Both `provenance.json` and `provenance.json.bundle` are signed with cosign and uploaded to `provenance-archive/{run_number}/`.

**Step 9 — Upload scan summary:**

Writes a `scan-summary.json` recording the outcome of all signing and scanning steps:

```json
{
  "runNumber": "...",
  "commit": "...",
  "sbomGenerated": true,
  "sbomSigned": true,
  "provenanceSigned": true,
  "evidenceSigned": true,
  "signingMethod": "cosign-keyless-oidc",
  "rekorTransparencyLog": true,
  "generatedAt": "..."
}
```

Uploaded to `scan-results/{run_number}/scan-summary.json`.

---

## Supply Chain Security

### Cosign Keyless Signing

No private keys are stored anywhere. For each `cosign sign-blob` call:

1. Cosign requests a short-lived OIDC token from GitHub's token endpoint.
2. Cosign presents the token to Fulcio (a certificate authority run by sigstore.dev).
3. Fulcio verifies the token with GitHub and issues a code-signing certificate whose Subject Alternative Name encodes the workflow identity (e.g. `https://github.com/{org}/{repo}/.github/workflows/deploy-prod.yml@refs/heads/main`).
4. Cosign signs the blob with the ephemeral key derived from the certificate.
5. The signature, certificate chain, and a transparency log inclusion proof are written to the `.bundle` file.
6. The entry is recorded permanently in the Rekor public append-only transparency log.

**Verification** (anyone with the bundle can do this):
```
cosign verify-blob {file} --bundle {file}.bundle \
  --certificate-identity-regexp "github.com/{org}/{repo}" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

### Evidence Chain (production release)

```
Git commit SHA
    │
    ▼
dotnet publish → web-publish artifact
    │
    ▼
sbom-tool generate → sbom.spdx.json  ──── cosign sign ──► sbom.spdx.json.bundle
    │
    │ sha256sum
    ▼
provenance.json (SLSA v1.0) ─────────────── cosign sign ──► provenance.json.bundle
    │
    ▼
release-evidence.json ───────────────────── cosign sign ──► release-evidence.json.bundle
    │
    ▼
scan-summary.json
    │
    ▼
All uploaded to stbidirectionalaudit under run-scoped blob paths
```

---

## Manual Deployment Script

**File:** `pipelines/deploy.sh`

Used for break-glass or first-time deployments from a local machine. Requires `az login` and the correct subscription set beforehand. The script sets the subscription explicitly at the top.

**Configuration in script:**

| Variable | Value |
|---|---|
| `RESOURCE_GROUP` | `rg-bidirectional-dev-app` |
| `SUBSCRIPTION` | `156c186b-44ba-4fb4-98c1-4ff26e131d41` |
| `LOCATION` | `australiaeast` |

**Step 1 — Set subscription:**
```
az account set --subscription 156c186b-44ba-4fb4-98c1-4ff26e131d41
```
Ensures all subsequent commands run against the correct subscription regardless of which subscription is currently active in the local Azure CLI context.

**Step 2 — Deploy policy initiative (subscription scope):**
```
az deployment sub create \
  --name "bidirectional-policy-{timestamp}" \
  --location australiaeast \
  --template-file infra/policies/initiative.bicep \
  --parameters appResourceGroupName=rg-bidirectional-dev-app \
  --confirm-with-what-if
```
The `--confirm-with-what-if` flag prints a what-if diff and prompts for confirmation before applying. The deployment name includes a timestamp (`date +%Y%m%d%H%M%S`) to keep Azure Deployments history readable.

**Step 3 — Deploy main stack (resource group scope):**
```
az deployment group create \
  --name "bidirectional-main-{timestamp}" \
  --resource-group rg-bidirectional-dev-app \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --confirm-with-what-if
```
Same what-if prompt before applying. Deploys all modules in dependency order.

**Stage 8 post-run instructions (printed by the script):**

After the first run, the App Service exists but the managed identity RBAC assignments have not been created yet because `appServiceManagedIdentityObjectId` is empty by default.

1. In the Azure portal, navigate to App Service → Identity → System assigned.
2. Enable the identity (Status: On) and save.
3. Copy the **Object (principal) ID** that appears.
4. Open `infra/main.bicepparam` and set `appServiceManagedIdentityObjectId` to that value.
5. Re-run `pipelines/deploy.sh` — this time the `rbac` module will create the Key Vault Secrets User and Storage Blob Data Reader assignments for the managed identity.

---

## Bicep Module Deployment Stages

The `main.bicep` orchestrates 8 logical stages. The stage numbers match comments in the source files.

| Stage | Module | Scope | What it does |
|---|---|---|---|
| 1 | `rbac.bicep` | Resource group | Assigns Website Contributor to deployment SP; assigns Key Vault Secrets User and Storage Blob Data Reader to managed identity (conditional on Stage 8) |
| 2 | `initiative.bicep` | Subscription | Creates and assigns the `enterprise-regulated-platform-baseline` policy initiative |
| 3 | `observability.bicep` | Resource group | Creates Log Analytics workspace (`law-bidirectional-dev`) and workspace-based Application Insights (`appi-bidirectional-dev`) |
| 4 | `alerts.bicep` | Resource group | Creates action group (`ag-bidirectional-dev-oncall`) and two metric alert rules (error rate Sev 1, Http5xx Sev 2) |
| 5 | `log-export.bicep` | Resource group | Creates continuous data export rule from Log Analytics to audit storage for 5 tables |
| 6 | `audit-storage.bicep` | Resource group | Creates the 5 private blob containers in `stbidirectionalaudit` |
| 7 | `deployment-slot.bicep` | Resource group | Creates the `staging` slot, writes slot-sticky `ASPNETCORE_ENVIRONMENT` config, and registers it in `slotConfigNames` |
| 8 | `rbac.bicep` (re-run) | Resource group | The conditional RBAC assignments for the managed identity are applied on the second run after the Object ID is populated in `main.bicepparam` |

**Module dependency graph:**

```
storage ──────────────────────────────────────────────────────────┐
keyVault ───────────────────────────────────┐                      │
observability ──────────────────────┐       │                      ▼
                                    ▼       ▼               auditContainers
                              appService → rbac
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
                 alerts          logExport         slot
```

Bicep resolves the `dependsOn` declarations and deploys modules in this order, parallelising where there are no dependencies. Storage and Key Vault are deployed in parallel. Application Insights depends on nothing except storage. App Service waits for both Application Insights (needs connection string) and Key Vault (needs vault name). RBAC, alerts, log export, audit containers, and slot all fan out in parallel once the App Service exists.
