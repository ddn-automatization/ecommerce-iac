# Create an Azure Kubernetes Service (AKS) cluster
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  # Name of the AKS cluster
  name = var.cluster_name
  # Location where the AKS cluster will be created
  location = var.location
  # Resource group where the AKS cluster will be created
  resource_group_name = var.resource_group_name
  # DNS prefix for the AKS cluster
  dns_prefix = var.dns_prefix

  # Default node pool for the AKS cluster
  default_node_pool {
    # Name of the default node pool
    name = var.node_pool_name
    # Number of nodes in the default node pool
    node_count = var.node_count
    # Size of the virtual machines in the default node pool
    vm_size = var.vm_size
    # Size of the operating system disk in gigabytes
    os_disk_size_gb = var.os_disk_size_gb
    # ID of the virtual network subnet
    vnet_subnet_id = var.vnet_subnet_id
    # Temporary name for the node pool during rotation
    temporary_name_for_rotation = "nodepooltemp" # Agregar nombre temporal para la rotación
  }

  # Network profile for the AKS cluster
  network_profile {
    # Network plugin used by the AKS cluster
    network_plugin = var.network_plugin
  }

  # Identity for the AKS cluster
  identity {
    # Type of identity for the AKS cluster
    type = var.identity_type
  }

  # Key vault secrets provider for the AKS cluster
  key_vault_secrets_provider {
    # Update the secrets on a regular basis
    secret_rotation_enabled = var.secret_rotation_enabled
  }

  # Enable private cluster (commented out)
  //private_cluster_enabled = var.private_cluster_enabled
}

# Create a local file containing the Kubernetes configuration for the AKS cluster
resource "local_file" "kubeconfig" {
  # Depends on the AKS cluster
  depends_on = [azurerm_kubernetes_cluster.aks_cluster]
  # Name of the local file
  filename = var.local_file_name
  # Content of the local file, which is the Kubernetes configuration for the AKS cluster
  content = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
}

# Create a Kubernetes service account for workload identity (commented out)
/*
resource "kubernetes_service_account" "workload_identity_sa" {
  # Depends on the AKS cluster
  depends_on = [azurerm_kubernetes_cluster.aks_cluster]
  metadata {
    # Name of the service account
    name      = var.name_workload_identity
    # Namespace for the service account
    namespace = var.namespace
    # Annotations for the service account
    annotations = {
      "azure.workload.identity/client-id" = var.user_assigned_client_id
    }
  }
}
*/
