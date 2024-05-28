provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

module "acr" {
  source                  = "./modules/acr"
  location                = azurerm_resource_group.rg.location
  container_registry_name = var.container_registry_name
  resource_group_name     = azurerm_resource_group.rg.name

  lifecycle {
    prevent_destroy = true
  }
}

module "k8s_cluster" {
  source              = "./modules/k8s_cluster"
  deployment_name     = var.deployment_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "ra" {
  principal_id                     = module.k8s_cluster.akc.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = module.acr.acr.id
  skip_service_principal_aad_check = true
}

output "client_certificate" {
  value     = module.k8s_cluster.akc.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value     = module.k8s_cluster.akc.kube_config_raw
  sensitive = true
}
