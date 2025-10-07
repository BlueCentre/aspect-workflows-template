# MetalLB Setup Guide

**Audience:** Administrators, DevOps Engineers  
**Last Updated:** October 8, 2025

## Overview

MetalLB is a network load balancer implementation for bare-metal and local Kubernetes clusters (kind, minikube). This guide explains how to configure MetalLB in your Pulumi stack to enable LoadBalancer services in environments that don't have native cloud provider support.

## Why MetalLB?

### The Problem

Local Kubernetes clusters (kind, minikube) and bare-metal clusters don't have built-in LoadBalancer support. When you create a LoadBalancer service, it remains in `<pending>` state indefinitely because there's no controller to assign external IPs.

### The Solution

MetalLB provides LoadBalancer capabilities by:

- Assigning external IPs from a configured pool
- Announcing those IPs using Layer 2 (ARP) or BGP protocols
- Making LoadBalancer services work just like in cloud environments

### Benefits

- ✅ **Production Parity**: Services behave identically to cloud environments (GKE, EKS, AKS)
- ✅ **Standard Ports**: Services use ports 80/443 instead of NodePorts (30000+)
- ✅ **Ingress Compatible**: Works seamlessly with Istio, NGINX Ingress, and other ingress controllers
- ✅ **DNS Ready**: External IPs can be registered in DNS for proper service discovery
- ✅ **Testing**: Validate LoadBalancer configurations before cloud deployment

## When to Use MetalLB

| Environment | Use MetalLB? | Reason |
|-------------|--------------|--------|
| **kind cluster** | ✅ **Yes** | No native LoadBalancer support |
| **minikube** | ✅ **Yes** | No native LoadBalancer support |
| **Bare-metal/On-premises** | ✅ **Yes** | No cloud provider LoadBalancer |
| **Private data centers** | ✅ **Yes** | Custom networking requirements |
| **Edge computing** | ✅ **Yes** | Local load balancing needed |
| **GKE/EKS/AKS** | ❌ **No** | Use native cloud LoadBalancer |
| **Docker Desktop K8s** | ⚠️ **Optional** | Has limited LoadBalancer support |

## Configuration

### 1. Enable MetalLB in Pulumi Configuration

Edit `Pulumi.local.yaml`:

```yaml
config:
  # Enable MetalLB for LoadBalancer support
  monorepo:metallb_enabled: "true"
  monorepo:metallb_version: "0.14.9"
  monorepo:metallb_ip_range: "172.18.255.200-172.18.255.250"
```

### 2. Determine the Correct IP Range

The IP range must match your cluster's network subnet and not conflict with existing IP allocations.

#### For kind Clusters

```bash
# Check the kind network subnet
docker network inspect kind | grep Subnet

# Example output: "Subnet": "172.18.0.0/16"
# Use high-range IPs to avoid conflicts: 172.18.255.200-172.18.255.250
```

**Recommended configuration:**

```yaml
monorepo:metallb_ip_range: "172.18.255.200-172.18.255.250"
```

#### For minikube Clusters

```bash
# Get minikube IP to determine subnet
minikube ip

# Example output: 192.168.49.2
# Use same subnet: 192.168.49.200-192.168.49.250
```

**Recommended configuration:**

```yaml
monorepo:metallb_ip_range: "192.168.49.200-192.168.49.250"
```

#### For Bare-Metal Clusters

```bash
# Check your network configuration
ip addr show

# Or check node IPs
kubectl get nodes -o wide
```

**Recommended approach:**

1. Coordinate with your network administrator
2. Use IPs outside of DHCP range
3. Ensure IPs are routable within your network
4. Reserve the IP range in your network documentation

**Example configuration:**

```yaml
monorepo:metallb_ip_range: "10.0.1.200-10.0.1.250"
```

### 3. Deploy the Stack

```bash
cd /workspaces/kitchen-sink/infrastructure/pulumi_dev_local

# Deploy with MetalLB enabled
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

### 4. Verify Deployment

```bash
# Check MetalLB pods are running
kubectl get pods -n metallb-system

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# metallb-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# metallb-speaker-xxxxx                 1/1     Running   0          2m

# Verify IP address pool
kubectl get ipaddresspool -n metallb-system

# Expected output:
# NAME           AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
# default-pool   true          false             ["172.18.255.200-172.18.255.250"]

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system

