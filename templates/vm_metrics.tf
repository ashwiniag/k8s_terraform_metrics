# -------------------outputs----------------

# -------------------variables--------------
locals {
  name = "victoriametrics"
}

variable "env" {}

//variable namespace {}

variable "vm_metrics" {
  type = map(string)
  default = {
    port                = "8428"
    target_port         = "8428"
    storage_mount_point = "/storage"
  }
}

variable "cluster" {}

variable "victoriametrics" {
  type = map(string)
  default = {
    port                = "8428"
    target_port         = "8428"
    storage_mount_point = "/storage"
    count               = "1"
  }
}

variable "victoriametrics_version" {
  default = "v1.64.0"
  type    = string
}

variable "victoriametrics_retention_period" {
  default = "1d"
  type    = string
}

variable "victoriametrics_max_labels_per_timeseries" {
  default = "100"
  type    = string
}

variable "victoriametrics_search_cache_timestamp_offset" {
  default = "5m0s"
  type    = string
}

variable "victoriametrics_search_max_concurrent_requests" {
  default = "8"
  type    = string
}

variable "victoriametrics_search_max_queue_duration" {
  default = "10s"
  type    = string
}

variable "victoriametrics_search_max_query_duration" {
  default = "30s"
  type    = string
}


variable "victoriametrics_search_max_uniq_timeseries" {
  default = "999999"
  type    = string
}

variable "victoriametrics_availability_zone_affinity" {
  default = "ap-south-1a"
  type    = string
}

variable "internet_facing" {
  type = bool
}

# -------------------resources--------------

resource "kubernetes_namespace" "vm_metrics" {
  metadata {
    name = local.name
  }
}

resource "kubernetes_deployment" "vm_metrics" {

  metadata {
    name      = "${local.name}-dply"
    namespace = local.name
    labels = {
      app = local.name
    }
  }

  spec {
    replicas = var.victoriametrics.count

    selector {
      match_labels = {
        app = local.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.name
        }
      }

      spec {
        restart_policy = "Always"

        node_selector = {
          group = "vm_metrics"
        }

        container {
          image             = "victoriametrics/victoria-metrics:${var.victoriametrics_version}"
          name              = local.name
          image_pull_policy = "Always"

          args = [
            "--storageDataPath=${var.victoriametrics.storage_mount_point}/${local.name}/vmdata/",
            "--httpListenAddr=:${var.victoriametrics.port}",
            "--retentionPeriod=${var.victoriametrics_retention_period}",
            "--maxLabelsPerTimeseries=${var.victoriametrics_max_labels_per_timeseries}",
            "--search.cacheTimestampOffset=${var.victoriametrics_search_cache_timestamp_offset}",
            "--search.maxConcurrentRequests=${var.victoriametrics_search_max_concurrent_requests}",
            "--search.maxQueueDuration=${var.victoriametrics_search_max_queue_duration}",
            "--search.maxUniqueTimeseries=${var.victoriametrics_search_max_uniq_timeseries}",
            "--search.maxQueryDuration=${var.victoriametrics_search_max_query_duration}"
          ]

          port {
            name           = "app"
            container_port = var.victoriametrics.port
            protocol       = "TCP"
          }

          port {
            name           = "alb"
            container_port = "80"
            protocol       = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "vm_metrics_ingress_service" {
  metadata {
    name      = "${local.name}-ing-svc"
    namespace = local.name
    labels = {
      app = local.name
    }
  }

  spec {
    selector = {
      app = local.name
    }

    port {
      name        = "connection"
      port        = 80
      target_port = var.victoriametrics.port
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "vm_metrics_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "${local.name}-ingress"
    namespace = local.name

    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = var.internet_facing ? "internet-facing" : "internal"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      //"alb.ingress.kubernetes.io/certificate-arn" = "xxxxx"
      //"alb.ingress.kubernetes.io/load-balancer-name" = "${local.name}-loadtest-alb"
      "alb.ingress.kubernetes.io/subnets"         = var.internet_facing ? join(", ", local.public_subnet_ids) : join(", ", local.private_subnet_ids)
     // "alb.ingress.kubernetes.io/group.name"      = local.env
      "alb.ingress.kubernetes.io/group.order"     = "1"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service.vm_metrics_ingress_service.metadata.0.name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

