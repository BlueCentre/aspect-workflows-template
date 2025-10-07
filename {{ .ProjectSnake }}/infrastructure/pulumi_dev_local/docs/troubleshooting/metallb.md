# MetalLB Troubleshooting Guide

**Audience:** Administrators, DevOps Engineers, Developers  
**Last Updated:** October 8, 2025

## Overview

This guide helps diagnose and resolve common issues with MetalLB LoadBalancer implementation in local and bare-metal Kubernetes clusters.

## Common Issues

### Issue 1: Service Stuck with EXTERNAL-IP `<pending>`

**Symptoms:**

```bash
$ kubectl get svc -n istio-system istio-ingressgateway
NAME                   TYPE           EXTERNAL-IP   PORT(S)
istio-ingressgateway   LoadBalancer   <pending>     80:32492/TCP,443:30688/TCP
```

#### Possible Causes and Solutions

#### A. MetalLB Not Deployed

**Diagnosis:**

```bash
kubectl get pods -n metallb-system
# If this returns "No resources found", MetalLB is not installed
```

**Solution:**

```bash
# Enable MetalLB in Pulumi.local.yaml
monorepo:metallb_enabled: "true"
monorepo:metallb_version: "0.14.9"
monorepo:metallb_ip_range: "172.18.255.200-172.18.255.250"

# Deploy
cd infrastructure/pulumi_dev_local
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

#### B. MetalLB Pods Not Running

**Diagnosis:**

```bash
kubectl get pods -n metallb-system
# Look for pods in CrashLoopBackOff, Error, or Pending state
```

**Solution:**

```bash
# Check controller logs
kubectl logs -n metallb-system -l app=metallb,component=controller

# Check speaker logs
kubectl logs -n metallb-system -l app=metallb,component=speaker

# Common issues:
# - Invalid IP range format
# - Network connectivity issues
# - RBAC permissions missing
```

#### C. No IP Address Pool Configured

**Diagnosis:**

```bash
kubectl get ipaddresspool -n metallb-system
# If this returns "No resources found", IP pool is missing
```

**Solution:**

```bash
# Check IPAddressPool configuration
kubectl get ipaddresspool -n metallb-system -o yaml

# If missing or incorrect, update Pulumi.local.yaml and redeploy
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

#### D. Service Type is Not LoadBalancer

**Diagnosis:**

```bash
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.type}'
# Should return "LoadBalancer", not "NodePort" or "ClusterIP"
```

**Solution:**
Update the service configuration to use `type: LoadBalancer`:

For Pulumi-managed services (like Istio):

```go
// In pkg/applications/istio.go
Values: map[string]interface{}{
    "service": map[string]interface{}{
        "type": "LoadBalancer",
    },
},
```

For manual services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer  # Must be LoadBalancer
  ports:
    - port: 80
```

#### E. IP Pool Exhausted

**Diagnosis:**

```bash
# Count allocated IPs
kubectl get svc -A --field-selector spec.type=LoadBalancer | grep -v pending | wc -l

# Check pool size
kubectl get ipaddresspool -n metallb-system -o jsonpath='{.items[0].spec.addresses}'
```

**Solution:**
Expand the IP pool range:

```yaml
# In Pulumi.local.yaml
monorepo:metallb_ip_range: "172.18.255.200-172.18.255.254"  # Expanded
```

Apply changes:

```bash
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

#### F. L2Advertisement Missing

**Diagnosis:**

```bash
kubectl get l2advertisement -n metallb-system
# If empty, Layer 2 mode is not configured
```

**Solution:**

```bash
# Should be created automatically by Pulumi
# If missing, check deployment logs and redeploy
kubectl describe ipaddresspool -n metallb-system
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

---

### Issue 2: External IP Not Reachable

**Symptoms:**

```bash
$ curl http://172.18.255.200
curl: (28) Failed to connect
```

#### Possible Causes and Solutions

#### A. Normal Behavior for kind Clusters

**Context:**
In kind clusters, LoadBalancer IPs are only reachable from within the Docker network, not from the host machine or dev containers.

**Verification:**

```bash
# Test from within a pod
kubectl run test-curl --image=curlimages/curl --rm -i --restart=Never -- \
  curl -I http://172.18.255.200

# If this works, the LoadBalancer is functioning correctly
```

**Solution:**
Use port forwarding to access from host:

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
curl http://localhost:8080
```

Or use NodePort:

```bash
# LoadBalancer services also expose NodePorts
kubectl get svc -n istio-system istio-ingressgateway
# Access via NodePort (e.g., 32492)
curl http://localhost:32492
```

#### B. Network Configuration Issues (Bare-Metal)

**Diagnosis:**

```bash
# Check routing
ip route get <external-ip>

# Check ARP table
arp -a | grep <external-ip>

# Verify network interface
kubectl get nodes -o wide
```

