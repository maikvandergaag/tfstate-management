# Terraform State Configuration

This repository contains infrastructure as code for the Terraform state platform in Azure.

It includes:
- Bicep for deploying the state backend platform resources
- Terraform for creating and managing user-assigned managed identities and related access
- GitHub Actions workflows for validation and deployment

## Repository Layout

- `bicep/`: Bicep templates and parameter files for backend platform deployment
- `terraform/`: Terraform configuration for identities, federated credentials, and role assignments
- `.github/workflows/`: CI/CD workflows for validation and deployment

## Prerequisites

- Azure subscription access
- GitHub Actions environment `platform` configured with these secrets for OIDC login:
	- `AZURE_CLIENT_ID`
	- `AZURE_TENANT_ID`
	- `AZURE_SUBSCRIPTION_ID`
	- `AZURE_OBJECT_ID` (used by deployment stack deny settings)
- The `platform` environment must also define these variables for the Terraform remote backend:
	- `TF_STATE_SUBSCRIPTION_ID`
	- `TF_STATE_RESOURCE_GROUP`
	- `TF_STATE_STORAGE_ACCOUNT`
	- `TF_STATE_CONTAINER`
	- `TF_STATE_KEY`
- Local tools for manual operations:
	- Terraform >= 1.5
	- Azure CLI
	- jq (for import helper script)

## Deployment Workflows

### Deploy State Configuration

Workflow: `.github/workflows/deploy-state-config.yml`

Triggered on:
- Push to `main` with changes in Bicep files
- Push to `main` with changes in Terraform files
- Manual dispatch

Jobs:
1. Deploy Bicep stack for backend platform resources
2. Apply Terraform to configure state identities and permissions

### Validate Terraform on Pull Request

Workflow: `.github/workflows/terraform-validate-pr.yml`

Triggered on pull requests with Terraform changes.

Checks include:
- Format check
- Init
- Validate
- Plan comment on pull request (when Azure secrets are available)

## Terraform Configuration Model

The Terraform code creates:
- Resource group (name is generated)
- User-assigned managed identities
- Federated identity credentials for OIDC
- Storage Blob Data Contributor role assignments scoped to a specific blob container

Generated names:
- Resource group: `rg-<resource_group_name>-<locationshort>-<environment>`
- Identity: `id-<identity_name>-<locationshort>-<environment>`

## How To Add a New Identity for Terraform State

Add or update identities in `terraform/terraform.tfvars`.

Each identity entry requires:
- `name`: logical identity key
- `storage_blob_container_name`: blob container for scoped role assignment
- `tags`: optional metadata map
- `federated_credentials`: optional list of OIDC trust relationships

Example identity entry:

identities = [
	{
		name = "tfstate"
		storage_blob_container_name = "tfstateidentities"
		tags = {
			owner   = "Team DevOps"
			purpose = "Terraform state automation"
		}
		federated_credentials = [
			{
				name      = "github-platform-environment"
				issuer    = "https://token.actions.databalance.ghe.com"
				subject   = "repo:databalance/terraform-state:environment:platform"
				audiences = ["api://AzureADTokenExchange"]
			}
		]
	}
]

Recommended process when adding a new identity:
1. Edit `terraform/terraform.tfvars` and add a new object in `identities`.
2. Run local validation:
	 - `terraform -chdir=terraform fmt`
	 - `terraform -chdir=terraform init -backend=false`
	 - `terraform -chdir=terraform validate`
	 - `terraform -chdir=terraform plan -var-file=terraform.tfvars`
3. Open a pull request and review the validation + plan output.
4. Merge to `main` to trigger deployment.

## Import Existing Resources

If resources already exist in Azure and must be brought under Terraform state, use:

- `terraform/import-existing-resources.sh`

Usage:
- `cd terraform`
- `./import-existing-resources.sh`

Optional custom var-file:
- `./import-existing-resources.sh /path/to/custom.tfvars`

The script attempts to import:
- Resource group
- User-assigned identities
- Federated credentials (if present)
- Blob contributor role assignments (if present)

After import, run:
- `terraform plan -var-file=terraform.tfvars`

## Notes

- Terraform role assignment scope is configured at blob container level per identity.
- Keep `terraform.tfvars` aligned with real resources to avoid drift.
