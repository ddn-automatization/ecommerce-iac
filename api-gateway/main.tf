# Para desplegar este ejemplo necesitas primero crear todos los recursos con terraform apply
# Luego debes extrare el id del api gateway ya desplegado con el siguiente comando
# appgwId=$(az network application-gateway show -n myApplicationGateway -g testingApiK8sResourceGroup -o tsv --query "id")
# Luego debes habilitar el controlador ingress y unirlo con dicha api con el comando
# az aks enable-addons -n myCluster -g testingApiK8sResourceGroup -a ingress-appgw --appgw-id $appgwId
# Luego, deberas mover el archivo kubeconfig a tu contexto local para poder usar los comandos
# de kubectl en tu pc y comunicarse directamente con la nube
# con mv kubeconfig ~/.kube/config se realiza dicha accion
# luego puedes crear con kubectl el cluster-example.yaml o obtenerlo del repo oficial
# kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml 
# luego kubectl get ingress para ver su ip o en puedes ir a azure, ver el recurso api gateway y la 
# DIR IP FRONTEND que aparezca en el overview de tu apigateway deberia ser ahora el punto de acceso a
# los recursos creados en el cluster
# Para habilitar la union del cluster con el key vault se ejecuta el comando
# az aks enable-addons --addons azure-keyvault-secrets-provider --name myCluster --resource-group testingApiK8sResourceGroup


# main.tf

# Provider configuration
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  # Aqui se definen variables locales asociados a varios recursos de red para mantener
  # la lebibilidad, consistencia y reutilizacion de dichas variables en el codigo
  backend_address_pool_name      = "${module.networking.api_vnet_name}-beap"
  frontend_port_HTTP_name        = "${module.networking.api_vnet_name}-fe_HTTP_port"
  frontend_port_HTTPS_name       = "${module.networking.api_vnet_name}-fe_HTTPS_port"
  frontend_ip_configuration_name = "${module.networking.api_vnet_name}-feip"
  http_setting_name              = "${module.networking.api_vnet_name}-be-htst"
  listener_name                  = "${module.networking.api_vnet_name}-httplstn"
  request_routing_rule_name      = "${module.networking.api_vnet_name}-rqrt"
  redirect_configuration_name    = "${module.networking.api_vnet_name}-rdrcfg"
  current_user_id                = coalesce(null, data.azurerm_client_config.current.object_id)
}

# Module for creating the Azure Resource Group
module "resource_group" {
  source              = "./modules/resource_group"
  resource_group_name = "apiK8sRss"
  location            = "East US"
}


module "networking" {
  source = "./modules/networking"

  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location

  public_ip_name    = "myTestingPublicIp"
  allocation_method = "Static"
  sku               = "Standard"

  api_vnet_name                       = "myTestingApiVnet"
  api_vnet_address_space              = ["10.1.0.0/16"]
  api_gateway_subnet_name             = "apiGatewaySubnet"
  api_gateway_subnet_address_prefixes = ["10.1.1.0/24"]

  cluster_vnet_name               = "myTestingClusterVnet"
  cluster_vnet_address_space      = ["10.2.0.0/16"]
  cluster_subnet_name             = "clusterSubnet"
  cluster_subnet_address_prefixes = ["10.2.1.0/24"]

  appgw_to_cluster_peering_name = "AppGWtoClusterVnetPeering"
  cluster_to_appgw_peering_name = "ClustertoAppGWVnetPeering"
}


# Module for creating the Azure Application Gateway
module "application_gateway" {
  source                   = "./modules/application_gateway"
  application_gateway_name = "myApplicationGateway"
  resource_group_name      = module.resource_group.resource_group_name
  location                 = module.resource_group.location

  sku_name                 = "Standard_v2"
  sku_tier                 = "Standard_v2"
  sku_capacity             = 2

  gateway_ip_configuration_name = "appGatewayIpConfig"
  subnet_id                     = module.networking.api_gateway_subnet_id

  frontend_ip_configuration_name    = local.frontend_ip_configuration_name
  public_ip_address_id           = module.networking.public_ip_id

  frontend_port_name             = local.frontend_port_HTTP_name
  frontend_port_port             = 80

  backend_address_pool_name             = local.backend_address_pool_name

  backend_http_settings_name            = local.http_setting_name
  cookie_based_affinity                 = "Disabled"
  backend_http_settings_port            = 80
  backend_http_settings_protocol        = "Http"
  backend_http_settings_request_timeout = 60

  http_listener_name                           = local.listener_name 
  http_listener_frontend_ip_configuration_name = local.frontend_ip_configuration_name
  http_listener_frontend_port_name             = local.frontend_port_HTTP_name
  http_listener_protocol                       = "Http"

  request_routing_rule_name                       = local.request_routing_rule_name
  request_routing_rule_rule_type                  = "Basic"
  request_routing_rule_priority                   = 9
  request_routing_rule_http_listener_name         = local.listener_name
  request_routing_rule_backend_address_pool_name  = local.backend_address_pool_name
  request_routing_rule_backend_http_settings_name = local.http_setting_name
}



