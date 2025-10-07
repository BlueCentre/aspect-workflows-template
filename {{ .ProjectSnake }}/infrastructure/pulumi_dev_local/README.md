# Pulumi Local Development Environment

[![Pulumi](https://img.shields.io/badge/pulumi-%235C4EE5.svg?style=for-the-badge&logo=pulumi&logoColor=white)](https://www.pulumi.com/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Colima](https://img.shields.io/badge/colima-local_k8s-blue?style=for-the-badge)](https://github.com/abiosoft/colima)
[![Go](https://img.shields.io/badge/go-%2300ADD8.svg?style=for-the-badge&logo=go&logoColor=white)](https://golang.org/)

A Pulumi Go-based toolkit for provisioning and managing essential Kubernetes components for local containerized application development.

## Overview

This directory contains a comprehensive Pulumi implementation written in Go, designed to provision and manage essential Kubernetes components for containerized application development in a local environment (specifically using Colima). This setup provides a consistent, reproducible way to deploy commonly used infrastructure components that support modern application development workflows.

The Go implementation offers improved type safety, enhanced error handling, and powerful programmatic control over infrastructure deployment compared to the YAML-based approach, while maintaining the same component feature set and configuration flexibility.

## Key Components Available

The configuration allows developers to selectively enable and deploy:

| Component | Description | Status | Default |
|-----------|-------------|--------|---------|
| **Cert Manager** | Automates the management and issuance of TLS certificates | ✅ Active | ✅ Enabled |
| **Istio** | Complete service mesh with Base, CNI, Control Plane, and Ingress Gateway | ✅ Active | ✅ Enabled |
| **OpenTelemetry** | Observability stack with Operator and Collector for metrics, tracing, and logging | ✅ Active | ✅ Enabled | 
| **External Secrets** | Integration with external secret management systems | ✅ Active | ✅ Enabled |
| **CloudNativePG** | Kubernetes operator for PostgreSQL database clusters | ✅ Active | ✅ Enabled |
| **MetalLB** | LoadBalancer implementation for bare-metal and local clusters (kind/minikube) | ✅ Active | ✅ Enabled |
| **Argo CD** | GitOps continuous delivery tool | ✅ Active | ❌ Disabled |
| **Telepresence** | Local development tool for remote Kubernetes connections | ✅ Active | ❌ Disabled |
| **External DNS** | Automated DNS configuration for Kubernetes services | ✅ Active | ❌ Disabled |
| **Datadog** | Application monitoring and analytics platform | ✅ Active | ❌ Disabled |
| **Monitoring** | Prometheus and Grafana stack for metrics monitoring | ✅ Active | ❌ Disabled |

**Note**: "Active" status means the component is implemented and ready to use. The "Default" column indicates whether the component is enabled by default in the current configuration. Engineers can enable disabled components by setting their respective flags to `"true"` in `Pulumi.dev.yaml`.

## LoadBalancer Support with MetalLB

### Why MetalLB?

Local Kubernetes clusters (kind, minikube) and bare-metal clusters don't have built-in LoadBalancer support like cloud providers (GKE, EKS, AKS). When you create a LoadBalancer service in these environments, it stays in `<pending>` state indefinitely.

**MetalLB solves this problem** by providing a network load balancer implementation that:

- ✅ **Works locally**: Perfect for kind/minikube development
- ✅ **Production-like**: Mimics cloud LoadBalancer behavior
- ✅ **Standard ports**: Services use normal ports (80, 443) instead of NodePorts (30000+)
- ✅ **Seamless ingress**: Works perfectly with Istio, NGINX, and other ingress controllers
- ✅ **Bare-metal ready**: Also works for on-premises and edge deployments

### When to Use MetalLB

| Environment | Use MetalLB? | Why |
|-------------|--------------|-----|
| **kind cluster** | ✅ Yes | No native LoadBalancer support |
| **minikube** | ✅ Yes | No native LoadBalancer support |
| **Bare-metal/On-prem** | ✅ Yes | No native LoadBalancer support |
| **GKE/EKS/AKS** | ❌ No | Cloud providers have native LoadBalancer |
| **Docker Desktop K8s** | ⚠️ Optional | Has some LoadBalancer support, but MetalLB provides more control |

### Configuration

MetalLB is configured in `Pulumi.local.yaml`:

```yaml
config:
  # Enable MetalLB (recommended for kind/minikube)
  monorepo:metallb_enabled: "true"
  monorepo:metallb_version: "0.14.9"
  
  # IP range must match your cluster network
  # For kind: Use 172.18.x.x range (check with `docker network inspect kind`)
  # For minikube: Use 192.168.x.x range
  # For bare-metal: Use available IPs in your network
  monorepo:metallb_ip_range: "172.18.255.200-172.18.255.250"
```

### Finding the Right IP Range

**For kind clusters:**

```bash
# Inspect the kind network to find the subnet
docker network inspect kind | grep Subnet

# Example output: "Subnet": "172.18.0.0/16"
# Use IPs from the high end: 172.18.255.200-172.18.255.250
```

**For minikube:**

```bash
# Check minikube IP
minikube ip

# Example output: 192.168.49.2
# Use same subnet: 192.168.49.200-192.168.49.250
```

**For bare-metal:**

- Use available IPs from your network that won't conflict with DHCP
- Coordinate with your network administrator

### Verifying MetalLB

After deployment, verify MetalLB is working:

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check IP address pool
kubectl get ipaddresspool -n metallb-system

# Test with a LoadBalancer service (e.g., Istio ingress gateway)
kubectl get svc -n istio-system istio-ingressgateway

# Should show an EXTERNAL-IP from your configured range
# Example: EXTERNAL-IP = 172.18.255.200
```

**📚 For detailed MetalLB documentation:**

- **Setup Guide:** [docs/setup/metallb.md](./docs/setup/metallb.md) - Complete configuration and deployment instructions
- **Troubleshooting:** [docs/troubleshooting/metallb.md](./docs/troubleshooting/metallb.md) - Common issues and solutions

## Modular Structure

The Pulumi configuration has been organized in a modular way to improve maintainability and readability:

```bash
pulumi_dev_local/
├── main.go                # Main Go program entry point
├── Pulumi.yaml            # Project configuration
├── Pulumi.local.yaml      # Stack configuration
├── go.mod                 # Go module definition
├── go.sum                 # Go module dependencies
├── docs/                  # Comprehensive documentation
│   ├── README.md          # Documentation index
│   ├── setup/             # Setup and configuration guides
│   │   └── metallb.md     # MetalLB LoadBalancer setup
│   ├── troubleshooting/   # Problem-solving guides
│   │   └── metallb.md     # MetalLB troubleshooting
│   ├── COMPONENTS.md      # Component catalog and configuration
│   ├── pulumi_helm_best_practices.md
│   ├── pulumi_utilities.md
│   ├── resources_package.md
│   ├── pulumi_troubleshooting.md
│   ├── pulumi_tips_and_tricks.md
│   ├── pulumi_passphrase_management.md
│   ├── pulumi_non_interactive_deployments.md
│   └── HELM_VALUES_COMPARISON.md
├── values/                # Helm chart values YAML files
│   ├── cert-manager.yaml
│   ├── cnpg-cluster.yaml
│   ├── cnpg-operator.yaml
│   ├── datadog.yaml
│   ├── external-dns.yaml
│   ├── external-secrets.yaml
│   ├── istio-base.yaml
│   ├── metallb.yaml
│   ├── mongodb-community-operator.yaml
│   ├── monitoring.yaml
│   ├── opentelemetry-collector.yaml
│   ├── opentelemetry-operator.yaml
│   └── redis.yaml
└── pkg/                   # Go package directory
    ├── applications/      # Individual component implementations
    │   ├── argocd.go
    │   ├── cert_manager.go
    │   ├── cnpg.go
    │   ├── database.go
    │   ├── datadog.go
    │   ├── external_dns.go
    │   ├── external_secrets.go
    │   ├── external_secrets_store.go
    │   ├── ingress.go
    │   ├── istio.go
    │   ├── metallb.go     # MetalLB LoadBalancer
    │   ├── mongodb.go
    │   ├── monitoring.go
    │   ├── opentelemetry.go
    │   ├── redis.go
    │   ├── telepresence.go
    │   └── utils.go
    ├── resources/         # Kubernetes resource abstractions
    │   ├── helm.go        # Helm chart deployment
    │   ├── kubernetes.go  # Kubernetes resources
    │   ├── manifest.go    # YAML manifest deployment
    │   └── namespace.go   # Namespace management
    └── utils/             # Utility functions
        ├── config.go      # Configuration helpers
        └── yaml.go        # YAML processing
```

### Helm Values Management

This project uses external YAML files for managing Helm chart values, located in the `values/` directory. This approach offers several benefits:

1. **Separation of Configuration**: Keeps Helm values separate from deployment logic
2. **Improved Maintainability**: Makes it easier to update and maintain values without changing code
3. **Consistency**: Uses the same format and structure across all components
4. **Portability**: Values can be reused with other IaC tools if needed

Each component in `pkg/applications/` automatically loads values from its corresponding YAML file when deployed. Runtime overrides can still be applied when needed.

For more details on our Helm best practices, see [Pulumi Helm Best Practices](./docs/pulumi_helm_best_practices.md).

### Enabling and Disabling Components

This Pulumi setup allows you to easily enable or disable components through configuration:

1. **Update Pulumi.dev.yaml**:

   The `Pulumi.local.yaml` file contains the configuration for each component:

   ```yaml
   config:
     monorepo:cert_manager_enabled: "true"
     monorepo:opentelemetry_enabled: "true"
     monorepo:istio_enabled: "true"
     monorepo:external_secrets_enabled: "true"
     monorepo:external_dns_enabled: "false"
     monorepo:datadog_enabled: "false"
     monorepo:argocd_enabled: "false"
   ```

   Set a component to `"true"` to enable it or `"false"` to disable it.

### Go-Based Implementation

This Pulumi configuration uses Go as the implementation language, providing several benefits:

1. **Type Safety**: Go's strong typing helps prevent configuration errors.
2. **Better Modularity**: Each component is defined in its own Go file in the `pkg/applications/` directory.
3. **Advanced Logic**: Complex conditional logic can be implemented for component deployments.
4. **Better Testability**: Go code can be tested with standard testing frameworks.
5. **Extended Functionality**: Direct access to the Kubernetes API server when needed.

### Utility Packages

This project provides several utility packages that make component implementation more consistent and efficient:

1. **Configuration Utilities**: Simplifies working with Pulumi configuration by adding type conversion and default value handling.
2. **YAML Utilities**: Streamlines loading and merging of Helm chart values from YAML files.

These utilities help ensure consistent patterns across all components and reduce boilerplate code. For more details, see [Pulumi Utilities Documentation](./docs/pulumi_utilities.md).

### Resources Package

This project also includes a specialized `resources` package that provides high-level abstractions for creating and managing Kubernetes resources:

1. **Helm Chart Deployment**: Standardized Helm chart deployment with value loading, cleanup capabilities, and proper error handling.
2. **Kubernetes Resource Creation**: Simplified creation of namespaces, ConfigMaps, and other Kubernetes resources.
3. **YAML Manifest Deployment**: Easy deployment of raw YAML manifests to Kubernetes.

The resources package serves as an abstraction layer between the raw Pulumi Kubernetes SDK and our application-specific code, promoting consistency and reducing duplication. For more details, see [Resources Package Documentation](./docs/resources_package.md).

### Handling Complex Components

For guidance on implementing components with advanced requirements (like multiple Helm charts, internal dependencies, conditional logic, or raw YAML manifests), please refer to the detailed guide:

- [Contributing Complex IAC Components](../../docs/CONTRIBUTING_COMPLEX_IAC_COMPONENTS.md)

This guide uses the Istio implementation as a case study and references the corresponding `.cursorrules` template for AI development assistance.

### Customizing Components

To customize a component:

1. Edit the relevant component file in the `pkg/applications/` directory
2. Modify the corresponding values YAML file in the `values/` directory
3. Run `pulumi preview` to see the changes
4. Apply the changes with `pulumi up`

For example, to customize the Istio component:

1. Edit `pkg/applications/istio.go` to modify deployment logic
2. Edit `values/istio.yaml` to change Helm values
3. Run `pulumi preview` to verify changes
4. Run `pulumi up` to apply changes

### Adding a New Component

To add a new component:

1. Create a new Go file in the `pkg/applications/` directory
2. Create a new values YAML file in the `values/` directory if needed
3. Add the component initialization to `main.go`
4. Add appropriate configuration options to `Pulumi.dev.yaml`
5. Preview and apply the changes

For example, to add a new component called "example-component":

1. Create `pkg/applications/example_component.go`
2. Create `values/example-component.yaml` with Helm values
3. Update `main.go` to include the new component
4. Add `monorepoe:example_component_enabled: "true"` to `Pulumi.local.yaml`
5. Run `pulumi preview` and `pulumi up`

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory. See the [Documentation Index](./docs/README.md) for a complete guide.

### Quick Links

**For Users:**

- [Getting Started](#getting-started) (below)
- [Components Guide](./docs/COMPONENTS.md) - Available components and configuration
- [MetalLB Setup](./docs/setup/metallb.md) - LoadBalancer configuration
- [Pulumi Tips & Tricks](./docs/pulumi_tips_and_tricks.md) - Best practices

**For Administrators:**

- [MetalLB Setup Guide](./docs/setup/metallb.md) - IP pool configuration and deployment
- [MetalLB Troubleshooting](./docs/troubleshooting/metallb.md) - Diagnose and fix issues
- [Pulumi Troubleshooting](./docs/pulumi_troubleshooting.md) - General problem-solving
- [Passphrase Management](./docs/pulumi_passphrase_management.md) - Secure configuration

**For Contributors:**

- [Helm Best Practices](./docs/pulumi_helm_best_practices.md) - Chart deployment patterns
- [Resources Package](./docs/resources_package.md) - Abstraction layer documentation
- [Pulumi Utilities](./docs/pulumi_utilities.md) - Helper functions
- [Adding Components](#adding-a-new-component) - Component development guide

### Common Tasks

| Need to... | See Documentation |
|------------|-------------------|
| Deploy for the first time | [Quick Start](#quick-start) (below) |
| Fix pending LoadBalancer IPs | [MetalLB Troubleshooting](./docs/troubleshooting/metallb.md#issue-1-service-stuck-with-external-ip-pending) |
| Configure IP range for MetalLB | [MetalLB Setup](./docs/setup/metallb.md#configuration) |
| Enable/disable components | [Components Guide](./docs/COMPONENTS.md) |
| Add a new component | [Adding Components](#adding-a-new-component) |
| Troubleshoot deployment failures | [Pulumi Troubleshooting](./docs/pulumi_troubleshooting.md) |
| Set up CI/CD | [Non-Interactive Deployments](./docs/pulumi_non_interactive_deployments.md) |

## Getting Started

### Prerequisites

- [Pulumi CLI](https://www.pulumi.com/docs/install/) (latest version)
- [Colima](https://github.com/abiosoft/colima) or another local Kubernetes environment (kind, minikube)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) configured to work with your local cluster

### Quick Start

1. **Initialize Pulumi**:

   ```bash
   cd pulumi_dev_local
   pulumi login --local
   pulumi stack init dev
   ```

2. **Set a Passphrase for Configuration Encryption**:

   Pulumi requires a passphrase to encrypt secrets. Set this securely, for example, using an environment variable:

   ```bash
   export PULUMI_CONFIG_PASSPHRASE="your-secure-passphrase"
   ```

   For detailed guidance on managing passphrases, see:

   - [Managing the Pulumi Passphrase](./docs/pulumi_passphrase_management.md)

3. **Configure Components**:

   Edit `Pulumi.local.yaml` to enable the components you need:

   ```yaml
   config:
     monorepoe:cert_manager_enabled: "true"
     monorepoe:opentelemetry_enabled: "true"
     monorepoe:istio_enabled: "true"
     monorepoe:external_secrets_enabled: "true"
     monorepoe:external_dns_enabled: "false"
     monorepoe:datadog_enabled: "false"
     monorepoe:argocd_enabled: "false"
   ```

4. **Configure Secrets**:

   Configure secrets for the enabled components:

   ```bash
   pulumi config set --secret monorepo:cloudflare_api_token <YOUR_CLOUDFLARE_API_TOKEN>
   pulumi config set --secret monorepo:github_token <YOUR_GITHUB_TOKEN>
   pulumi config set --secret monorepo:datadog_api_key <YOUR_DATADOG_API_KEY>
   pulumi config set --secret monorepo:datadog_app_key <YOUR_DATADOG_APP_KEY>
   pulumi config set --secret monorepo:redis_password <YOUR_REDIS_PASSWORD>
   pulumi config set --secret monorepo:cnpg_app_db_password <YOUR_CNPG_APP_DB_PASSWORD>
   pulumi config set --secret monorepo:mongodb_password <YOUR_MONGODB_PASSWORD>
   pulumi config set --secret monorepo:argocd_admin_password <YOUR_ARGOCD_ADMIN_PASSWORD>
   ```

   Then execute:

   ```bash
   pulumi config env init
   pulumi config refresh
   ```

5. **Preview the Deployment**:

   ```bash
   pulumi preview
   ```

6. **Deploy Resources**:

   ```bash
   pulumi up
   ```

   *For running deployments non-interactively (e.g., in CI/CD), refer to the guide:*
   *- [Non-Interactive Pulumi Deployments](./docs/pulumi_non_interactive_deployments.md)*

7. **Verify Installation**:

   ```bash
   kubectl get pods --all-namespaces
   ```

8. **Clean Up When Done**:

   ```bash
   # Destroy all resources managed by the stack
   pulumi destroy -y
   ```

## Deployed Components Details

For a comprehensive guide to all the components available and their configuration details, see the [COMPONENTS.md](./docs/COMPONENTS.md) file.

### Cert Manager

**Status**: ✅ Active
**Version**: v1.17.0
**Namespace**: cert-manager

Cert Manager provides automated certificate management capabilities in Kubernetes:

- Automates the issuance and renewal of TLS certificates
- Supports multiple issuers including Let's Encrypt, Vault, and self-signed certificates
- Simplifies certificate management for Kubernetes services and ingresses

### OpenTelemetry

**Status**: ✅ Active  
**Components**:

- OpenTelemetry Operator (v0.79.0)
- OpenTelemetry Collector (v0.79.0)

**Namespace**: opentelemetry

The OpenTelemetry deployment includes:

- **OpenTelemetry Operator**: Manages OpenTelemetry Collector instances and instrumentation
- **OpenTelemetry Collector**: Collects, processes, and exports telemetry data
- Support for collecting metrics, traces, and logs from applications
- Integration with various backends and observability tools

### Istio

**Status**: ✅ Active  
**Version**: 1.23.3  
**Components**:

- Istio Base
- Istio CNI
- Istio Control Plane (istiod)
- Istio Ingress Gateway

**Namespace**: istio-system

The complete Istio deployment provides:

- **Service Mesh Capabilities**: Traffic management, security, and observability
- **Istio CNI**: Network management without privileged init containers
- **Istio Control Plane**: Core service mesh functionality
- **Istio Ingress Gateway**: External traffic management with:
  - HTTP port: 80 (targeting 8080)
  - HTTPS port: 443 (targeting 8443)
  - Service type: ClusterIP (for local development)

The Ingress Gateway can be accessed locally through port-forwarding:

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

## External Secrets and External DNS

The Pulumi configuration includes External Secrets (version 0.14.4) and External DNS (version 1.15.0) Helm charts, matching the versions used in the terraform_dev_local configuration.

### External Secrets Operator

External Secrets Operator is installed with the following configuration:

- Installs CRDs
- Creates ClusterExternalSecret and ClusterSecretStore CRDs
- Creates a service account for the operator
- Disables webhook and cert controller for local development

**Note:** With the current configuration, External Secrets Operator is enabled (`external_secrets_enabled: "true"`), but no secret stores will be created since both `external_dns_enabled` and `datadog_enabled` are set to `"false"`.

### External DNS

External DNS is configured to:

- Use Cloudflare as the provider
- Pull API token from a Kubernetes secret (cf-secret)
- Use bluecentre-dev as the TXT owner ID
- Sync records with a 30-minute interval
- Only process resources with the annotation `external-dns.alpha.kubernetes.io/sync-enabled: "true"`
- Monitor istio-gateway resources for DNS entries

**Note:** External DNS is currently disabled in the configuration (`external_dns_enabled: "false"`).

### Manual Post-Deployment Steps

If you decide to enable External DNS (`external_dns_enabled: "true"`), you would need to manually create the following resources after deployment:

1. A ClusterSecretStore to serve as a fake secret provider:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: external-secret-cluster-fake-secrets
  namespace: external-secrets
spec:
  provider:
    fake:
      data:
      - key: "CLOUDFLARE_API_TOKEN"
        value: "REPLACE_WITH_CLOUDFLARE_API_TOKEN"
        version: "v1"
```

2. An ExternalSecret to retrieve the Cloudflare API token:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cf-external-secret
  namespace: external-dns
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: external-secret-cluster-fake-secrets
  target:
    name: cf-secret
    creationPolicy: Owner
    template:
      metadata:
        labels:
          service: external-dns
        annotations:
          reloader.stakater.com/match: "true"
  data:
    - secretKey: cloudflare-api-key
      remoteRef:
        key: CLOUDFLARE_API_TOKEN
        version: v1
```

These resources can be applied using `kubectl apply -f <filename>` after enabling and deploying the External DNS component.

Alternatively, you would use the provided post-deployment script after enabling the component:

```bash
# First update the configuration and deploy with Pulumi
# Edit Pulumi.dev.yaml to set external_dns_enabled: "true"
pulumi up

# Then run the post-deployment script
./post-deploy.sh
```

The script will create the necessary custom resources for external-secrets and external-dns integration.

### Enabling Components in Your Configuration

To enable External DNS or Datadog integration with External Secrets, update the `Pulumi.dev.yaml` file:

```yaml
config:
  # Enable External DNS integration (will create Cloudflare secret store)
  monorepo:external_dns_enabled: "true"
  
  # Enable Datadog integration (will create Datadog secret store)
  monorepo:datadog_enabled: "true"
```

Then run `pulumi up` to apply the changes.

## Redis for Istio Rate Limiting

The Bitnami Redis Helm chart is included to support rate limiting in Istio and provide Redis services for applications. It is deployed in a dedicated `redis` namespace with multi-tenant capabilities.

### Usage

1. Enable Redis by setting `redis_enabled` to `"true"` in `Pulumi.dev.yaml`
2. Apply the configuration with `pulumi up`

Redis will be deployed in the dedicated `redis` namespace and configured for use with both Istio's rate limiting service and as a general-purpose Redis instance for applications.

### Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| redis_enabled | Enable or disable Redis deployment | "false" |
| redis_password | Password for Redis authentication | "redis-password" |

### Connecting to Redis

Application developers can connect to Redis using:

```bash
# Host and port configuration
REDIS_HOST=redis-master.redis.svc.cluster.local
REDIS_PORT=6379

# Test connection to Redis
kubectl exec -it -n redis deploy/redis-master -- redis-cli -a $(kubectl get secret -n redis redis -o jsonpath="{.data.redis-password}" | base64 --decode)
```

### Multi-tenant Usage

The Redis deployment includes:

- Network policies allowing connections from all namespaces
- Appropriate security contexts for secure multi-tenant usage
- High availability with 1 master and 2 replicas
- AOF persistence enabled for better durability

### Testing Rate Limiting

To verify Redis is working with Istio rate limiting:

```bash
# Test rate limiting functionality in the template-fastapi-app
skaffold verify -m template-fastapi-app -p istio-rate-limit
```
