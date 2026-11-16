# Example configuration for creating a managed identity
# Copy this file to terraform.tfvars and update with your values

resource_group_name         = "identities"
environment                 = "prd"
locationshort               = "weu"
storage_account_resource_id = "/subscriptions/5b389701-0e47-4738-b4fe-ddb67ac3a036/resourceGroups/gaag-rg-tfstatebackend-weu-prd/providers/Microsoft.Storage/storageAccounts/sttfstatebackendweuprd"

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
    storage_blob_container_name = "tfstate"
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
    storage_blob_container_name = "tfstateaisolution"
    federated_credentials = [
      {
        name      = "github-development-environment"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:maikvandergaag@9531411/azure-ai-solution@1459603384:environment:Development"
        audiences = ["api://AzureADTokenExchange"]
      },
      {
        name      = "github-development-apply-environment"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:maikvandergaag@9531411/azure-ai-solution@1459603384:environment:Development-Apply"
        audiences = ["api://AzureADTokenExchange"]
      }
    ]
  }
]
