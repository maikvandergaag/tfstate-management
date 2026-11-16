#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-$SCRIPT_DIR}"
VAR_FILE="${1:-$TF_DIR/terraform.tfvars}"

if [[ ! -f "$VAR_FILE" ]]; then
  echo "Variable file not found: $VAR_FILE" >&2
  echo "Usage: $0 [path-to-tfvars]" >&2
  exit 1
fi

for cmd in terraform az jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not logged in. Run: az login" >&2
  exit 1
fi

cd "$TF_DIR"

# Ensure provider and backend metadata are available for import operations.
terraform init -input=false >/dev/null

# Helper: evaluate a Terraform console expression with the selected var file.
tf_eval() {
  local expr="$1"
  terraform console -var-file="$VAR_FILE" <<< "$expr"
}

# Helper: import only when address is not already present in state.
import_if_missing() {
  local address="$1"
  local import_id="$2"
  local normalized_import_id

  # Azure CLI may return lowercase segment names (for example: /resourcegroups/).
  # Terraform import for some resources expects canonical segment casing.
  normalized_import_id="$(echo "$import_id" | sed 's#/resourcegroups/#/resourceGroups/#g')"

  if terraform state show "$address" >/dev/null 2>&1; then
    echo "Skipping (already in state): $address"
    return
  fi

  echo "Importing: $address"
  terraform import -var-file="$VAR_FILE" "$address" "$normalized_import_id"
}

resource_group_name="$(tf_eval 'local.rg_name' | tr -d '"\r')"
storage_scope="$(tf_eval 'var.storage_account_resource_id' | tr -d '"\r')"
locationshort="$(tf_eval 'var.locationshort' | tr -d '"\r')"
environment="$(tf_eval 'var.environment' | tr -d '"\r')"
identities_json="$(tf_eval 'jsonencode(var.identities)' | jq -r '.')"
target_subscription_id="$(echo "$storage_scope" | awk -F'/' '{print $3}')"
subscription_id="$(az account show --query id -o tsv)"

if [[ -z "$target_subscription_id" ]]; then
  echo "Could not parse subscription ID from storage_account_resource_id: $storage_scope" >&2
  exit 1
fi

if [[ "$subscription_id" != "$target_subscription_id" ]]; then
  echo "Switching Azure CLI context to subscription: $target_subscription_id"
  az account set --subscription "$target_subscription_id"
  subscription_id="$target_subscription_id"
fi

if [[ -z "$resource_group_name" ]]; then
  echo "Could not resolve local.rg_name from Terraform configuration." >&2
  exit 1
fi

if [[ "$identities_json" == "null" || "$identities_json" == "[]" ]]; then
  echo "No identities found in configuration. Nothing to import." >&2
  exit 1
fi

resource_group_id="/subscriptions/${subscription_id}/resourceGroups/${resource_group_name}"
import_if_missing "azurerm_resource_group.main" "$resource_group_id"

identity_context_tsv="$(mktemp)"
cleanup() {
  rm -f "$identity_context_tsv"
}
trap cleanup EXIT

while IFS= read -r identity_key; do
  if [[ -z "$identity_key" ]]; then
    continue
  fi

  managed_identity_name="id-${identity_key}-${locationshort}-${environment}"

  identity_lookup_json="$(az identity show \
    --resource-group "$resource_group_name" \
    --name "$managed_identity_name" \
    -o json 2>/dev/null || true)"

  if [[ -z "$identity_lookup_json" ]]; then
    identity_candidates_json="$(az identity list \
      --query "[?name=='${managed_identity_name}'].{id:id,principalId:principalId,resourceGroup:resourceGroup}" \
      -o json)"
    candidate_count="$(echo "$identity_candidates_json" | jq -r 'length')"

    if [[ "$candidate_count" -eq 1 ]]; then
      identity_lookup_json="$(echo "$identity_candidates_json" | jq '.[0]')"
      found_rg="$(echo "$identity_lookup_json" | jq -r '.resourceGroup')"
      echo "Identity '${managed_identity_name}' found in resource group '${found_rg}' (fallback lookup)."
    elif [[ "$candidate_count" -gt 1 ]]; then
      echo "Multiple identities found with name '${managed_identity_name}'. Please resolve ambiguity or align resource group naming." >&2
      exit 1
    else
      echo "Identity '${managed_identity_name}' was not found. Expected resource group: '${resource_group_name}'." >&2
      exit 1
    fi
  fi

  identity_id="$(echo "$identity_lookup_json" | jq -r '.id')"
  principal_id="$(echo "$identity_lookup_json" | jq -r '.principalId')"

  if [[ -z "$identity_id" || -z "$principal_id" ]]; then
    echo "Could not resolve identity or principal ID for: $managed_identity_name" >&2
    exit 1
  fi

  import_if_missing "azurerm_user_assigned_identity.main[\"${identity_key}\"]" "$identity_id"

  printf '%s\t%s\t%s\n' "$identity_key" "$identity_id" "$principal_id" >> "$identity_context_tsv"
done < <(
  echo "$identities_json" | jq -r '.[].name'
)

while IFS=$'\t' read -r identity_key credential_name; do
  if [[ -z "$identity_key" || -z "$credential_name" ]]; then
    continue
  fi

  identity_id="$(awk -F '\t' -v key="$identity_key" '$1 == key { print $2; exit }' "$identity_context_tsv")"
  if [[ -z "$identity_id" ]]; then
    echo "Identity ID missing in script context for key: $identity_key" >&2
    exit 1
  fi

  federated_credential_id="${identity_id}/federatedIdentityCredentials/${credential_name}"
  existing_federated_credential_id="$(az resource show --ids "$federated_credential_id" --query id -o tsv 2>/dev/null || true)"
  if [[ -z "$existing_federated_credential_id" ]]; then
    echo "Warning: federated credential '${credential_name}' was not found for identity '${identity_key}'. Skipping import for this credential."
    continue
  fi

  import_if_missing "azurerm_federated_identity_credential.main[\"${identity_key}/${credential_name}\"]" "$existing_federated_credential_id"
done < <(
  echo "$identities_json" | jq -r '.[] as $i | ($i.federated_credentials // [])[]? | [$i.name, .name] | @tsv'
)

while IFS= read -r identity_key; do
  if [[ -z "$identity_key" ]]; then
    continue
  fi

  principal_id="$(awk -F '\t' -v key="$identity_key" '$1 == key { print $3; exit }' "$identity_context_tsv")"
  if [[ -z "$principal_id" ]]; then
    echo "Principal ID missing in script context for key: $identity_key" >&2
    exit 1
  fi

  role_assignment_id="$(az role assignment list \
    --scope "$storage_scope" \
    --assignee-object-id "$principal_id" \
    --role "Storage Blob Data Contributor" \
    --query '[0].id' \
    -o tsv 2>/dev/null || true)"

  if [[ -z "$role_assignment_id" ]]; then
    echo "Warning: no existing Storage Blob Data Contributor role assignment found for identity '$identity_key' on scope '$storage_scope'. Skipping import for this role assignment."
    continue
  fi

  import_if_missing "azurerm_role_assignment.storage_blob_contributor[\"${identity_key}\"]" "$role_assignment_id"
done < <(
  echo "$identities_json" | jq -r '.[].name'
)

echo "Import completed successfully."
echo "Recommended next step: terraform plan -var-file=$(basename "$VAR_FILE")"
