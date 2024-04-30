# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
/*
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
  path                = "deploytest"
  protocols           = ["https", "http"]
  service_url         = "http://52.230.145.205"

  import {
    content_format = "swagger-link-json"
    content_value  = "http://conferenceapi.azurewebsites.net/?format=json"
  }
}



# Subredes

resource "azurerm_virtual_network" "virtual_network" {
  name =  "resources-vnet"
  location = azurerm_resource_group.apigw-k8s-resource.location
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  address_space = "192.168.1.0/16"
}
 
resource "azurerm_subnet" "aks_subnet" {
  name = "aks"
  resource_group_name  = azurerm_resource_group.apigw-k8s-resource.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes = "192.168.0.0/24"
}

resource "azurerm_subnet" "app_gwsubnet" {
  name = "appgw"
  resource_group_name  = azurerm_resource_group.apigw-k8s-resource.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes = "192.168.2.0/24"
}






resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "testk8s"
  location            = azurerm_resource_group.apigw-k8s-resource.location
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  dns_prefix          = "k8sdns"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  http_application_routing_enabled = true

  tags = {
    Environment = "Test"
  }
}

resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.k8s]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.k8s.kube_config_raw
}


resource "azurerm_dns_zone" "dns" {
  name                = "www.ecommerceadmintesting.azurequickstart.org"
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
}

resource "azurerm_dns_a_record" "example" {
  name                = "www"
  zone_name           = azurerm_dns_zone.dns.name
  resource_group_name = azurerm_resource_group.apigw-k8s-resource.name
  ttl                 = 3600
  records             = ["52.230.145.205"]  
}
*/

#**********************Recursos Necesarios***************************
provider "azurerm" {
  features {}
}
# Grupo de recursos sobre lo que se creara todo el codigo
resource "azurerm_resource_group" "apiK8sRss" {
  name     = "testingApiK8sResourceGroup"
  location = "East US"
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
# fluya desde la puerta de enlace de aplicaciones a los pods del clúster. La interconexión de las 
# dos redes virtuales requiere la ejecución del comando Azure CLI dos veces por separado, para
# garantizar que la conexión sea bidireccional. El primer comando creará una conexión de interconexión
# desde la red virtual de la puerta de enlace de aplicaciones a la red virtual AKS; el segundo comando 
# creará una conexión de interconexión en la otra dirección.

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







/*

 Creación de la red virtual
resource "azurerm_virtual_network" "vn-rss" {
  name                = "myVirtualNetwork"
  resource_group_name = azurerm_resource_group.api-k8s-rss.name
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.api-k8s-rss.location
}

# Subnet de cluster
resource "azurerm_subnet" "vn-sb-aks" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.api-k8s-rss.name
  virtual_network_name = azurerm_virtual_network.vn-rss.name
  address_prefixes     = ["192.168.0.0/24"]
}

# Cluster AKS
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "myCluster"
  location            = azurerm_resource_group.api-k8s-rss.location
  resource_group_name = azurerm_resource_group.api-k8s-rss.name
  dns_prefix          = "myClusterDNS"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.vn-sb-aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }
}

resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.aks]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.aks.kube_config_raw
}

# Puerta de enlace de aplicación
resource "azurerm_subnet" "vn-sb-api" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.api-k8s-rss.name
  virtual_network_name = azurerm_virtual_network.vn-rss.name
  address_prefixes     = ["10.0.1.0/24"]
}



resource "azurerm_application_gateway" "example" {
  name                = "myApplicationGateway"
  resource_group_name = azurerm_resource_group.api-k8s-rss.name
  location            = azurerm_resource_group.api-k8s-rss.location
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name      = "myGatewayIpConfiguration"
    subnet_id = azurerm_subnet.vn-sb-api.id
  }
  frontend_ip_configuration {
    name                 = "myFrontendIp"
    public_ip_address_id = azurerm_public_ip.ip.id
  }
}

# Peering entre redes virtuales
resource "azurerm_virtual_network_peering" "to_aksvnet" {
  name                         = "AppGWtoAKSVnetPeering"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.example.name
  remote_virtual_network_id    = azurerm_kubernetes_cluster.example.network_profile[0].network_plugin[0].azure.network_id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "to_appgwvnet" {
  name                         = "AKStoAppGWVnetPeering"
  resource_group_name          = azurerm_kubernetes_cluster.example.node_resource_group
  virtual_network_name         = azurerm_kubernetes_cluster.example.network_profile[0].network_plugin[0].azure.vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.example.id
  allow_virtual_network_access = true
}

*/
