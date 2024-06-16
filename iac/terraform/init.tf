terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.7"
}

provider "yandex" {
  token = var.yc_token
  folder_id   = "b1gnhefd903iepjjk423"
}

provider "external" {
  # no configuration needed
}


module "yc-vpc" {
  source              = "github.com/terraform-yc-modules/terraform-yc-vpc.git"
  network_name        = "test-module-network"
  network_description = "Test network created with module"
  private_subnets = [{
    name           = "subnet-1"
    zone           = "ru-central1-a"
    v4_cidr_blocks = ["10.10.0.0/24"]
    }
  ]
}

module "kube" {
  cluster_version = "1.28"
  cluster_name = var.k8s_cluster_name
  source     = "github.com/terraform-yc-modules/terraform-yc-kubernetes.git"
  network_id = module.yc-vpc.vpc_id

  master_locations = [
    for s in module.yc-vpc.private_subnets :
    {
      zone      = s.zone,
      subnet_id = s.subnet_id
    }
  ]

  master_maintenance_windows = [
    {
      day        = "monday"
      start_time = "23:00"
      duration   = "3h"
    }
  ]

  node_groups = {

    "yc-k8s-ng-01" = {
      node_memory = 2
      node_cores = 2
      disk_size = 30
      description = "Kubernetes nodes group 01"
      fixed_scale = {
        size = 1
      }
      node_labels = {
        role        = "worker-01"
        environment = "dev"
      }
#      node_taints = [
#        "node-role=infra:NoSchedule"
#      ]

    },

    "yc-k8s-ng-02" = {
      node_memory = 2
      node_cores = 2
      disk_size = 30
      description = "Kubernetes nodes group 02"
      fixed_scale = {
        size = 1
      }
      node_labels = {
        role        = "worker-02"
        environment = "dev"
      }

      max_expansion   = 1
      max_unavailable = 1
    },

    "yc-k8s-ng-03" = {
      node_memory = 2
      node_cores = 2
      disk_size = 30
      description = "Kubernetes nodes group 03"
      fixed_scale = {
        size = 1
      }
      node_labels = {
        role        = "worker-03"
        environment = "dev"
      }

      max_expansion   = 1
      max_unavailable = 1
    }

  }
}

resource "null_resource" "configure_kubectl" {
  provisioner "local-exec" {
    command = "yc managed-kubernetes cluster get-credentials ${module.kube.cluster_name} --external --force"
  }
}
