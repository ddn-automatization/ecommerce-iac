provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

data "azurerm_container_registry" "acr" {
  name                = azurerm_container_registry.acr.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_kubernetes_cluster" "akc" {
  name                = "${var.resource_group_name}-aks1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_role_assignment" "ra" {
  principal_id                     = azurerm_kubernetes_cluster.akc.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.akc.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.akc.kube_config_raw
  sensitive = true
}
