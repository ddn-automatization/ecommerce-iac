
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
 





# Provider configuration
provider "azurerm" {
  features {
  }
}



data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_key_vault" "example" {
  name                        = "keywithhelmcluster"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

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

resource "random_password" "mysecret" {
  length = 64
}

data "azurerm_key_vault" "keyvault" {
  name                = azurerm_key_vault.example.name
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_key_vault_secret" "mysecret" {
  name         = "mysecret"
  value        = random_password.mysecret.result
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "example-cluster"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "secretexample"
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }
  identity {
    type = "SystemAssigned"
  }
  # enable CSI driver to access key vault
  key_vault_secrets_provider {
    # update the secrets on a regular basis
    secret_rotation_enabled = true
  }
}

resource "azurerm_key_vault_access_policy" "vaultaccess" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = azurerm_key_vault.keyvault.tenant_id
  object_id    = azurerm_kubernetes_cluster.cluster.key_vault_secrets_provider[0].secret_identity[0].object_id
  # cluster access to secrets should be read-only
  secret_permissions = [
    "Get", "List"
  ]
}





provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.cluster.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
  }
}

data "azurerm_key_vault_secrets" "secrets" {
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

resource "helm_release" "aks_secret_provider" {
  name    = "aks-secret-provider"
  chart   = "./aks-secret-provider"
  version = "0.0.1"
  values = [yamlencode({
    vaultName = azurerm_key_vault.keyvault.name
    tenantId  = azurerm_key_vault.keyvault.tenant_id
    clientId  = azurerm_kubernetes_cluster.cluster.key_vault_secrets_provider[0].secret_identity[0].client_id
    secrets   = data.azurerm_key_vault_secrets.secrets.names # secrets to expose
  })]
  force_update = true
}





resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.cluster]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.cluster.kube_config_raw
}
*/