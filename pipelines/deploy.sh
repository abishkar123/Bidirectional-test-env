#!/usr/bin/env bash
# Bidirectional regulated platform — full infrastructure deployment via Terraform
#
# One-time prerequisite (run once before first terraform init):
#   az storage container create \
#     --name tfstate \
#     --account-name stbidirectionalaudit \
#     --auth-mode login
set -euo pipefail

SUBSCRIPTION="156c186b-44ba-4fb4-98c1-4ff26e131d41"
TF_DIR="infra/terraform"

az account set --subscription "$SUBSCRIPTION"

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
