# Terraform Local Development Documentation

Welcome to the Terraform local development environment documentation. This guide helps you navigate the comprehensive documentation for deploying and managing Kubernetes infrastructure using Terraform.

**Audience:** All Users (Platform Engineers, DevOps Engineers, SREs, Application Developers)

**Last Updated:** 2025-01-17

## 📚 Documentation Structure

This documentation is organized into the following categories:

### 🚀 Setup Guides

Step-by-step instructions for deploying and configuring infrastructure components.

- **[MetalLB Setup Guide](setup/metallb.md)** - Deploy LoadBalancer support for kind/bare-metal clusters
  - *Audience: Platform Engineers, DevOps Engineers*
  - Prerequisites, configuration, environment-specific setup for kind/minikube/bare-metal
  - IP range planning and validation steps

### 🔧 Troubleshooting

Solutions to common issues and debugging techniques.

- **[MetalLB Troubleshooting](troubleshooting/metallb.md)** - Resolve MetalLB deployment and networking issues
  - *Audience: Platform Engineers, DevOps Engineers, SREs*
  - 6 common issues with detailed solutions
  - Debugging commands and prevention best practices

- **[Terraform Troubleshooting Guide](troubleshooting/terraform_troubleshooting.md)** - General Terraform issues and solutions
  - *Audience: Platform Engineers, DevOps Engineers*
  - State drift, dependency issues, and resource conflicts
  - Terraform-specific debugging techniques

### 💻 Development Guides

In-depth guides for working with Terraform and understanding the infrastructure.

- **[Terraform CRD Best Practices](development/terraform-crds-best-practices.md)** - Handle Custom Resource Definitions correctly
  - *Audience: Platform Engineers, Infrastructure Developers*
  - Provider choice (kubectl_manifest vs kubernetes_manifest)
  - Time delays and dependency management for CRD resources
  - Examples from MetalLB implementation

- **[Terraform Usage and Details Guide](development/TERRAFORM_GUIDE.md)** - Comprehensive Terraform workflow guide
  - *Audience: Platform Engineers, Infrastructure Developers*
  - Component selection, variable management, and best practices
  - Detailed explanation of Terraform structure and patterns

- **[Terraform Tips and Tricks](development/terraform_tips_and_tricks.md)** - Productivity tips and advanced techniques
  - *Audience: Terraform Users, DevOps Engineers*
  - Useful command-line flags and workflow optimizations
  - Performance tuning and debugging tips

### 📖 Reference Documentation

- **[Supported Components](COMPONENTS.md)** - Complete list of deployable components
  - *Audience: All Users*
  - Cert Manager, Istio, MetalLB, OpenTelemetry, Redis, MongoDB, CNPG, and more
  - Component versions, features, and configuration details

- **[Testing & Validation Report](TESTING_VALIDATION_REPORT.md)** - Live infrastructure testing results
  - *Audience: Platform Engineers, DevOps Engineers, QA*
  - Complete deployment testing in kind cluster
  - Documentation accuracy verification
  - Performance metrics and issues discovered

## 🎯 Quick Navigation by Role

### Platform Engineers

You'll likely need:

1. [Terraform Usage and Details Guide](development/TERRAFORM_GUIDE.md) - Understand the infrastructure structure
2. [MetalLB Setup Guide](setup/metallb.md) - Enable LoadBalancer support
3. [Supported Components](COMPONENTS.md) - Review available infrastructure components
4. [Terraform Troubleshooting](troubleshooting/terraform_troubleshooting.md) - Resolve deployment issues

### DevOps Engineers / SREs

You'll likely need:

1. [MetalLB Setup Guide](setup/metallb.md) - Deploy LoadBalancer infrastructure
2. [MetalLB Troubleshooting](troubleshooting/metallb.md) - Debug networking issues
3. [Terraform Tips and Tricks](development/terraform_tips_and_tricks.md) - Optimize workflows
4. [Terraform Troubleshooting](troubleshooting/terraform_troubleshooting.md) - Fix deployment problems

