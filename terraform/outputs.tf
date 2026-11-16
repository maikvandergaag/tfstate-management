output "managed_identities_summary" {
  description = "Structured summary of managed identities and federated credentials"
  value = {
    subscription_id     = data.azurerm_client_config.current.subscription_id
    resource_group_name = azurerm_resource_group.main.name
    identities = [
      for identity_key in sort(keys(azurerm_user_assigned_identity.main)) : {
        key          = identity_key
        name         = azurerm_user_assigned_identity.main[identity_key].name
        id           = azurerm_user_assigned_identity.main[identity_key].id
        client_id    = azurerm_user_assigned_identity.main[identity_key].client_id
        principal_id = azurerm_user_assigned_identity.main[identity_key].principal_id
        tenant_id    = azurerm_user_assigned_identity.main[identity_key].tenant_id
        location     = azurerm_user_assigned_identity.main[identity_key].location
        tags         = azurerm_user_assigned_identity.main[identity_key].tags
        federated_credentials = [
          for cred_key in sort([
            for k, v in local.federated_credential_map : k if v.identity_name == identity_key
            ]) : {
            name      = local.federated_credential_map[cred_key].name
            issuer    = local.federated_credential_map[cred_key].issuer
            subject   = local.federated_credential_map[cred_key].subject
            audiences = local.federated_credential_map[cred_key].audiences
          }
        ]
      }
    ]
  }
}

output "subscription_id" {
  description = "The subscription ID where the managed identity is deployed"
  value       = data.azurerm_client_config.current.subscription_id
}

output "resource_group_name" {
  description = "The name of the resource group containing the managed identity"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Map of identity key to Azure region where the managed identity is deployed"
  value       = { for k, v in azurerm_user_assigned_identity.main : k => v.location }
}
