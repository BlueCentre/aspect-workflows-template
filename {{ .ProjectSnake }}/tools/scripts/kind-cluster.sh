#!/usr/bin/env bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

CLUSTER_NAME="local-dev-cluster"
CONFIG_FILE=".devcontainer/kind-config.yaml"

function print_success() {
	echo -e "${GREEN}✓${NC} $1"
}

function print_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}

function print_error() {
	echo -e "${RED}✗${NC} $1"
}

function check_docker() {
	if ! docker info >/dev/null 2>&1; then
		print_error "Docker is not running. Please ensure Docker is started."
		exit 1
	fi
	print_success "Docker is running"
}

function cluster_exists() {
	kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

function get_context_for_cluster() {
	# Get the kubectl context name for the kind cluster
	local cluster_name="$1"
	# Check if context with kind prefix exists
	if kubectl config get-contexts "kind-${cluster_name}" &>/dev/null; then
		echo "kind-${cluster_name}"
	# Check if context without prefix exists
	elif kubectl config get-contexts "${cluster_name}" &>/dev/null; then
		echo "${cluster_name}"
	else
		echo ""
	fi
}

function get_cluster_for_context() {
	# Get the cluster name from a context
	local context_name="$1"
	kubectl config view -o jsonpath="{.contexts[?(@.name=='${context_name}')].context.cluster}" 2>/dev/null
}

function is_in_devcontainer() {
	# Check if running inside a dev container
	# Dev containers set the REMOTE_CONTAINERS environment variable
	# or have /.dockerenv file (when container is running)
	if [ -n "${REMOTE_CONTAINERS}" ] || [ -n "${CODESPACES}" ] || [ -f "/.dockerenv" ]; then
		return 0
	fi
	return 1
}

function fix_devcontainer_connection() {
	# When running in a dev container, we need to use host.docker.internal
	# instead of 127.0.0.1 to reach the host machine where kind is running
	local context_name="$1"
	local cluster_name
	
	print_warning "Dev container detected - fixing kubectl connection..."
	
	# Get the cluster name from the context
	cluster_name=$(get_cluster_for_context "${context_name}")
	
	if [ -z "${cluster_name}" ]; then
		print_error "Could not find cluster for context '${context_name}'"
		return 1
	fi
	
	# Get the current server URL and extract the port
	local current_server
	current_server=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='${cluster_name}')].cluster.server}" 2>/dev/null)
	local port=$(echo "${current_server}" | grep -oP '\d+$')
	
	if [ -z "${port}" ]; then
		print_error "Could not extract port from server URL: ${current_server}"
		return 1
	fi
	
	# Update server URL to use host.docker.internal
	kubectl config set-cluster "${cluster_name}" --server=https://host.docker.internal:${port}
	
	# Skip TLS verification since cert doesn't include host.docker.internal
	kubectl config set-cluster "${cluster_name}" --insecure-skip-tls-verify=true
	
	print_success "kubectl configured for dev container environment (cluster: ${cluster_name}, port: ${port})"
}

function create_cluster() {
	echo "Creating kind cluster '${CLUSTER_NAME}'..."

	if cluster_exists; then
		print_warning "Cluster '${CLUSTER_NAME}' already exists"
		return 0
	fi

	kind create cluster --config="${CONFIG_FILE}" --wait=5m
	print_success "Cluster created successfully"

	# Discover the kubectl context (kind prefixes with 'kind-')
	local context_name
	context_name=$(get_context_for_cluster "${CLUSTER_NAME}")
	
	if [ -z "${context_name}" ]; then
		print_error "Could not find kubectl context for cluster '${CLUSTER_NAME}'"
		return 1
	fi
	
	kubectl cluster-info --context "${context_name}" || true
	print_success "kubectl configured to use ${context_name}"
	
	# Fix connection if running in dev container
	if is_in_devcontainer; then
		fix_devcontainer_connection "${context_name}"
	fi
}

function delete_cluster() {
	echo "Deleting kind cluster '${CLUSTER_NAME}'..."

	if ! cluster_exists; then
		print_warning "Cluster '${CLUSTER_NAME}' does not exist"
		return 0
	fi

	kind delete cluster --name="${CLUSTER_NAME}"
	print_success "Cluster deleted successfully"
}

