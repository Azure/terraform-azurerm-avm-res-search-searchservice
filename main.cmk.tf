# -----------------------------------------------------------------------------
# Customer-managed key (CMK) encryption for the Search Service.
#
# The writable `properties.encryptionWithCmk` block — both the `enforcement`
# policy and the `serviceLevelEncryptionKey` configuration — is only available
# on PREVIEW API versions of `Microsoft.Search/searchServices`
# (2024-06-01-preview onwards). The primary `azapi_resource.this` is
# intentionally pinned to the stable GA API (SFR1): on that API `enforcement`
# is a read-only status field and `serviceLevelEncryptionKey` does not exist.
# We therefore apply the entire CMK block here with a dedicated preview-API
# PATCH, keeping the primary resource on the stable API.
#
# Migration: this preserves the `azapi_update_resource.cmk[0]` address used by
# the 0.3.x release, so upgrading consumers keep their CMK state in place with
# no destroy / re-create. The 0.3.x `data.azurerm_key_vault.cmk` lookup is gone
# — the Key Vault URI is now derived from `customer_managed_key.key_vault_resource_id`.
# -----------------------------------------------------------------------------

resource "azapi_update_resource" "cmk" {
  count = local.encryption_with_cmk_body == null ? 0 : 1

  resource_id = azapi_resource.this.id
  type        = var.resource_types.search_search_services_cmk
  body = {
    properties = {
      encryptionWithCmk = local.encryption_with_cmk_body
    }
  }
  read_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  retry        = var.retry

  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
