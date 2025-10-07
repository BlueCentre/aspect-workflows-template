# Documentation Index

**Last Updated:** October 8, 2025

This directory contains comprehensive documentation for the Pulumi local development environment. Documentation is organized by audience and purpose.

## 📚 Documentation Structure

```bash
docs/
├── setup/                      # Setup and configuration guides
│   └── metallb.md             # MetalLB LoadBalancer setup
├── troubleshooting/           # Problem-solving guides
│   └── metallb.md             # MetalLB troubleshooting
├── development/               # For contributors
│   └── (future contribution guides)
├── COMPONENTS.md              # Component catalog and details
├── pulumi_helm_best_practices.md
├── pulumi_utilities.md
├── resources_package.md
├── pulumi_troubleshooting.md
├── pulumi_tips_and_tricks.md
├── pulumi_passphrase_management.md
├── pulumi_non_interactive_deployments.md
└── HELM_VALUES_COMPARISON.md
```

## 👥 Documentation by Audience

### For Users (Deploying and Using Infrastructure)

**Getting Started:**

- [Main README](../README.md) - Project overview and quick start
- [Components Guide](COMPONENTS.md) - Available components and their purpose

**Setup Guides:**

- [MetalLB Setup](setup/metallb.md) - Configure LoadBalancer support for local/bare-metal clusters

**Operational:**

- [Pulumi Tips and Tricks](pulumi_tips_and_tricks.md) - Best practices and shortcuts
- [Passphrase Management](pulumi_passphrase_management.md) - Secure configuration management
- [Non-Interactive Deployments](pulumi_non_interactive_deployments.md) - Automation and CI/CD

### For Administrators (Managing and Operating Infrastructure)

**Configuration:**

- [MetalLB Setup Guide](setup/metallb.md) - LoadBalancer configuration and IP pool management
- [Components Configuration](COMPONENTS.md) - Enable/disable and configure components

**Troubleshooting:**

- [MetalLB Troubleshooting](troubleshooting/metallb.md) - Diagnose and fix LoadBalancer issues
- [Pulumi Troubleshooting](pulumi_troubleshooting.md) - General Pulumi problem-solving
- [Helm Values Comparison](HELM_VALUES_COMPARISON.md) - Compare configuration approaches

**Maintenance:**

- [Pulumi Tips and Tricks](pulumi_tips_and_tricks.md) - Operational best practices
- [Non-Interactive Deployments](pulumi_non_interactive_deployments.md) - Automation strategies

### For Contributors (Developing and Extending)

**Architecture:**

- [Components Guide](COMPONENTS.md) - Component architecture and implementation
- [Resources Package](resources_package.md) - Abstraction layer for Kubernetes resources
- [Pulumi Utilities](pulumi_utilities.md) - Utility functions and helpers

**Development:**

