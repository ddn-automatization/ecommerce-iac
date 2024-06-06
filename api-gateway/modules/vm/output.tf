output "linuxVM_nic_id" {
  value = azurerm_network_interface.linuxVM-PrivIP-nic.id
}

output "name" {
  value = azurerm_linux_virtual_machine.name
}
