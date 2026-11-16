# Example configuration for creating a managed identity
# Copy this file to terraform.tfvars and update with your values

resource_group_name         = "identities"
environment                 = "prd"
locationshort               = "weu"

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
        subject   = "repo:maikvandergaag/azure-ai-solution:environment:Development"
        audiences = ["api://AzureADTokenExchange"]
      }
    ]
  }
]
