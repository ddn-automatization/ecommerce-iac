# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "apigw-k8s-resource" {
  name     = "apigwk8sresources"
  location = "centralus"
  tags = {
    environment = "dev"
  }
}



resource "azurerm_api_management" "api-mg" {
  name                = "apimn-1"
  location            = azurerm_resource_group.apigw-k8s-resource.location
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  publisher_name      = "E-Commerce Admin Example"
  publisher_email     = "ecommerce-admin@example"

  sku_name = "Developer_1"
}


resource "azurerm_api_management_api" "api-mg-api" {
  name                = "apimn-api-1"
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  api_management_name = azurerm_api_management.api-mg.name
  revision            = "1"
  display_name        = "E-CommerceAdminExampleAPI"
  path                = ""
  protocols           = ["https", "http"]
  service_url         = "http://conferenceapi.azurewebsites.net"

  import {
    content_format = "swagger-link-json"
    content_value  = "http://conferenceapi.azurewebsites.net/?format=json"
  }
}


resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "assessment-cluster"
  location            = azurerm_resource_group.apigw-k8s-resource.location
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  dns_prefix          = "assessmentdns"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Test"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "ecommerceAdminContainers"
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  location            = azurerm_resource_group.apigw-k8s-resource.location
  sku                 = "Standard"
  admin_enabled       = true
}

data "azurerm_container_registry" "acr" {
  name                = azurerm_container_registry.acr.name
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
}

resource "azurerm_role_assignment" "role_acrpull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.k8s.kubelet_identity.0.object_id
  skip_service_principal_aad_check = true
}


output "client_certificate" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].client_certificate
  sensitive = true
}

output "kubeconfig" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.k8s.id
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.k8s.fqdn
}

output "aks_node_rg" {
  value = azurerm_kubernetes_cluster.k8s.node_resource_group
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

resource "local_file" "kubeconfig" {
  depends_on   = [azurerm_kubernetes_cluster.k8s]
  filename     = "kubeconfig"
  content      = azurerm_kubernetes_cluster.k8s.kube_config_raw
}



