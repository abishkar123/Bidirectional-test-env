# Bidirectional

Multi-tenant regulated platform built on .NET and Azure, with infrastructure managed via Terraform.

## Project structure

```
├── src/
│   ├── Bidirectional.Api/        # Backend API
│   └── Bidirectional.Web/        # Frontend web app
├── tests/                        # Test projects
├── infra/
│   └── terraform/
│       ├── bootstrap/            # One-time per-tenant bootstrap (SP + state storage)
│       ├── modules/              # Reusable Terraform modules
│       │   ├── app-service/      # App Service + managed identity
│       │   ├── deployment-slot/  # Staging slot
│       │   ├── key-vault/        # Key Vault
│       │   ├── storage/          # Audit storage account
│       │   ├── observability/    # Log Analytics + Application Insights
│       │   ├── rbac/             # Role assignments
│       │   ├── alerts/           # Azure Monitor alerts
│       │   ├── log-export/       # Diagnostic log export
│       │   ├── audit-storage/    # Audit blob containers
│       │   └── policy/           # Azure Policy assignments
│       ├── backend-configs/      # Per-tenant backend configs (gitignored)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars      # Gitignored — copy from .example
├── pipelines/
│   └── deploy.sh                 # Local full-stack deploy script
└── Bidirectional.sln
```

## Prerequisites

- [.NET SDK](https://dotnet.microsoft.com/download)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

## Local development

```bash
dotnet restore
dotnet build
dotnet test
```

## Infrastructure

The platform uses a **multi-tenant model**: each tenant has its own Azure subscription and its own Terraform state backend. The same Terraform config is applied independently per tenant, parameterised by `terraform.tfvars` and a backend config file.

### First-time tenant setup (bootstrap)

Run the bootstrap once per tenant to create the service principal and state storage account:

```bash
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id and tenant_name
terraform init
terraform apply
```

Note the `deployment_sp_object_id` output — you will need it in the next step.

### Per-tenant deployment

1. **Create the backend config** for the tenant:

   ```bash
   cp infra/terraform/backend-configs/example.conf.example \
      infra/terraform/backend-configs/<tenant>.conf
   # fill in storage_account_name, container_name, key, subscription_id, resource_group_name
   ```

2. **Create the tfvars file**:

   ```bash
   cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
   # fill in tenant_name, subscription_id, resource_group_name, deployment_sp_object_id, alert_email_address
   ```

3. **Init, plan, and apply**:

   ```bash
   cd infra/terraform
   terraform init -backend-config=backend-configs/<tenant>.conf
   terraform plan
   terraform apply
   ```

   Or use the convenience script from the repo root:

   ```bash
   ./pipelines/deploy.sh
   ```

### Terraform modules

| Module | What it provisions |
|---|---|
| `app-service` | App Service Plan + Web App with system-assigned managed identity |
| `deployment-slot` | Staging slot on the App Service |
| `key-vault` | Key Vault for secrets, wired to the app's managed identity |
| `storage` | Storage account for audit logs |
| `observability` | Log Analytics Workspace + Application Insights |
| `rbac` | Role assignments for the deployment SP and app managed identity |
| `alerts` | Azure Monitor alert rules + action group |
| `log-export` | Diagnostic settings to export logs to the storage account |
| `audit-storage` | Blob containers within the audit storage account |
| `policy` | Azure Policy assignments |

### Key outputs

After `terraform apply`:

```bash
terraform output app_service_name   # e.g. app-<tenant>-dev-api
terraform output app_service_url    # https://app-<tenant>-dev-api.azurewebsites.net
terraform output key_vault_name
terraform output audit_storage_name
```

## Security notes

- `terraform.tfvars` and `backend-configs/*.conf` are gitignored — never commit real subscription IDs or storage account names.
- In CI, variables are injected via `TF_VAR_*` environment variables sourced from GitHub secrets — no tfvars file is needed.
- `.gitguardian.yml` suppresses a known false positive in `infra/terraform/modules/rbac/main.tf`.
