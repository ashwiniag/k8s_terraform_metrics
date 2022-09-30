# -------------outputs----------------

output "vpc_id" {
  value = data.aws_vpc.host.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.private.ids
}

output "vm_metrics_subnet_id" {
  value = data.aws_subnet.vm_metrics_subnet.id
}

output "vm_metrics_subnet_cidr" {
  value = data.aws_subnet.vm_metrics_subnet.cidr_block
}

output "node_role_arn" {
  value = local.role_eks_node["arn"]
}

output "node_role_name" {
  value = local.role_eks_node["name"]
}

# -------------variables--------------
variable "vm_metrics_node_group" {
  type = object({
    flavor       = string
    desired_size = number
    max_size     = number
    min_size     = number
    disk_size    = number
  })
}

variable zone {
  default = "a"
}

locals {
  zone = "${local.region}${var.zone}"
  node_group      = "vm_metrics"
}

# -------------data------------------
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Type"
    values = ["private-subnet"]
  }
}

data "aws_vpc" "host" {
  id = local.vpc_id
}

data "aws_subnet" "vm_metrics_subnet" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Type"
    values = ["private-subnet"]
  }

  filter {
    name   = "availability-zone"
    values = [local.zone]
  }
}

# -------------resources--------------

resource "aws_iam_role_policy_attachment" "eks-node-EKSWorkerNode" {
  role       = local.role_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks-node-ECRReadOnly" {
  role       = local.role_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource aws_iam_role_policy_attachment "eks-Node" {
  role       = local.role_eks_node.name
  policy_arn = local.policy_eks_node
}
#│ aws-node {"level":"info","ts":"2022-09-27T10:39:29.247Z","caller":"entrypoint.sh","msg":"Retrying waiting for IPAM-D"}
# https://www.anycodings.com/questions/aws-eks-nodes-creation-failure
resource "aws_iam_role_policy_attachment" "eks-node-EKS-CNI" {
  role       = local.role_eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# single zone
resource "aws_eks_node_group" "vm_metrics" {
  cluster_name    = local.eks_cluster_name
  node_group_name = "${var.host_infra}-node-${local.node_group}"
  node_role_arn   = local.role_eks_node["arn"]
  subnet_ids      = [data.aws_subnet.vm_metrics_subnet.id]
  instance_types  = [var.vm_metrics_node_group.flavor]
  disk_size       = var.vm_metrics_node_group.disk_size

  labels = {
    group = local.node_group
  }

  scaling_config {
    desired_size = var.vm_metrics_node_group.desired_size
    max_size     = var.vm_metrics_node_group.max_size
    min_size     = var.vm_metrics_node_group.min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-node-EKSWorkerNode,
    aws_iam_role_policy_attachment.eks-node-ECRReadOnly,
    aws_iam_role_policy_attachment.eks-Node,
    aws_iam_role_policy_attachment.eks-node-EKS-CNI
  ]
}