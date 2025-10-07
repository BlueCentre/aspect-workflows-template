# Quick Reference: Terraform Deployment

**Last Updated:** 2025-10-09 (v2 - Single-stage deployment)

## Single-Stage Deployment ✅

The infrastructure now deploys in a **single command** with automatic CRD handling!

```bash
cd infrastructure/terraform_dev_local
terraform apply -auto-approve
```

## What Happens During Deployment

1. **MetalLB Helm chart deploys** (~13 seconds) - Installs CRDs
2. **30-second wait** - Ensures CRDs are registered with Kubernetes API
3. **IPAddressPool and L2Advertisement created** - Uses kubectl_manifest provider
4. **Istio components deploy** - Ingress gateway gets LoadBalancer IP

**Total deployment time:** ~1-2 minutes

## How It Works

The code uses:

- `time_sleep` resource with 30s delay after MetalLB installation
- `kubectl_manifest` provider (instead of `kubernetes_manifest`) for better CRD handling
- Proper `depends_on` relationships between resources

This eliminates the need for two-stage deployments or manual retries!

## Verification Commands

After deployment, verify everything is working:

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check IPAddressPool
kubectl get ipaddresspool -n metallb-system

# Check LoadBalancer got external IP
kubectl get svc -n istio-system istio-ingressgateway

# Check Istio pods
kubectl get pods -n istio-system

# View Terraform outputs
terraform output metallb_info
```

## Expected Results

**MetalLB:**

- Controller pod: 1/1 Running
- Speaker pod: 4/4 Running

**Istio Ingress Gateway:**

- EXTERNAL-IP: `172.18.255.200` (from MetalLB pool)
- TYPE: LoadBalancer

**All Istio Pods:**

- istio-cni-node: 1/1 Running
- istio-ingressgateway: 1/1 Running
- istiod: 1/1 Running

## Common Issues

### Issue: "no matches for kind IPAddressPool"

**Solution:** Use two-stage deployment as shown above.

### Issue: Service stuck in "Pending"

**Solution:** Check MetalLB pods are running: `kubectl get pods -n metallb-system`

### Issue: Wrong IP range

**Solution:** Verify Docker network: `docker network inspect kind | grep Subnet`

## Full Documentation

For complete guides, see:

- [MetalLB Setup Guide](docs/setup/metallb.md)
- [MetalLB Troubleshooting](docs/troubleshooting/metallb.md)
- [Testing Validation Report](docs/TESTING_VALIDATION_REPORT.md)

## Cleanup

To destroy all resources:

```bash
terraform destroy -auto-approve
```

---

**Pro Tip:** Save this file locally or bookmark the documentation links for quick reference!
