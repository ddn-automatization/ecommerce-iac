variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the resources."
}

variable "location" {
  type        = string
  default     = "East US"
  description = "The location/region where the resources will be created."
}

variable "container_registry_name" {
  type        = string
  default     = "ddncr"
  description = "The name of the container registry."
}