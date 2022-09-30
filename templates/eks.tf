# ------------outputs------------------
output "eks_cluster_arn" {
  value = aws_eks_cluster.eks_cluster.arn
}

output "eks_cluster_certificate" {
  value = aws_eks_cluster.eks_cluster.certificate_authority
}

output "eks_name" {
  value = aws_eks_cluster.eks_cluster.id
}

output "eks_cluster_tls_certificate_url" {
  value = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "policy_eks_node" {
  value = aws_iam_policy.eks_node_policy.arn
}

output "role_eks_node" {
  value = tomap({
    name = aws_iam_role.eks_node_group.name,
    arn  = aws_iam_role.eks_node_group.arn, id = aws_iam_role.eks_node_group.id
  })
}

output "region" {
  value = var.region
}
# ------------variables----------------
//variable "eks_keypair_name" {
//  type    = string
//  default = "eks"
//}

variable "eks_cluster" {
  type = object({
    node_group_size = string
    desired_size    = number
    max_size        = number
    min_size        = number
  })

  default = {
    node_group_size = "t3a.xlarge"
    desired_size    = 1
    max_size        = 2
    min_size        = 1
  }
}

variable "eks_cluster_version" {
  default = "1.21"
}
# ------------resources----------------

//resource "tls_private_key" "eks" {
//  algorithm = "RSA"
//}
//
//resource "aws_key_pair" "eks" {
//  key_name   = var.eks_keypair_name
//  public_key = tls_private_key.eks.public_key_openssh
//  tags       = merge(local.combined_tags, tomap({ "Type" = "eks-key-pair" }))
//}

resource "aws_security_group" "eks" {
  vpc_id                 = aws_vpc.vpc.id
  name                   = "ashwiniag-${var.env}-eks"
  revoke_rules_on_delete = true

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = -1
    to_port     = 0
  }

  tags = merge(local.combined_tags, tomap({
    "Type" = "eks-sg", "kubernetes.io/cluster/ashwiniag-${var.env}" = "owned"
  }))
}

resource "aws_security_group_rule" "eks-self-rule" {
  from_port         = 0
  protocol          = -1
  to_port           = 0
  security_group_id = aws_security_group.eks.id
  self              = true
  type              = "ingress"
}

resource "aws_iam_role" "eks_node_group" {
  name               = "ashwiniag-${var.env}-eks-node-group-role"
  tags               = local.combined_tags
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
  POLICY
}

resource "aws_iam_role" "eks_cluster" {
  name               = "ashwiniag-${var.env}-eks-cluster-role"
  tags               = local.combined_tags
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "eks.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		}
	]
}
  POLICY
}

resource "aws_iam_policy" "eks_node_policy" {
  name   = "ashwiniag-${var.env}-eks-node-policy"
  policy = file("eks_node_and_ssm_policy.json")
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "ashwiniag-${var.env}"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = aws_subnet.private.*.id
    security_group_ids      = [aws_security_group.eks.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSServicePolicy,
  ]

  tags    = merge(local.combined_tags, tomap({ "Type" = "eks-cluster" }))
  version = var.eks_cluster_version
}