module "aks_cluster" {
  source              = "./modules/aks_cluster"
  cluster_name        = "myCluster"
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location
  dns_prefix          = "myClusterDns"

  node_pool_name  = "nodepool"
  node_count      = 1
  vm_size         = "Standard_D2_v2"
  os_disk_size_gb = 40
  vnet_subnet_id  = module.networking.cluster_subnet_id

  network_plugin = "azure"
  identity_type  = "SystemAssigned"

  local_file_name = "kubeconfig"
}

# Module for creating the Azure Key Vault
module "key_vault" {
  source                     = "./modules/key_vault"
  key_vault_name             = "myKeyVault-1099"
  resource_group_name        = module.resource_group.resource_group_name
  location                   = module.resource_group.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  sku_name                   = "standard"
  object_id                  = local.current_user_id
  key_permissions            = ["Get", "Create", "List", "Delete", "Purge", "Recover", "SetRotationPolicy", "GetRotationPolicy"]
  secret_permissions         = ["Get", "Set", "List", "Delete", "Purge", "Recover"]
  certificate_permissions    = ["Get"]
  secret_names               = ["mySecret1", "mySecret2"] # Example secret names
  secret_values              = ["szechuan", "shashlik"]   # Example secret values
  key_names                  = ["myKey1", "myKey2"]       # Example key names
  key_types                  = ["RSA", "RSA"]             # Example key types
  key_sizes                  = [2048, 2048]               # Example key sizes
  key_opts                   = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  time_before_expiry         = "P30D"
  expire_after               = "P90D"
  notify_before_expiry       = "P29D"
}


output "resource_group_name" {
  value = module.resource_group.resource_group_name
}

output "application_gateway_name" {
  value = module.application_gateway.application_gateway_name
}

output "cluster_name" {
  value = module.aks_cluster.cluster_name
}


# Recurso null_resource para ejecutar un script de bash externo
resource "null_resource" "execute_script" {
  # Dependencia de otros recursos, por ejemplo, el recurso de aplicación de puerta de enlace
  depends_on = [
    module.application_gateway,
    module.key_vault,
    module.aks_cluster
    # Agrega otros recursos de los que depende tu script aquí
  ]

  # Ejecutar un script de bash externo después de aplicar los recursos dependientes
  provisioner "local-exec" {
    command = "chmod +x script.sh && ./script.sh"
  }
}



























