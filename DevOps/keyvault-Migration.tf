
locals {
  secrets_to_copy = [
    "1001-SMARTLING-214398360-forum",
]
}

# Get the source Key Vault ID
data "azurerm_key_vault" "source_keyvault" {
  name                = var.source_kv_name
  resource_group_name = var.source_kv_rg
}

# Get the target Key Vault ID
data "azurerm_key_vault" "target_keyvault" {
  name                = var.target_kv_name
  resource_group_name = var.target_kv_rg
}

output "source_kv_id" {
  value = data.azurerm_key_vault.source_keyvault.id
  # sensitive   = true
  # description = "description"
  # depends_on  = []
}

# Get the Sectet Value by providing Name from source Key Vault
data "azurerm_key_vault_secret" "source_secrets" {
  for_each     = toset(local.secrets_to_copy)
  name         = each.key
  key_vault_id = data.azurerm_key_vault.source_keyvault.id
}

# Create Secrets in Target KeyVault
resource "azurerm_key_vault_secret" "copied_secrets" {
  for_each     = data.azurerm_key_vault_secret.source_secrets
  name         = each.key
  value        = each.value.value
  key_vault_id = data.azurerm_key_vault.target_keyvault.id
  depends_on = [ data.azurerm_key_vault.source_keyvault ]
}
