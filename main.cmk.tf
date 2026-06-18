# Customer-managed key (CMK) support for the Search Service.
#
# Background:
#   The hashicorp/azurerm provider's `azurerm_search_service` resource (which pins
#   `Microsoft.Search/searchServices@2025-05-01`) does not expose any argument to set
#   `properties.encryptionWithCmk.serviceLevelEncryptionKey`. That property only exists
#   in the `2026-03-01-preview` API version. We therefore PATCH the freshly-created
#   service with `azapi_update_resource` to apply the CMK configuration.
#
# Idempotency:
#   The PATCH only sets `properties.encryptionWithCmk.serviceLevelEncryptionKey`. The
#   sibling `enforcement` field already managed by `azurerm_search_service` via
#   `customer_managed_key_enforcement_enabled` is left untouched. Because the azurerm
#   resource uses an older API version that has no knowledge of
#   `serviceLevelEncryptionKey`, it will not drift the CMK setting back to
#   service-managed encryption on subsequent applies.
#
# Tracking issue #107: this is the targeted 0.3 fix. A broader refactor that replaces
# `azurerm_search_service` with `azapi_resource` is tracked separately.

data "azurerm_key_vault" "cmk" {
  count = var.customer_managed_key != null ? 1 : 0

  name                = local.cmk_key_vault_name
  resource_group_name = local.cmk_key_vault_resource_group_name
}

resource "azapi_update_resource" "cmk" {
  count = var.customer_managed_key != null ? 1 : 0

  resource_id = azurerm_search_service.this.id
  type        = "Microsoft.Search/searchServices@${var.resource_types.search_searchservices}"
  body = {
    properties = {
      encryptionWithCmk = {
        serviceLevelEncryptionKey = merge(
          {
            keyVaultUri     = data.azurerm_key_vault.cmk[0].vault_uri
            keyVaultKeyName = var.customer_managed_key.key_name
            identity = {
              "@odata.type" = "#Microsoft.Azure.Search.DataNoneIdentity"
            }
          },
          var.customer_managed_key.key_version == null ? {} : {
            keyVaultKeyVersion = var.customer_managed_key.key_version
          }
        )
      }
    }
  }
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  retry          = var.retry
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