- [Helm Best Practices](pulumi_helm_best_practices.md) - Helm chart deployment patterns
- [Main README](../README.md#adding-a-new-component) - Adding new components

**Quality:**

- [Pulumi Tips and Tricks](pulumi_tips_and_tricks.md) - Development best practices

## 📖 Quick Reference

### Common Tasks

| Task | Documentation |
|------|---------------|
| **First-time setup** | [README - Quick Start](../README.md#quick-start) |
| **Enable MetalLB** | [MetalLB Setup](setup/metallb.md#configuration) |
| **LoadBalancer not getting IP** | [MetalLB Troubleshooting](troubleshooting/metallb.md#issue-1-service-stuck-with-external-ip-pending) |
| **Add new component** | [README - Adding Components](../README.md#adding-a-new-component) |
| **Configure component** | [Components Guide](COMPONENTS.md) |
| **Deployment fails** | [Pulumi Troubleshooting](pulumi_troubleshooting.md) |
| **Understand project structure** | [README - Modular Structure](../README.md#modular-structure) |
| **Helm chart patterns** | [Helm Best Practices](pulumi_helm_best_practices.md) |
| **CI/CD integration** | [Non-Interactive Deployments](pulumi_non_interactive_deployments.md) |

### By Technology

| Technology | Documentation |
|------------|---------------|
| **MetalLB** | [Setup](setup/metallb.md) · [Troubleshooting](troubleshooting/metallb.md) |
| **Istio** | [Components Guide](COMPONENTS.md#istio) |
| **Cert Manager** | [Components Guide](COMPONENTS.md#cert-manager) |
| **CloudNativePG** | [Components Guide](COMPONENTS.md#cloudnativepg) |
| **OpenTelemetry** | [Components Guide](COMPONENTS.md#opentelemetry) |
| **Pulumi** | [Troubleshooting](pulumi_troubleshooting.md) · [Tips](pulumi_tips_and_tricks.md) |
| **Helm** | [Best Practices](pulumi_helm_best_practices.md) · [Values Comparison](HELM_VALUES_COMPARISON.md) |

## 🔍 Finding Documentation

### By Problem

**"LoadBalancer service stuck in pending"**
→ [MetalLB Troubleshooting - Issue 1](troubleshooting/metallb.md#issue-1-service-stuck-with-external-ip-pending)

**"Need to configure IP range for MetalLB"**
→ [MetalLB Setup - Configuration](setup/metallb.md#configuration)

**"Pulumi deployment failing"**
→ [Pulumi Troubleshooting](pulumi_troubleshooting.md)

**"Can't reach LoadBalancer IP from host"**
→ [MetalLB Troubleshooting - Issue 2](troubleshooting/metallb.md#issue-2-external-ip-not-reachable)

**"MetalLB pods crashing"**
→ [MetalLB Troubleshooting - Issue 3](troubleshooting/metallb.md#issue-3-metallb-controllerspeaker-pods-crashlooping)

**"How to add a new component"**
→ [README - Adding Components](../README.md#adding-a-new-component)

**"Understanding resource abstractions"**
→ [Resources Package](resources_package.md)

### By Keyword

- **Load Balancer / LoadBalancer** → [MetalLB Setup](setup/metallb.md)
- **External IP / Pending** → [MetalLB Troubleshooting](troubleshooting/metallb.md)
- **kind / minikube / bare-metal** → [MetalLB Setup](setup/metallb.md#when-to-use-metallb)
- **Helm charts / values** → [Helm Best Practices](pulumi_helm_best_practices.md)
- **Secrets / passphrases** → [Passphrase Management](pulumi_passphrase_management.md)
- **CI/CD / automation** → [Non-Interactive Deployments](pulumi_non_interactive_deployments.md)
- **Dependencies / order** → [Pulumi Troubleshooting](pulumi_troubleshooting.md)

## 📝 Contributing to Documentation

When contributing documentation:

1. **Choose the right location:**
   - User-facing guides → `setup/` or main README
   - Troubleshooting → `troubleshooting/`
   - Development guides → `development/`
   - Technical reference → Root `docs/` folder

2. **Include audience indicator:**
   - Add "Audience: Users, Admins, Contributors" at the top
   - Use appropriate technical level

3. **Keep it updated:**
   - Add "Last Updated" date
   - Update this index when adding new docs
   - Review and update quarterly

4. **Link extensively:**
   - Cross-reference related documentation
   - Link to external resources
   - Update the quick reference table

## 🔗 External Resources

- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [kind Documentation](https://kind.sigs.k8s.io/)

## 📞 Getting Help

1. **Check documentation:** Start with this index to find relevant guides
2. **Search issues:** Look for similar problems in troubleshooting guides
3. **Run diagnostics:** Use commands from troubleshooting guides
4. **Gather logs:** Collect relevant logs before asking for help
5. **Contact team:** Platform team, DevOps lead, or community channels

## 📅 Documentation Maintenance

This documentation is actively maintained by the platform team. If you find outdated information or missing topics:

- Open an issue
- Submit a pull request
- Contact the platform team
- Update and notify in team channels