**Solution:**

1. Ensure IP range is routable in your network
2. Check firewall rules
3. Verify switch/router configuration
4. Coordinate with network team

#### C. Service Has No Endpoints

**Diagnosis:**

```bash
kubectl get endpoints <service-name> -n <namespace>
# If "ENDPOINTS" is empty, no pods are backing the service
```

**Solution:**

```bash
# Check pod status
kubectl get pods -n <namespace> -l <service-selector>

# Check service selector matches pod labels
kubectl get svc <service-name> -n <namespace> -o yaml | grep selector -A 5
kubectl get pods -n <namespace> --show-labels
```

---

### Issue 3: MetalLB Controller/Speaker Pods CrashLooping

**Symptoms:**

```bash
$ kubectl get pods -n metallb-system
NAME                                  READY   STATUS             RESTARTS   AGE
metallb-controller-xxx                0/1     CrashLoopBackOff   5          5m
metallb-speaker-xxx                   0/1     Error              3          5m
```

#### Diagnosis

```bash
# Check controller logs
kubectl logs -n metallb-system -l app=metallb,component=controller --tail=50

# Check speaker logs
kubectl logs -n metallb-system -l app=metallb,component=speaker --tail=50

# Check events
kubectl get events -n metallb-system --sort-by='.lastTimestamp'
```

#### Common Causes

1. **Invalid IP range format:**

   ```bash
   Error: invalid CIDR address: 172.18.255.200
   ```

   Solution: Use range format: `172.18.255.200-172.18.255.250`

2. **RBAC permissions missing:**

   ```bash
   Error: cannot list resource "nodes" in API group
   ```

   Solution: Redeploy with proper RBAC (should be automatic with Pulumi)

3. **Conflicting IP assignments:**

   ```bash
   Error: IP address already in use
   ```

   Solution: Choose different IP range

4. **Network plugin conflicts:**
   Some CNI plugins (Calico, Cilium) may conflict with MetalLB
   Solution: Check CNI compatibility and adjust configuration

---

### Issue 4: Multiple Services Getting Same IP

**Symptoms:**
Two different LoadBalancer services show the same EXTERNAL-IP.

**Diagnosis:**

```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
```

**Cause:**
This is actually normal if services are configured to share IPs (not common in default setup).

**Solution:**
If unintended, ensure services don't have `metallb.universe.tf/allow-shared-ip` annotation or manually specified `loadBalancerIP`.

---

### Issue 5: IP Assigned but ARP Not Working (Layer 2)

**Symptoms:**

- Service has external IP
- Cannot ping or reach the IP
- ARP requests timeout

**Diagnosis:**

```bash
# Check speaker pods (responsible for ARP)
kubectl get pods -n metallb-system -l component=speaker

# Check speaker logs
kubectl logs -n metallb-system -l component=speaker | grep -i arp

# Check network interfaces
kubectl exec -n metallb-system <speaker-pod> -- ip addr
```

**Solutions:**

1. **Verify network mode:**

   - kind requires `extraPortMappings` in cluster config
   - Some networks block ARP announcements

2. **Check speaker binding:**

   ```bash
   kubectl describe pod -n metallb-system <speaker-pod> | grep Interfaces
   ```

3. **Network policy conflicts:**

   ```bash
   kubectl get networkpolicies -A
   ```

---

## Diagnostic Commands

### Complete Health Check

```bash
#!/bin/bash
echo "=== MetalLB System Status ==="
echo ""
echo "--- Pods ---"
kubectl get pods -n metallb-system
echo ""
echo "--- IP Address Pool ---"
kubectl get ipaddresspool -n metallb-system -o yaml
echo ""
echo "--- L2 Advertisement ---"
kubectl get l2advertisement -n metallb-system -o yaml
echo ""
echo "--- LoadBalancer Services ---"
kubectl get svc -A --field-selector spec.type=LoadBalancer
echo ""
echo "--- Recent Events ---"
kubectl get events -n metallb-system --sort-by='.lastTimestamp' | tail -10
```

### Check IP Allocation

```bash
# List all LoadBalancer services with IPs
kubectl get svc -A --field-selector spec.type=LoadBalancer \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip
```

### Detailed Service Inspection

```bash
SERVICE_NAME="istio-ingressgateway"
NAMESPACE="istio-system"

echo "=== Service Details ==="
kubectl get svc $SERVICE_NAME -n $NAMESPACE -o yaml

echo ""
echo "=== Endpoints ==="
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE

echo ""
echo "=== Pods ==="
kubectl get pods -n $NAMESPACE -l app=istio-ingressgateway
```

---

## Recovery Procedures

### Restart MetalLB Components

```bash
# Restart controller
kubectl rollout restart deployment metallb-controller -n metallb-system

# Restart speakers (DaemonSet)
kubectl rollout restart daemonset metallb-speaker -n metallb-system

# Wait for rollout
kubectl rollout status deployment metallb-controller -n metallb-system
kubectl rollout status daemonset metallb-speaker -n metallb-system
```

