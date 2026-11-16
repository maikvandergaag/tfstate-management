variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to create for the managed identity"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_.()]+$", var.resource_group_name))
    error_message = "Resource group name must only contain alphanumeric characters, hyphens, underscores, parentheses and periods."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the resource group and managed identity will be created"
  default     = "westeurope"

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "Location must be a valid Azure region name in lowercase without spaces (for example: westeurope)."
  }
}

variable "locationshort" {
  type        = string
  description = "Shortened Azure region identifier for naming resources"
  default     = "weu"

  validation {
    condition     = can(regex("^[a-z]{2,3}$", var.locationshort))
    error_message = "Location short must be 2-3 lowercase letters (for example: 'weu' for West Europe)."
  }
}

variable "identities" {
  type = list(object({
    name                        = string
    tags                        = optional(map(string), {})
    storage_blob_container_name = string
    federated_credentials = optional(list(object({
      name      = string
      issuer    = string
      subject   = string
      audiences = list(string)
    })), [])
  }))
  description = "List of identities to create. At least one identity is required."
  default     = []

  validation {
    condition     = length(var.identities) > 0
    error_message = "At least one identity must be provided in 'identities'."
  }

  validation {
    condition = alltrue([
      for identity in var.identities :
      can(regex("^[a-zA-Z0-9-]+$", identity.name))
    ])
    error_message = "Each identity name must only contain alphanumeric characters and hyphens."
  }

  validation {
    condition     = length(var.identities) == length(distinct([for identity in var.identities : identity.name]))
    error_message = "Identity names must be unique."
  }

  validation {
    condition = alltrue(flatten([
      for identity in var.identities : [
        for cred in identity.federated_credentials :
        can(regex("^[a-zA-Z0-9-]+$", cred.name)) &&
        can(regex("^https://", cred.issuer)) &&
        length(cred.audiences) > 0
      ]
    ]))
    error_message = "Each federated credential must have a valid name (alphanumeric and hyphens), HTTPS issuer URL, and at least one audience."
  }

  validation {
    condition = alltrue(flatten([
      for identity in var.identities : [
        for k, v in identity.tags : can(regex("^.{1,512}$", k)) && can(regex("^.{0,256}$", v))
      ]
    ]))
    error_message = "Identity tag names must be 1-512 characters and values must be 0-256 characters."
  }

  validation {
    condition = alltrue([
      for identity in var.identities :
      can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])$", identity.storage_blob_container_name))
    ])
    error_message = "storage_blob_container_name must be a valid Azure blob container name (3-63 chars, lowercase letters, numbers, and hyphens, starting and ending with an alphanumeric character)."
  }
}

variable "storage_account_resource_id" {
  type        = string
  description = "Global storage account resource ID used for container-scoped Storage Blob Data Contributor role assignments"

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Storage/storageAccounts/[^/]+$", var.storage_account_resource_id))
    error_message = "storage_account_resource_id must be an Azure storage account resource ID like '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<name>'."
  }
}

variable "environment" {
  type        = string
  description = "The environment identifier (e.g., 'dev', 'tst', 'acc', 'prd')"
  default     = ""

  validation {
    condition     = var.environment == "" || can(regex("^[a-z0-9]{2,4}$", var.environment))
    error_message = "Environment must be 2-4 lowercase alphanumeric characters (e.g., 'dev', 'tst', 'acc', 'prd')."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the resource group and as default tags for managed identities"
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.tags : can(regex("^.{1,512}$", k)) && can(regex("^.{0,256}$", v))])
    error_message = "Tag names must be 1-512 characters and values must be 0-256 characters."
  }
}

