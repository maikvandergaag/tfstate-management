# Example configuration for creating a managed identity
# Copy this file to terraform.tfvars and update with your values

resource_group_name         = "identities"
environment                 = "prd"
locationshort               = "weu"
storage_account_resource_id = "/subscriptions/60182d51-2810-425e-b75a-c2692503a1a2/resourceGroups/rg-terraformstatebackend-weu-prd/providers/Microsoft.Storage/storageAccounts/stterraformstatebweuprd"

tags = {
  environment = "prod"
  managedBy   = "GitHub Actions"
  purpose     = "Managed identities for automations"
  owner       = "maik@familie-vandergaag.nl"
}

identities = [
  {
    name = "tfstate"
    tags = {
      purpose = "id for deploying and maintaining the terraform backend"
      owner   = "maik@familie-vandergaag.nl"
    }
    storage_blob_container_name = "tfstateidentities"
    federated_credentials = [
      {
        name      = "github-platform-environment"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:maikvandergaag/tfstate-management:environment:platform"
        audiences = ["api://AzureADTokenExchange"]
      }
    ]
  },
  {
    name = "tfstateaisolution"
    tags = {
      purpose = "id for deploying and maintaining the terraform backend"
      owner   = "maik@familie-vandergaag.nl"
    }
    storage_blob_container_name = "tfstateidentities"
    federated_credentials = [
      {
        name      = "github-development-environment"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:maikvandergaag/azure-ai-solution:environment:Development"
        audiences = ["api://AzureADTokenExchange"]
      }
    ]
  }
]
