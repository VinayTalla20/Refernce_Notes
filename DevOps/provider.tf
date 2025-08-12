
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
  }
}

provider "azurerm" {
  features {}
    subscription_id = var.subscription_id
    tenant_id       = var.aks_service_principal_tenant_id
    client_id       = var.aks_service_principal_app_id
    client_secret = var.aks_service_principal_client_secret
    resource_provider_registrations = "none"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.k8s.kube_admin_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.cluster_ca_certificate)
  
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    host                   = azurerm_kubernetes_cluster.k8s.kube_admin_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_admin_config.0.cluster_ca_certificate)
  }
}
