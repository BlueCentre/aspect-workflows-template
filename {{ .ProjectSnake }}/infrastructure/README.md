# IaC for local development

For those that have or use multiple colima profiles, this approach will allow you rename your current profile's k8s context to `local-dev-cluster` so all your IaC code can stay the same.

Rename local k8s context:
```bash
# Get the current context
$ kubectl config get-contexts

# Replace 'old-name' from above
$ kubectl config rename-context old-name local-dev-cluster
```
