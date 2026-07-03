#!/usr/bin/env bash
# Bidirectional regulated platform — full infrastructure deployment via Terraform
#
# Prerequisites:
#   1. az login                              (Azure CLI auth for local runs)
#   2. cp infra/terraform/terraform.tfvars.example \
#         infra/terraform/terraform.tfvars   (then fill in your IDs — gitignored)
#   3. One-time, before first terraform init, create the state container:
#        az storage container create \
#          --name tfstate \
#          --account-name stbidirectionalaudit \
#          --auth-mode login
#
# The azurerm provider targets the subscription via var.subscription_id from
# terraform.tfvars, so no subscription ID is hardcoded here.
set -euo pipefail

TF_DIR="infra/terraform"

echo "=== Terraform Init ==="
terraform -chdir="$TF_DIR" init

echo ""
echo "=== Terraform Plan ==="
terraform -chdir="$TF_DIR" plan -out=tfplan

echo ""
echo "=== Terraform Apply ==="
terraform -chdir="$TF_DIR" apply tfplan

echo ""
echo "=== Outputs ==="
terraform -chdir="$TF_DIR" output

echo ""
echo "Done."
