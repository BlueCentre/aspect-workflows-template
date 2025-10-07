package applications

import (
	"fmt"

	"github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"

	"github.com/james/monorepo/pulumi_dev_local/pkg/resources"
	"github.com/james/monorepo/pulumi_dev_local/pkg/utils"
)

// DeployMetalLB deploys MetalLB load balancer for bare-metal Kubernetes clusters
// MetalLB provides LoadBalancer service support for clusters that don't have a cloud provider
// Useful for: kind, minikube, bare-metal, on-premises clusters
func DeployMetalLB(ctx *pulumi.Context, provider *kubernetes.Provider) error {
	// Get configuration
	conf := utils.NewConfig(ctx)
	version := conf.GetString("metallb_version", "0.14.9")
	namespace := "metallb-system"

	// Get IP address range for LoadBalancer services
	// Default to a range suitable for kind/Docker networks
	ipRange := conf.GetString("metallb_ip_range", "172.18.255.200-172.18.255.250")

	ctx.Log.Info(fmt.Sprintf("Deploying MetalLB version %s with IP range: %s", version, ipRange), nil)

	// Deploy MetalLB using Helm chart
	metallbRelease, err := resources.DeployHelmChart(ctx, provider, resources.HelmChartConfig{
		Name:            "metallb",
		Namespace:       namespace,
		ChartName:       "metallb",
		RepositoryURL:   "https://metallb.github.io/metallb",
		Version:         version,
		CreateNamespace: true,
		ValuesFile:      "metallb",
		Wait:            true,
		Timeout:         300,
	})
	if err != nil {
		return err
	}

	ctx.Log.Info("MetalLB operator deployed successfully", nil)

	// Create IPAddressPool CRD
	// This defines the range of IP addresses MetalLB can assign to LoadBalancer services
	ipAddressPoolYAML := fmt.Sprintf(`apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: %s
spec:
  addresses:
  - %s`, namespace, ipRange)

	_, err = resources.CreateK8sManifest(ctx, provider, resources.K8sManifestConfig{
		Name: "metallb-ipaddresspool",
		YAML: ipAddressPoolYAML,
	}, pulumi.DependsOn([]pulumi.Resource{metallbRelease}))
	if err != nil {
		return err
	}

	ctx.Log.Info("MetalLB IPAddressPool created successfully", nil)

	// Create L2Advertisement CRD
	// This tells MetalLB to advertise the LoadBalancer IPs on the local network using L2 (ARP)
	l2AdvertisementYAML := fmt.Sprintf(`apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2-advertisement
  namespace: %s
spec:
  ipAddressPools:
  - default-pool`, namespace)

	_, err = resources.CreateK8sManifest(ctx, provider, resources.K8sManifestConfig{
		Name: "metallb-l2advertisement",
		YAML: l2AdvertisementYAML,
	}, pulumi.DependsOn([]pulumi.Resource{metallbRelease}))
	if err != nil {
		return err
	}

	ctx.Log.Info("MetalLB L2Advertisement created successfully", nil)
	ctx.Log.Info("MetalLB is now ready to assign external IPs to LoadBalancer services", nil)

	return nil
}