/*
#**********************Recursos Necesarios***************************
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
# Grupo de recursos sobre lo que se creara todo el codigo
resource "azurerm_resource_group" "apiK8sRss" {
  name     = "testingApiK8sResourceGroup"
  location = "East US"
}

data "azurerm_client_config" "current" {}

#**************************Variables Locales***************************
locals {
  # Aqui se definen variables locales asociados a varios recursos de red para mantener
  # la lebibilidad, consistencia y reutilizacion de dichas variables en el codigo
  backend_address_pool_name      = "${azurerm_virtual_network.apiVnet.name}-beap"
  frontend_port_HTTP_name        = "${azurerm_virtual_network.apiVnet.name}-fe_HTTP_port"
  frontend_port_HTTPS_name       = "${azurerm_virtual_network.apiVnet.name}-fe_HTTPS_port"
  frontend_ip_configuration_name = "${azurerm_virtual_network.apiVnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.apiVnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.apiVnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.apiVnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.apiVnet.name}-rdrcfg"
  current_user_id                = coalesce(null, data.azurerm_client_config.current.object_id)
}
#**********************Network Blocks*******************************

# Ip Publica para asociarla al Api Gateway
resource "azurerm_public_ip" "publicIp" {
  name                = "myTestingPublicIp"
  location            = azurerm_resource_group.apiK8sRss.location
  resource_group_name = azurerm_resource_group.apiK8sRss.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Virtual Network sobre lo que estara asociado el Api Gateway
resource "azurerm_virtual_network" "apiVnet" {
  name                = "myTestingApiVnet"
  resource_group_name = azurerm_resource_group.apiK8sRss.name
  location            = azurerm_resource_group.apiK8sRss.location
  address_space       = ["10.1.0.0/16"]
}
# Subred en la que estara el Api Gateway
resource "azurerm_subnet" "apiGatewaySubnet" {
  name                 = "apiGatewaySubnet"
  resource_group_name  = azurerm_resource_group.apiK8sRss.name
  virtual_network_name = azurerm_virtual_network.apiVnet.name
  address_prefixes     = ["10.1.1.0/24"]
}
# Virtual Network sobre lo que estara asociado el Cluster
resource "azurerm_virtual_network" "clusterVnet" {
  name                = "myTestingClusterVnet"
  resource_group_name = azurerm_resource_group.apiK8sRss.name
  location            = azurerm_resource_group.apiK8sRss.location
  address_space       = ["10.2.0.0/16"]
}
# Subred en la que estara el Cluster
resource "azurerm_subnet" "clusterSubnet" {
  name                 = "clusterSubnet"
  resource_group_name  = azurerm_resource_group.apiK8sRss.name
  virtual_network_name = azurerm_virtual_network.clusterVnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

#**********************Key Vault*******************************

# Definicion del recurso azurerm_key_vault
resource "azurerm_key_vault" "myKeyVault-1099" {
  name                       = "myKeyVault-1099"
  location                   = azurerm_resource_group.apiK8sRss.location
  resource_group_name        = azurerm_resource_group.apiK8sRss.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  sku_name                   = "standard"

  # Politica de acceso al Key Vault
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = local.current_user_id

    key_permissions = [
      "Get", "Create", "List", "Delete", "Purge", "Recover", "SetRotationPolicy", "GetRotationPolicy"
    ]

    secret_permissions = [
      "Get", "Set", "List", "Delete", "Purge", "Recover"
    ]

    certificate_permissions = [
      "Get"
    ]
  }
}

# Definicion del recurso azurerm_key_vault_secret
resource "azurerm_key_vault_secret" "myKeyVaultSecret" {
  name         = "myKeyVaultSecret"
  value        = "szechuan"
  key_vault_id = azurerm_key_vault.myKeyVault-1099.id
}

# Definicion del recurso azurerm_key_vault_key
resource "azurerm_key_vault_key" "generated" {
  name         = "generated-certificate"
  key_vault_id = azurerm_key_vault.myKeyVault-1099.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}






#*************************Creacion del Api Gateway*************************

# Creacion del Api Gateway
resource "azurerm_application_gateway" "myApplicationGateway" {
  name                = "myApplicationGateway"
  resource_group_name = azurerm_resource_group.apiK8sRss.name
  location            = azurerm_resource_group.apiK8sRss.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    # Aqui se configura la dir ip del Api Gateway
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.apiGatewaySubnet.id
  }

  frontend_ip_configuration {
    # Aqui se define la configuracion de la direccion IP frontal, en este caso, asociándola a una dirección IP publica
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.publicIp.id
  }

  frontend_port {
    # Aqui se especifica el puerto frontal para HTTP
    name = local.frontend_port_HTTP_name
    port = 80
  }

  backend_address_pool {
    # Crea un grupo de direcciones de backend para enrutar el trafico
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    # Configura los ajustes de HTTP, como el puerto, el protocolo, y el tiempo de espera de la solicitud
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    # Define un escucha HTTP que se asocia con la configuración de direccion IP frontal y el puerto frontal
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_HTTP_name
    protocol                       = "Http"
  }

  request_routing_rule {
    # Establece una regla de enrutamiento que vincula el escucha HTTP, el grupo de direcciones de backend y la configuración de HTTP
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 9
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

#************************************Cluster********************************************

# Creacion del cluster de Kubernetes en Azure
resource "azurerm_kubernetes_cluster" "myCluster" {
  name                = "myCluster"
  location            = azurerm_resource_group.apiK8sRss.location
  resource_group_name = azurerm_resource_group.apiK8sRss.name
  dns_prefix          = "myClusterDns" # Prefijo DNS opcional para el clúster AKS

  # Configuracion del grupo de nodos por defecto
  default_node_pool {
    name            = "nodepool"
    node_count      = 1
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 40
    vnet_subnet_id  = azurerm_subnet.clusterSubnet.id
  }

  # Perfil de red del cluster
  network_profile {
    network_plugin = "azure"
  }

  # Identidad del cluster
  identity {
    type = "SystemAssigned"
  }

  /*
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.myApplicationGateway.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
 

}

# Generacion del archivo kubeconfig para poder linkear kubectl de forma local con el cluster en la nube
resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.myCluster]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.myCluster.kube_config_raw
}



#**********************************Union de redes virtuales********************************
# Dado que ha desplegado el clúster AKS en su propia red virtual y la puerta de enlace de 
# aplicaciones en otra red virtual, tendrá que unir las dos redes virtuales para que el tráfico 
# fluya desde la puerta de enlace de aplicaciones a los pods del clúster.

# Creacion de la relacion de confianza entre las redes virtuales del cluster y de la aplicacion
resource "azurerm_virtual_network_peering" "AppGWtoClusterVnetPeering" {
  name                         = "AppGWtoClusterVnetPeering"
  resource_group_name          = azurerm_resource_group.apiK8sRss.name
  virtual_network_name         = azurerm_virtual_network.apiVnet.name
  remote_virtual_network_id    = azurerm_virtual_network.clusterVnet.id
  allow_virtual_network_access = true
}

# Creacion de la relacion de confianza entre las redes virtuales del cluster y de la aplicacion
resource "azurerm_virtual_network_peering" "ClustertoAppGWVnetPeering" {
  name                         = "ClustertoAppGWVnetPeering"
  resource_group_name          = azurerm_resource_group.apiK8sRss.name
  virtual_network_name         = azurerm_virtual_network.clusterVnet.name
  remote_virtual_network_id    = azurerm_virtual_network.apiVnet.id
  allow_virtual_network_access = true
}
 */