function status_cluster() {
	if cluster_exists; then
		local context_name
		context_name=$(get_context_for_cluster "${CLUSTER_NAME}")
		
		if [ -z "${context_name}" ]; then
			print_warning "Cluster '${CLUSTER_NAME}' exists but no kubectl context found"
			return 1
		fi
		
		print_success "Cluster '${CLUSTER_NAME}' is running"
		print_success "Context '${context_name}' available (current: $(kubectl config current-context 2>/dev/null || echo 'none'))"
		echo ""
		echo "Cluster info:"
		kubectl cluster-info --context "${context_name}" 2>/dev/null || true
		echo ""
		echo "Nodes:"
		kubectl get nodes --context "${context_name}" 2>/dev/null || true
	else
		print_warning "Cluster '${CLUSTER_NAME}' does not exist"
		echo ""
		echo "Run './tools/scripts/kind-cluster.sh create' to create a cluster"
	fi
}

function restart_cluster() {
	echo "Restarting kind cluster '${CLUSTER_NAME}'..."
	delete_cluster
	create_cluster
}

function rename_context() {
	local current_context
	current_context=$(kubectl config current-context 2>/dev/null)

	if [ -z "$current_context" ]; then
		print_error "No current context found"
		exit 1
	fi

	echo "Current context: ${current_context}"
	echo -n "Rename context to 'local-dev-cluster'? (yes/no): "
	read -r response

	if [ "$response" = "yes" ]; then
		kubectl config rename-context "$current_context" "local-dev-cluster"
		print_success "Context renamed from '${current_context}' to 'local-dev-cluster'"
		kubectl config use-context "local-dev-cluster"
		print_success "Switched to context 'local-dev-cluster'"
	else
		print_warning "Context rename cancelled"
	fi
}

function fix_connection() {
	if ! cluster_exists; then
		print_error "Cluster '${CLUSTER_NAME}' does not exist"
		exit 1
	fi
	
	local context_name
	context_name=$(get_context_for_cluster "${CLUSTER_NAME}")
	
	if [ -z "${context_name}" ]; then
		print_error "Could not find kubectl context for cluster '${CLUSTER_NAME}'"
		exit 1
	fi
	
	if is_in_devcontainer; then
		fix_devcontainer_connection "${context_name}"
		echo ""
		echo "Testing connection..."
		kubectl cluster-info --context "${context_name}" 2>/dev/null || true
	else
		print_warning "Not running in a dev container - no fix needed"
		print_success "Use context directly: kubectl --context ${context_name} get nodes"
	fi
}

function show_help() {
	cat <<EOF
Usage: $0 <command>

Commands:
    create          Create a new kind cluster
    delete          Delete the kind cluster
    restart         Restart the kind cluster (delete + create)
    status          Show cluster status
    fix-connection  Fix kubectl connection for dev container environments
    rename-context  Rename the current kubectl context to 'local-dev-cluster'
    help            Show this help message

Examples:
    $0 create       # Create the cluster
    $0 status       # Check if cluster is running
    $0 delete       # Remove the cluster

The cluster is configured with:
  - Single control-plane node (resource-efficient)
  - Port mappings: 8080->80, 8443->443
  - Resource constraints for limited environments

After creating the cluster:
  - kubectl is automatically configured
  - Context: ${CLUSTER_NAME}
  - Dev container environments are auto-detected and configured
  - Access services at localhost:8080 (HTTP) or localhost:8443 (HTTPS)

EOF
}

# Main script
case "${1:-help}" in
create)
	check_docker
	create_cluster
	;;
delete)
	check_docker
	delete_cluster
	;;
restart)
	check_docker
	restart_cluster
	;;
status)
	check_docker
	status_cluster
	;;
fix-connection)
	check_docker
	fix_connection
	;;
rename-context)
	rename_context
	;;
help | --help | -h)
	show_help
	;;
*)
	print_error "Unknown command: $1"
	echo ""
	show_help
	exit 1
	;;
esac
