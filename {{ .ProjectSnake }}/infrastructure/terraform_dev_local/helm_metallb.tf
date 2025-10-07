# MetalLB is a load-balancer implementation for bare metal Kubernetes clusters
# and clusters that don't have native LoadBalancer support (like kind, minikube, etc.)
# It provides network load-balancer implementation that integrates with standard network equipment
# https://metallb.universe.tf/

# MetalLB Helm Chart
# https://metallb.universe.tf/installation/
# https://github.com/metallb/metallb/tree/main/charts/metallb
resource "helm_release" "metallb" {
  count            = var.metallb_enabled ? 1 : 0
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = var.metallb_version
  description      = "Terraform driven Helm release of MetalLB for LoadBalancer support in kind/bare-metal clusters"
  namespace        = "metallb-system"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  # MetalLB Helm chart values
  # https://github.com/metallb/metallb/blob/main/charts/metallb/values.yaml
  values = [
    templatefile(
      "${path.module}/helm_values/metallb_values.yaml.tpl",
      {
        namespace = "metallb-system"
      }
    )
  ]
}

# Wait for MetalLB CRDs to be fully registered with Kubernetes API server
# This prevents "no matches for kind" errors when creating IPAddressPool/L2Advertisement  
resource "time_sleep" "wait_for_metallb_crds" {
  count = var.metallb_enabled ? 1 : 0

  depends_on = [helm_release.metallb]

  create_duration = "30s"
}

# IPAddressPool defines the IP address range that MetalLB can allocate to services
# This must be compatible with your Docker network or cluster network range
# For kind clusters: typically 172.18.255.x range within the Docker network
# For minikube: typically 192.168.49.x range
# For bare metal: any available IP range in your network
# Using kubectl_manifest instead of kubernetes_manifest for better CRD handling
resource "kubectl_manifest" "metallb_ipaddresspool" {
  count = var.metallb_enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: default-pool
      namespace: metallb-system
    spec:
      addresses:
      - ${var.metallb_ip_range}
  YAML

  # Wait for MetalLB CRDs to be fully registered
  depends_on = [
    helm_release.metallb,
    time_sleep.wait_for_metallb_crds
  ]
}

# L2Advertisement enables Layer 2 mode for MetalLB
# In Layer 2 mode, one node assumes the responsibility of advertising a service to the local network
# This is the simplest mode and works well for development/testing environments
# Using kubectl_manifest instead of kubernetes_manifest for better CRD handling
resource "kubectl_manifest" "metallb_l2advertisement" {
  count = var.metallb_enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: default-l2
      namespace: metallb-system
    spec:
      ipAddressPools:
      - default-pool
  YAML

  depends_on = [
    helm_release.metallb,
    time_sleep.wait_for_metallb_crds,
    kubectl_manifest.metallb_ipaddresspool
  ]
}

# Output the MetalLB configuration for reference
output "metallb_info" {
  description = "MetalLB configuration information"
  value = var.metallb_enabled ? {
    enabled    = true
    version    = var.metallb_version
    ip_range   = var.metallb_ip_range
    namespace  = "metallb-system"
    chart_name = "metallb"
  } : null
}
