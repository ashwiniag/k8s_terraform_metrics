# ----------------------outputs----------------
output eks_cluster_name {
  value = local.eks_cluster_name
}

output eks_cluster_certificate {
  value = data.aws_eks_cluster.host.certificate_authority[0].data
}

output eks_cluster_endpoint {
  value = data.aws_eks_cluster.host.endpoint
}

output env {
  value = local.env
}

output region {
  value = local.region
}

# -------------------------data------------------
data "aws_eks_cluster" "host" {
  name = local.eks_cluster_name
}

# ---------------------------resources--------------
provider "kubernetes" {
  host = data.aws_eks_cluster.host.endpoint

  cluster_ca_certificate = base64decode(data.aws_eks_cluster.host.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name]
    command     = "aws"
  }
}