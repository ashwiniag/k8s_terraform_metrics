variable "host_infra" {}

data "terraform_remote_state" "host" {
  backend = "s3"

  config = {
    bucket = "ashwiniag-practices"
    key    = "terraform/${var.host_infra}/infra/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  vpc_id                  = data.terraform_remote_state.host.outputs.vpc_id
  private_subnet_ids      = data.terraform_remote_state.host.outputs.private_subnet_ids
  public_subnet_ids       = data.terraform_remote_state.host.outputs.public_subnet_ids
  region                  = data.terraform_remote_state.host.outputs.region
  eks_cluster_arn         = data.terraform_remote_state.host.outputs.eks_cluster_arn
  eks_cluster_certificate = data.terraform_remote_state.host.outputs.eks_cluster_certificate[0]["data"]
  eks_cluster_name        = data.terraform_remote_state.host.outputs.eks_name
  role_eks_node           = data.terraform_remote_state.host.outputs.role_eks_node
  env                     = data.terraform_remote_state.host.outputs.env
  policy_eks_node         = data.terraform_remote_state.host.outputs.policy_eks_node
  private_route_table_ids = data.terraform_remote_state.host.outputs.private_route_table_ids
  eks_certificate_url     = data.terraform_remote_state.host.outputs.eks_cluster_tls_certificate_url
}
