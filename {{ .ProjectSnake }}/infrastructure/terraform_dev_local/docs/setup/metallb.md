# MetalLB Setup Guide

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters and environments that don't have native LoadBalancer support (like kind, minikube, or on-premise clusters).

**Audience:** Platform Engineers, DevOps Engineers, SREs  

**Last Updated:** 2025-10-09 (v2 - Single-stage deployment)

## Why MetalLB?

When you deploy Kubernetes on bare metal or in local development environments (kind, minikube), services of type `LoadBalancer` will remain in a "pending" state indefinitely because there's no cloud provider load balancer to provision. MetalLB solves this by:

- Providing network load-balancer implementation using standard routing protocols
- Allowing services of type LoadBalancer to receive external IPs
- Supporting Layer 2 (ARP/NDP) and BGP modes

## Prerequisites

1. **Terraform installed** (version 1.0+)
2. **Kubernetes cluster running** (kind, minikube, or bare metal)
3. **Network IP range available** for LoadBalancer allocation
4. **kubectl configured** to access your cluster

## Quick Start

### 1. Determine Your Network Range

**For kind clusters:**

```bash
# Inspect the Docker network used by kind
docker network inspect kind | grep Subnet

# Typical output: "Subnet": "172.18.0.0/16"
# Choose a range within this subnet, e.g., 172.18.255.200-172.18.255.250
```

**For minikube clusters:**

```bash
# Get minikube IP
minikube ip

# Typical: 192.168.49.2
# Use range: 192.168.49.200-192.168.49.250
```

**For bare metal:**

- Coordinate with your network team
- Choose an unused IP range within your network
- Ensure IPs don't conflict with DHCP

### 2. Configure Terraform Variables

Edit `terraform.auto.tfvars`:

```hcl
# Enable MetalLB
metallb_enabled  = true
metallb_version  = "0.14.9"
metallb_ip_range = "172.18.255.200-172.18.255.250"  # Adjust for your environment
```

### 3. Deploy MetalLB

```bash
cd infrastructure/terraform_dev_local

# Initialize Terraform (if not already done)
terraform init

# Review the planned changes
terraform plan

# Apply the configuration (single command!)
terraform apply -auto-approve
```

**Note:** The deployment uses `time_sleep` resource and `kubectl_manifest` provider to handle CRD timing automatically. You'll see a 30-second wait during deployment while MetalLB CRDs are registered with the Kubernetes API server. This is normal and ensures reliable single-stage deployment.

### 4. Verify Deployment

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# controller-xxxxx             1/1     Running   0          1m
# speaker-xxxxx                1/1     Running   0          1m

# Check IPAddressPool
kubectl get ipaddresspool -n metallb-system

# Check L2Advertisement
kubectl get l2advertisement -n metallb-system

# Test with Istio ingress (if enabled)
kubectl get svc -n istio-system istio-ingressgateway

# Should show EXTERNAL-IP with one of your configured IPs
```

## Configuration Details

### Terraform Resources Created

The `helm_metallb.tf` file creates:

1. **Helm Release** - Deploys MetalLB controller and speaker
2. **IPAddressPool** - Defines the IP range for LoadBalancer allocation
3. **L2Advertisement** - Enables Layer 2 mode for IP advertisement

### Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `metallb_enabled` | bool | `false` | Enable MetalLB deployment |
| `metallb_version` | string | `"0.14.9"` | Helm chart version |
| `metallb_ip_range` | string | `"172.18.255.200-172.18.255.250"` | IP range for allocation |

### Deployment Order

MetalLB must be deployed **before** services that request LoadBalancer IPs. The configuration includes:

```hcl
depends_on = [helm_release.istio_base, helm_release.istiod, helm_release.metallb]
```

This ensures MetalLB is ready before Istio ingress gateway attempts to get an external IP.

## Environment-Specific Setup

### kind Clusters

```hcl
metallb_ip_range = "172.18.255.200-172.18.255.250"
```

The default Docker network for kind is `172.18.0.0/16`. Use the `.255.x` range to avoid conflicts.

### minikube Clusters

```hcl
metallb_ip_range = "192.168.49.200-192.168.49.250"
```

minikube typically uses `192.168.49.0/24`. Adjust based on `minikube ip` output.

### Bare Metal Clusters

```hcl
metallb_ip_range = "10.0.100.200-10.0.100.250"  # Example
```

Work with your network team to:

- Reserve a range of IPs
- Ensure no DHCP conflicts
- Verify network accessibility

## Advanced Configuration

### Using Multiple IP Pools

Edit `helm_metallb.tf` to add additional IPAddressPool resources:

```hcl
resource "kubernetes_manifest" "metallb_ipaddresspool_production" {
  count = var.metallb_enabled ? 1 : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "production-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [
        "10.0.200.1-10.0.200.50"
      ]
    }
  }

  depends_on = [helm_release.metallb]
}
```

### BGP Mode (Advanced)

For production environments, consider BGP mode instead of Layer 2:

1. Create BGP peer configuration
2. Configure router to accept BGP announcements
3. Update L2Advertisement to BGPAdvertisement

See [MetalLB BGP documentation](https://metallb.universe.tf/configuration/#bgp-configuration) for details.

## Integration with Other Services

### Istio Ingress Gateway

The Istio ingress gateway is configured to use LoadBalancer type:

```yaml
# helm_values/istio_ingressgateway_values.yaml.tpl
service:
  type: LoadBalancer
```

Once MetalLB is deployed, Istio will automatically receive an external IP.

### Other LoadBalancer Services

Any Kubernetes service with `type: LoadBalancer` will automatically receive an IP from MetalLB's pool:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: my-app
```

## Validation Steps

### 1. Check MetalLB Deployment

```bash
# Verify all pods are running
kubectl get pods -n metallb-system

# Check controller logs
kubectl logs -n metallb-system -l app.kubernetes.io/component=controller

# Check speaker logs (on each node)
kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker
```

### 2. Verify IP Pool Configuration

```bash
# Get IPAddressPool details
kubectl get ipaddresspool -n metallb-system -o yaml

# Get L2Advertisement details
kubectl get l2advertisement -n metallb-system -o yaml
```

### 3. Test LoadBalancer Service

```bash
# Check Istio ingress gateway (if enabled)
kubectl get svc -n istio-system istio-ingressgateway

# Output should show:
# TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
# LoadBalancer   10.96.xxx.xxx   172.18.255.200    80:xxxxx/TCP,443:xxxxx/TCP

# Test connectivity (if Istio is deployed)
curl -v http://$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## Troubleshooting

For common issues and solutions, see the [MetalLB Troubleshooting Guide](../troubleshooting/metallb.md).

### Quick Checks

```bash
# 1. Verify MetalLB is enabled in Terraform
terraform state show 'helm_release.metallb[0]'

# 2. Check service status
kubectl get svc --all-namespaces | grep LoadBalancer

# 3. Check MetalLB speaker logs
kubectl logs -n metallb-system -l component=speaker --tail=50

# 4. Verify IP range doesn't conflict
docker network inspect kind | grep -A 5 IPAM
```

## References

- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [MetalLB GitHub](https://github.com/metallb/metallb)
- [kind LoadBalancer Guide](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

## Next Steps

- **Configure DNS:** Set up External DNS to automatically create DNS records for LoadBalancer IPs
- **Add TLS:** Configure cert-manager for automatic TLS certificate provisioning
- **Monitor:** Set up monitoring for MetalLB speaker and controller components
- **Scale:** For production, consider BGP mode for better redundancy

---

*For questions or issues, see [terraform_troubleshooting.md](terraform_troubleshooting.md) or open an issue in the repository.*
