output lab_id {
  value       = azurerm_dev_test_lab.lab.id
}

output lab_vault_id {
  value       = data.azurerm_key_vault.lab_vault.id
}

output network_id {
    value     = azurerm_dev_test_virtual_network.network.id
}
