data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "main" {
  for_each            = local.identity_map
  name                = each.value.managed_identity_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = each.value.tags

  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_federated_identity_credential" "main" {
  for_each = local.federated_credential_map

  name                      = each.value.name
  user_assigned_identity_id = azurerm_user_assigned_identity.main[each.value.identity_name].id
  issuer                    = each.value.issuer
  subject                   = each.value.subject
  audience                  = each.value.audiences
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  for_each = local.identity_map

  scope                = each.value.storage_blob_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main[each.key].principal_id
}
