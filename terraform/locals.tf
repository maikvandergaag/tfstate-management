locals {

  rg_name = "gaag-rg-identity"

  identity_configs = [
    for identity in var.identities : {
      name                         = identity.name
      managed_identity_name        = "id-${identity.name}-${var.locationshort}-${var.environment}"
      tags                         = identity.tags
      storage_blob_container_name  = identity.storage_blob_container_name
      federated_credentials        = identity.federated_credentials
    }
  ]

  identity_map = {
    for identity in local.identity_configs :
    identity.name => identity
  }

  federated_credential_map = {
    for item in flatten([
      for identity in local.identity_configs : [
        for cred in identity.federated_credentials : {
          key           = "${identity.name}/${cred.name}"
          identity_name = identity.name
          name          = cred.name
          issuer        = cred.issuer
          subject       = cred.subject
          audiences     = cred.audiences
        }
      ]
    ]) : item.key => item
  }

}
