provider "azurerm" {
  features {}
}
data "azurerm_client_config" "current" {}


locals {
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


module "resource_group" {
  source              = "./modules/resource_group"
  resource_group_name = "apiK8sRss"
  location            = "East US"
}