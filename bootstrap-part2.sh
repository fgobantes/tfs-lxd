#!/bin/bash
set -e

echo "=== TeraFlow SDN Setup - Part 2 ==="

# Read devspace mode from part 1
DEVSPACE_MODE="no"
if [[ -f "/home/tfsuser/.devspace_mode" ]]; then
    DEVSPACE_MODE=$(cat /home/tfsuser/.devspace_mode)
fi

# Check what steps are already complete
MICROK8S_READY=false
ADDONS_ENABLED=false
REPOS_CLONED=false
DEPLOYMENT_COMPLETE=false

# Check if MicroK8s is ready
if microk8s.status --wait-ready --timeout 30 >/dev/null 2>&1 && [ -f "$HOME/.kube/config" ]; then
    MICROK8S_READY=true
    echo "[INFO] MicroK8s already ready, skipping step 1"
fi

# Check if addons are enabled
if $MICROK8S_READY && kubectl get pods -n container-registry | grep -q "registry" >/dev/null 2>&1; then
    ADDONS_ENABLED=true
    echo "[INFO] MicroK8s addons already enabled, skipping step 2"
fi

# Check if repositories are cloned
if [ -d "$HOME/controller" ] && [ -d "$HOME/MINDFulTeraFlowSDN.jl" ]; then
    REPOS_CLONED=true
    echo "[INFO] Repositories already cloned, skipping step 3"
fi

# Check if TeraFlow is already deployed and running
if $MICROK8S_READY; then
    echo "[INFO] Checking TeraFlow deployment status..."
    
    # Check if tfs namespace exists and main services are running
    if kubectl get namespace tfs >/dev/null 2>&1; then
        echo "[INFO] TFS namespace found, checking main services..."
        
        # Check only main services: deviceservice, nbiservice, webuiservice
        MAIN_SERVICES=("deviceservice" "nbiservice" "webuiservice")
        RUNNING_SERVICES=0
        
        for service in "${MAIN_SERVICES[@]}"; do
            # Check if pod exists and is actually Running
            POD_STATUS=$(kubectl get pods -n tfs -l app="$service" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
            
            if [[ "$POD_STATUS" == "Running" ]]; then
                echo "[INFO] $service is running"
                RUNNING_SERVICES=$((RUNNING_SERVICES + 1))
            else
                echo "[INFO] $service is not running (status: $POD_STATUS)"
            fi
        done
        
        # If all main services are running, mark deployment as complete
        if [[ $RUNNING_SERVICES -eq ${#MAIN_SERVICES[@]} ]]; then
            DEPLOYMENT_COMPLETE=true
            echo "[INFO] TeraFlow main services already running - deployment complete!"
            
            # Show current status
            echo ""
            kubectl get pods -n tfs
            echo ""
        else
            echo "[INFO] TeraFlow deployment needed - main services not all running ($RUNNING_SERVICES/${#MAIN_SERVICES[@]})"
        fi
    else
        echo "[INFO] TFS namespace not found, deployment needed"
    fi
else
    echo "[INFO] MicroK8s not ready, cannot check TeraFlow deployment"
fi

# Step 1: MicroK8s setup
if [ "$MICROK8S_READY" = false ]; then
    echo "[1/4] Wait for MicroK8s to be ready"
    microk8s.status --wait-ready
    microk8s config > $HOME/.kube/config
else
    echo "[1/4] MicroK8s already ready ✓"
fi

# Step 2: Enable addons
if [ "$ADDONS_ENABLED" = false ]; then
    echo "[2/4] Enable MicroK8s addons"
    # Enable community first
    microk8s.enable community || (git config --global --add safe.directory /snap/microk8s/current/addons/community/.git && microk8s.enable community)

    # Enable mandatory addons
    microk8s.enable dns
    microk8s.enable hostpath-storage
    microk8s.enable ingress
    microk8s.enable registry

    # Enable production addons
    microk8s.enable prometheus
    microk8s.enable metrics-server
    microk8s.enable linkerd

    # Create linkerd alias
    sudo snap alias microk8s.linkerd linkerd || true

    echo "Waiting for all addons to be ready..."
    sleep 30
else
    echo "[2/4] MicroK8s addons already enabled ✓"
fi

# Step 3: Clone repositories
if [ "$REPOS_CLONED" = false ]; then
    echo "[3/4] Clone repositories"
    cd $HOME
    if [ ! -d "controller" ]; then
        git clone https://labs.etsi.org/rep/tfs/controller.git
    fi

    if [ ! -d "MINDFulTeraFlowSDN.jl" ]; then
        git clone https://github.com/UniStuttgart-IKR/MINDFulTeraFlowSDN.jl
    fi
else
    echo "[3/4] Repositories already cloned ✓"
fi

# Step 4: Prepare and deploy TeraFlow (only if not already deployed)
if [ "$DEPLOYMENT_COMPLETE" = false ]; then
    echo "[4/4] Prepare and deploy TeraFlow"
    cd $HOME/MINDFulTeraFlowSDN.jl/deploy-tfs

    echo "Configuring deployment..."
    if [ ! -f "my_deploy.sh.backup" ]; then
        cp my_deploy.sh my_deploy.sh.backup
    fi

    # Update controller folder path
    sed -i 's|^export CONTROLLER_FOLDER=.*|export CONTROLLER_FOLDER="/home/tfsuser/controller"|g' my_deploy.sh

    # Set devspace mode
    if [[ "$DEVSPACE_MODE" == "yes" ]]; then
        sed -i 's|^export TFS_DEV_MODE=.*|export TFS_DEV_MODE="YES"|g' my_deploy.sh
        if ! grep -q "DEVSPACE_CONFIG" my_deploy.sh; then
            echo 'export DEVSPACE_CONFIG="/home/tfsuser/MINDFulTeraFlowSDN.jl/deploy-tfs/devspace.yaml"' >> my_deploy.sh
        fi
    else
        sed -i 's|^export TFS_DEV_MODE=.*|export TFS_DEV_MODE=""|g' my_deploy.sh
    fi

    echo "Sourcing deployment configuration..."
    source my_deploy.sh

    echo "Starting TeraFlow deployment..."
    ./deploy/all.sh
    
    echo ""
    echo "Waiting for deployment to stabilize..."
    sleep 30
    
    echo "Final deployment status:"
    kubectl get pods -n tfs
else
    echo "[4/4] TeraFlow already deployed ✓"
fi

# Cleanup
rm -f /home/tfsuser/.devspace_mode

echo "=== Deployment Complete ==="
echo 
echo "Use 'microk8s.status' to check cluster status"
echo "Use 'kubectl get all --all-namespaces' to check all resources"