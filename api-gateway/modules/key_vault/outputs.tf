output "key_vault_id" {
  description = "The ID of the created Azure Key Vault."
  value       = azurerm_key_vault.key_vault.id
}