# Expected output:
# NAME                       IPADDRESSPOOLS     IPADDRESSPOOL SELECTORS
# default-l2-advertisement   ["default-pool"]
```

### 5. Verify LoadBalancer Services

```bash
# List all LoadBalancer services
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Expected output for Istio:
# NAMESPACE      NAME                   TYPE           EXTERNAL-IP      PORT(S)
# istio-system   istio-ingressgateway   LoadBalancer   172.18.255.200   15021:32040/TCP,80:32492/TCP,443:30688/TCP
```

✅ If you see an `EXTERNAL-IP` (not `<pending>`), MetalLB is working correctly!

## IP Pool Management

### Understanding IP Allocation

- MetalLB assigns IPs sequentially from the configured pool
- First service gets: `172.18.255.200`
- Second service gets: `172.18.255.201`
- And so on...

### Checking IP Allocations

```bash
# See all LoadBalancer services and their IPs
kubectl get svc -A --field-selector spec.type=LoadBalancer -o wide
```

### Expanding the IP Pool

If you run out of IPs in the pool:

1. **Update `Pulumi.local.yaml`:**

   ```yaml
   monorepo:metallb_ip_range: "172.18.255.200-172.18.255.254"  # Expanded range
   ```

2. **Apply changes:**

   ```bash
   PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
   ```

3. **Verify new pool:**

   ```bash
   kubectl get ipaddresspool -n metallb-system -o yaml
   ```

## Network Reachability

### kind Clusters

In kind clusters, LoadBalancer IPs have specific reachability characteristics:

| Source | Can Reach LoadBalancer IP? | Method |
|--------|---------------------------|--------|
| **Pods in cluster** | ✅ Yes | Direct access |
| **Docker containers on same network** | ✅ Yes | Direct access |
| **Host machine** | ❌ No | Requires port forwarding |
| **Dev containers** | ❌ No | Requires port forwarding |

**To access from host/dev container:**

```bash
# Option 1: Port forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
curl http://localhost:8080

# Option 2: Use NodePort (still available on LoadBalancer services)
kubectl get svc -n istio-system istio-ingressgateway
# Note the NodePort (e.g., 32492 for port 80)
curl http://localhost:32492
```

### Bare-Metal Clusters

In bare-metal clusters with proper network configuration:

- ✅ LoadBalancer IPs are directly reachable from anywhere on the network
- ✅ Can register IPs in DNS for hostname resolution
- ✅ Can access from workstations, servers, and other infrastructure

## Advanced Configuration

### Using BGP Mode (Bare-Metal)

For production bare-metal clusters, BGP mode is recommended over Layer 2:

```yaml
# Example BGP configuration (requires BGP-capable routers)
# This would require custom MetalLB configuration beyond this Pulumi setup
```

**Note:** The current Pulumi implementation uses Layer 2 mode, which is suitable for most use cases. BGP mode requires additional network infrastructure and configuration.

### IP Address Pool Sharing

By default, all LoadBalancer services share the same IP pool. You can create multiple pools for different purposes (not covered in current implementation).

### Service-Specific IP Assignment

To request a specific IP for a service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  loadBalancerIP: 172.18.255.210  # Specific IP from the pool
  ports:
    - port: 80
```

## Troubleshooting

For troubleshooting issues with MetalLB, see:

- [MetalLB Troubleshooting Guide](../troubleshooting/metallb.md)
- [General Pulumi Troubleshooting](../pulumi_troubleshooting.md)

### Quick Health Check

```bash
# One command to check everything
echo "=== MetalLB Pods ===" && \
kubectl get pods -n metallb-system && \
echo -e "\n=== IP Pool ===" && \
kubectl get ipaddresspool -n metallb-system && \
echo -e "\n=== LoadBalancer Services ===" && \
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

## Best Practices

### DO ✅

- Use high-range IPs (e.g., x.x.255.x) to avoid conflicts
- Document your IP pool allocation
- Reserve sufficient IPs for future growth (50+ IPs recommended)
- Test LoadBalancer services after initial setup
- Monitor IP pool usage as you add services

### DON'T ❌

- Don't use IPs within the DHCP range
- Don't overlap with existing node or pod IPs
- Don't enable MetalLB in cloud environments (GKE/EKS/AKS)
- Don't modify MetalLB resources directly (use Pulumi)
- Don't forget to update documentation when changing IP ranges

## Integration with Other Components

### Istio Ingress Gateway

- Automatically gets external IP from MetalLB
- Configured as LoadBalancer type in `pkg/applications/istio.go`
- Uses standard ports 80/443

### Other LoadBalancer Services

Any service with `type: LoadBalancer` will automatically:

1. Request an IP from MetalLB
2. Get assigned the next available IP from the pool
3. Be announced via Layer 2 (ARP)

## Uninstalling MetalLB

To disable MetalLB:

1. **Update `Pulumi.local.yaml`:**

   ```yaml
   monorepo:metallb_enabled: "false"
   ```

2. **Note:** Existing LoadBalancer services will lose their external IPs and go to `<pending>` state

3. **Apply changes:**

   ```bash
   PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
   ```

## Additional Resources

- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [MetalLB Configuration Reference](https://metallb.universe.tf/configuration/)
- [kind LoadBalancer Guide](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
- [Pulumi Kubernetes Provider](https://www.pulumi.com/registry/packages/kubernetes/)

## Support

For issues or questions:

1. Check the [troubleshooting guide](../troubleshooting/metallb.md)
2. Review MetalLB controller logs: `kubectl logs -n metallb-system -l app=metallb,component=controller`
3. Check the [Pulumi troubleshooting guide](../pulumi_troubleshooting.md)
4. Consult your platform team or DevOps lead