### Force IP Reassignment

```bash
# Delete and recreate the service
kubectl delete svc <service-name> -n <namespace>
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y

# Or manually recreate with kubectl
kubectl apply -f service.yaml
```

### Reset MetalLB Configuration

```bash
# Disable MetalLB
# Edit Pulumi.local.yaml: metallb_enabled: "false"
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y

# Re-enable with corrected configuration
# Edit Pulumi.local.yaml: metallb_enabled: "true"
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

---

## Prevention Best Practices

1. **Validate IP Range Before Deployment**

   ```bash
   # For kind
   docker network inspect kind | grep Subnet
   
   # For bare-metal
   consult network team
   ```

2. **Monitor IP Pool Usage**

   ```bash
   # Set up alerts when 80% of IPs are allocated
   TOTAL_IPS=50
   USED_IPS=$(kubectl get svc -A --field-selector spec.type=LoadBalancer | grep -v pending | wc -l)
   PERCENTAGE=$((USED_IPS * 100 / TOTAL_IPS))
   echo "IP Pool Usage: $PERCENTAGE%"
   ```

3. **Document IP Allocations**
   Keep a record of which services use which IPs

4. **Regular Health Checks**

   ```bash
   # Add to monitoring/alerting
   kubectl get pods -n metallb-system -o json | \
     jq '.items[] | select(.status.phase != "Running") | .metadata.name'
   ```

5. **Test After Changes**

   ```bash
   # After any network or configuration change
   kubectl get svc -A --field-selector spec.type=LoadBalancer
   # Verify all services have external IPs
   ```

---

## Getting Help

If issues persist after following this guide:

1. **Check Logs:**

   ```bash
   # Controller logs
   kubectl logs -n metallb-system -l app=metallb,component=controller --tail=100
   
   # Speaker logs (all)
   kubectl logs -n metallb-system -l app=metallb,component=speaker --tail=100
   ```

2. **Gather Diagnostic Information:**

   ```bash
   # Save full diagnostics
   kubectl get all -n metallb-system -o yaml > metallb-diagnostics.yaml
   kubectl get events -n metallb-system > metallb-events.txt
   ```

3. **Consult Resources:**

   - [MetalLB Official Documentation](https://metallb.universe.tf/)
   - [MetalLB Concepts](https://metallb.universe.tf/concepts/)
   - [Setup Guide](../setup/metallb.md)
   - [General Pulumi Troubleshooting](../pulumi_troubleshooting.md)

4. **Contact Support:**

   - Platform team
   - DevOps lead
   - MetalLB community (GitHub issues)

---

## Known Limitations

### kind Clusters

- LoadBalancer IPs not directly reachable from host
- Requires Docker network access
- Layer 2 mode only (no BGP support)

### minikube

- Similar limitations to kind
- Some versions have built-in `minikube tunnel` (alternative to MetalLB)

### Bare-Metal

- Requires network team coordination
- May need switch/router configuration for BGP mode
- Firewall rules may block ARP announcements

---

## Appendix: Real-World Example

### Case Study: istio-ingressgateway Not Getting External IP

**Initial State:**

```bash
$ kubectl get svc -n istio-system istio-ingressgateway
NAME                   TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)
istio-ingressgateway   NodePort   10.96.75.227   <none>        80:32492/TCP
```

**Problem:** Service type was `NodePort` instead of `LoadBalancer`

**Investigation:**

```bash
# Checked MetalLB was running
$ kubectl get pods -n metallb-system
NAME                                  READY   STATUS    RESTARTS   AGE
metallb-controller-xxx                1/1     Running   0          10m
metallb-speaker-xxx                   1/1     Running   0          10m

# Verified IP pool existed
$ kubectl get ipaddresspool -n metallb-system
NAME           AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
default-pool   true          false             ["172.18.255.200-172.18.255.250"]

# Found service type was wrong
$ kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.type}'
NodePort  # Should be LoadBalancer!
```

**Solution:**
Updated `pkg/applications/istio.go`:

```go
Values: map[string]interface{}{
    "service": map[string]interface{}{
        "type": "LoadBalancer",  // Explicitly set
    },
},
```

Applied changes:

```bash
PULUMI_CONFIG_PASSPHRASE=pulumi-dev-passphrase pulumi up -y
```

**Result:**

```bash
$ kubectl get svc -n istio-system istio-ingressgateway
NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
istio-ingressgateway   LoadBalancer   10.96.75.227   172.18.255.200   80:32492/TCP,443:30688/TCP
```

✅ **Success!** External IP assigned by MetalLB.

**Lesson:** Always verify service type is `LoadBalancer`, not `NodePort` or `ClusterIP`.
