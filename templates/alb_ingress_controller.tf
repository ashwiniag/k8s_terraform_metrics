//output  "eks-cluster-tls-certificate" {
//  value = local.eks_certificate_url
//}
//
//data "tls_certificate" "eks_cluster_tls_certificate" {
//  url = local.eks_certificate_url
//}
//
//resource "aws_iam_openid_connect_provider" "eks_cluster_oidc" {
//  client_id_list  = ["sts.amazonaws.com"]
//  thumbprint_list = [data.tls_certificate.eks_cluster_tls_certificate.certificates[0].sha1_fingerprint]
//  url             = local.eks_certificate_url
//}
//
//resource "aws_iam_role" "alb_ingress_controller_role" {
//  name = "${var.cluster}_${var.env}_alb_ingress_controller"
//
//  assume_role_policy = <<POLICY
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Sid": "",
//      "Effect": "Allow",
//      "Principal": {
//        "Federated": "${aws_iam_openid_connect_provider.eks_cluster_oidc.arn}"
//      },
//      "Action": "sts:AssumeRoleWithWebIdentity",
//      "Condition": {
//        "StringEquals": {
//          "${replace(aws_iam_openid_connect_provider.eks_cluster_oidc.url, "https://", "")}:sub": "system:serviceaccount:kube-system:alb-ingress-controller",
//          "${replace(aws_iam_openid_connect_provider.eks_cluster_oidc.url, "https://", "")}:aud": "sts.amazonaws.com"
//        }
//      }
//    }
//  ]
//}
//POLICY
//
//  depends_on = [aws_iam_openid_connect_provider.eks_cluster_oidc]
//
//  tags = {
//    "ServiceAccountName" = "alb-ingress-controller"
//    "ServiceAccountNameSpace" = "kube-system"
//  }
//}
//
//resource "aws_iam_policy" "eks_node-AWSLoadBalancerControllerIAMPolicy" {
//  name   = "AWSLoadBalancerControllerIAMPolicy"
//  policy = file("AWSLoadBalancerControllerIAMPolicy.json")
//}
//
//resource "aws_iam_role_policy_attachment" "alb-ingress-controller-ALBIngressControllerIAMPolicy" {
//  policy_arn = aws_iam_policy.eks_node-AWSLoadBalancerControllerIAMPolicy.arn
//  role       = aws_iam_role.alb_ingress_controller_role.name
//  depends_on = [aws_iam_role.alb_ingress_controller_role]
//}
//
//resource "aws_iam_role_policy_attachment" "alb-ingress-controller-EKS-CNI" {
//  role       = aws_iam_role.alb_ingress_controller_role.name
//  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
//  depends_on = [aws_iam_role.alb_ingress_controller_role]
//}
//
//resource "kubernetes_service_account" "alb_ingress_controller" {
//  metadata {
//    name      = "alb-ingress-controller"
//    namespace = "kube-system"
//
//    labels = {
//      "app.kubernetes.io/name" = "alb-ingress-controller"
//    }
//
//    annotations = {
//      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_ingress_controller_role.arn
//    }
//  }
//}
//
//resource "kubernetes_cluster_role" "alb_ingress_controller" {
//  metadata {
//    name = "alb-ingress-controller"
//
//    labels = {
//      "app.kubernetes.io/name" = "alb-ingress-controller"
//    }
//  }
//
//  rule {
//    verbs      = ["create", "get", "list", "update", "watch", "patch"]
//    api_groups = ["", "extensions"]
//    resources  = ["configmaps", "endpoints", "events", "ingresses", "ingresses/status", "services", "pods/status"]
//  }
//
//  rule {
//    verbs      = ["get", "list", "watch"]
//    api_groups = ["", "extensions"]
//    resources  = ["nodes", "pods", "secrets", "services", "namespaces"]
//  }
//}
//
//resource "kubernetes_cluster_role_binding" "alb_ingress_controller" {
//  metadata {
//    name = "alb-ingress-controller"
//
//    labels = {
//      "app.kubernetes.io/name" = "alb-ingress-controller"
//    }
//  }
//
//  subject {
//    kind      = "ServiceAccount"
//    name      = "alb-ingress-controller"
//    namespace = "kube-system"
//  }
//
//  role_ref {
//    api_group = "rbac.authorization.k8s.io"
//    kind      = "ClusterRole"
//    name      = "alb-ingress-controller"
//  }
//}
//
//resource "kubernetes_deployment" "alb-ingress" {
//  metadata {
//    name = "alb-ingress-controller"
//    namespace = "kube-system"
//    labels = {
//      "app.kubernetes.io/name" = "alb-ingress-controller"
//    }
//  }
//
//  spec {
//    selector {
//      match_labels = {
//        "app.kubernetes.io/name" = "alb-ingress-controller"
//      }
//    }
//
//    template {
//      metadata {
//        labels = {
//          "app.kubernetes.io/name" = "alb-ingress-controller"
//        }
//      }
//      spec {
//        container {
//          # This is where you change the version when Amazon comes out with a new version of the ingress controller
//          image = "docker.io/amazon/aws-alb-ingress-controller:v2.4.4"
//          //602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller
//          name  = "alb-ingress-controller"
//                    args = ["--ingress-class=alb",
//                      "--cluster-name=${var.cluster}-${var.env}",
//                      "--aws-vpc-id=${local.vpc_id}",
//                      "--aws-region=${var.region}"]
//        }
//        service_account_name = "alb-ingress-controller"
//      }
//    }
//  }
//}
//

## Alternate approach for the above.
resource "null_resource" "service-account" {
  depends_on = [aws_iam_policy.eks_node-AWSLoadBalancerControllerIAMPolicy]
  triggers   = {
    always_run = 1
  }
  provisioner "local-exec" {
    on_failure  = fail
    interpreter = ["/bin/bash", "-c"]
    when        = create
    command     = <<EOT
        set -ex
        export KUBECONFIG=/tmp/kubeconfig/ashwiniag-dragon/services
        reg=${var.region}
        acc=263085199674
        cn=${var.cluster}-${var.env}
        eksctl utils associate-iam-oidc-provider \
        --region $reg \
        --cluster $cn \
        --approve
        eksctl create iamserviceaccount \
        --cluster=$cn \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --attach-policy-arn=${aws_iam_policy.eks_node-AWSLoadBalancerControllerIAMPolicy.arn} \
        --override-existing-serviceaccounts \
        --region $reg \
        --approve
        helm repo add eks https://aws.github.io/eks-charts
        helm repo update
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
          -n kube-system \
          --set clusterName=$cn \
          --set serviceAccount.create=false \
          --set serviceAccount.name=aws-load-balancer-controller \
          --set image.repository=602401143452.dkr.ecr.$reg.amazonaws.com/amazon/aws-load-balancer-controller
     EOT
  }
}

resource "aws_iam_policy" "eks_node-AWSLoadBalancerControllerIAMPolicy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("AWSLoadBalancerControllerIAMPolicy.json")
}