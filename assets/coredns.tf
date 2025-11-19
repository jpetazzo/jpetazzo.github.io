provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}

data "kubernetes_config_map_v1" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}

locals {
  new_corefile = replace(
    data.kubernetes_config_map_v1.coredns.data.Corefile,
    "forward . /etc/resolv.conf",
    "forward . 1.0.0.1 1.1.1.1"
  )
}

resource "kubernetes_config_map_v1_data" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  data = {
    "Corefile" = local.new_corefile
  }
  force = true
}

resource "kubernetes_annotations" "coredns" {
  kind        = "Deployment"
  api_version = "apps/v1"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "Corefile-hash" = sha256(local.new_corefile)
  }
  depends_on = [kubernetes_config_map_v1_data.coredns]
}