### Application Developers

You'll likely need:

1. [Supported Components](COMPONENTS.md) - Understand available services (databases, observability, etc.)
2. [MetalLB Setup Guide](setup/metallb.md) - If deploying LoadBalancer services
3. Main [README.md](../README.md) - Quick start and common tasks

## 🔍 Documentation Standards

All documentation in this directory follows these standards:

### Metadata Headers

Every document includes:

- **Audience:** Target users (Platform Engineers, DevOps Engineers, SREs, etc.)
- **Last Updated:** Date of last significant update (YYYY-MM-DD)

### Organization

- **Setup Guides** (`setup/`): Step-by-step deployment instructions
- **Troubleshooting** (`troubleshooting/`): Problem-solution pairs with debugging commands
- **Development** (`development/`): In-depth technical documentation and workflows
- **Reference** (root): Component catalogs and quick references

### Cross-References

Documents link to related content:

- Prerequisites link to setup guides
- Troubleshooting links to relevant component documentation
- Setup guides link to troubleshooting for common issues

## 📝 Recent Updates

### 2025-10-09: Single-Stage Deployment Solution

- **RESOLVED:** CRD timing issue - no more two-stage deployments needed!
- Switched to `kubectl_manifest` provider with `time_sleep` resource
- Updated all documentation to reflect simplified single-command deployment
- Added comprehensive CRD best practices guide

### 2025-01-17: MetalLB Documentation

- Added comprehensive MetalLB setup guide for kind/minikube/bare-metal
- Created MetalLB troubleshooting guide with 6 common scenarios
- Standardized all documentation with audience/date metadata
- Reorganized documentation into structured directories

### Documentation Improvement Plan

See [DOCUMENTATION_AUDIT.md](DOCUMENTATION_AUDIT.md) for:

- Quality assessment of all documentation
- Identified improvement areas
- Roadmap for future documentation enhancements

## 🛠️ Quick Start

New to this Terraform environment? Start here:

1. **Read the main [README.md](../README.md)** for project overview and prerequisites
2. **Review [Supported Components](COMPONENTS.md)** to understand what's available
3. **Follow [Terraform Usage Guide](development/TERRAFORM_GUIDE.md)** for deployment workflow
4. **Enable [MetalLB](setup/metallb.md)** if deploying to kind/minikube/bare-metal
5. **Reference [Tips and Tricks](development/terraform_tips_and_tricks.md)** for productivity

## 🔗 External Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 📧 Getting Help

If you encounter issues:

1. **Check troubleshooting guides** for your specific component
2. **Review Terraform logs** with `TF_LOG=DEBUG terraform apply`
3. **Inspect Kubernetes resources** with `kubectl describe` and `kubectl logs`
4. **Search GitHub issues** in relevant component repositories
5. **Open an issue** in this repository with full context

## 🎓 Learning Path

### Beginner

1. [Main README.md](../README.md) - Project overview
2. [Supported Components](COMPONENTS.md) - What's available
3. [Terraform Usage Guide](development/TERRAFORM_GUIDE.md) - Basic workflows

### Intermediate

1. [Terraform Tips and Tricks](development/terraform_tips_and_tricks.md) - Optimize workflows
2. [MetalLB Setup](setup/metallb.md) - Advanced networking
3. [Terraform Troubleshooting](troubleshooting/terraform_troubleshooting.md) - Debug issues

### Advanced

1. Component-specific deep dives in [COMPONENTS.md](COMPONENTS.md)
2. Terraform module development patterns
3. Custom Helm values and resource manifests

---

**Documentation Maintenance:**

- All documents follow consistent audience/date metadata format
- Cross-references validated quarterly
- Updates reflect latest component versions
- Community contributions welcome via pull requests

*For questions about this documentation, please open an issue with the `documentation` label.*
