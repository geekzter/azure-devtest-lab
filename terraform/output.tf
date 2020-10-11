output custom_network_subnet_id {
  value       = azurerm_subnet.custom_subnet.id
}
output custom_network_id {
  value       = azurerm_virtual_network.custom_network.id
}
output custom_network_lab_id {
  value       = local.lab_custom_network_id
}
output default_network_lab_id {
  value       = azurerm_dev_test_virtual_network.default_network.id
}
output lab_id {
  value       = azurerm_dev_test_lab.lab.id
}
output lab_vault_id {
  value       = azurerm_dev_test_lab.lab.key_vault_id
}
output windows_pool_fqdn {
  value       = [for vm in azurerm_dev_test_windows_virtual_machine.windows_pool : vm.fqdn] 
}
output windows_pool_id {
  value       = [for resource in data.azurerm_resources.windows_pool : resource.resources[0].id] 
}
output windows_pool_lab_id {
  value       = [for vm in azurerm_dev_test_windows_virtual_machine.windows_pool : vm.id] 
}