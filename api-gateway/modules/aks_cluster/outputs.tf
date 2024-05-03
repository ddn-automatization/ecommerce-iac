output "aks_cluster_id" {
  description = "The ID of the created AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster.id
}

output "cluster_name" {
  description = "The ID of the created AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster.name
}
