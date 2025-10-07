# Istio Ingress Gateway values
# https://github.com/istio/istio/blob/master/manifests/charts/gateway/values.yaml

# Explicitly set service type to LoadBalancer
# This requires MetalLB or cloud provider LoadBalancer support
service:
  type: LoadBalancer
  # Annotations can be added here for cloud-specific settings
  # annotations: {}
