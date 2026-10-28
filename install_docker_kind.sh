#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
INFO='\033[0;34m'

echo -e "${INFO}Starting WSL Environment Verification...${NC}"

# --- Step 1: Check Internet Connection via HTTPS ---
TARGET_URL="https://connectivitycheck.gstatic.com/generate_204"

echo -e "${INFO}Checking internet access via HTTPS...${NC}"

# Install curl first if not present (using native Ubuntu repo)
if ! command -v curl &> /dev/null; then
    echo -e "${INFO}curl is not installed. Installing curl from Ubuntu repositories...${NC}"
    sudo apt-get update -y && sudo apt-get install -y curl
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TARGET_URL" || true)

if [ "$HTTP_STATUS" -eq 204 ]; then
    echo -e "${GREEN}✔ HTTPS Internet connection successful!${NC}"
else
    echo -e "${RED}✘ HTTPS Connection failed (HTTP Status: $HTTP_STATUS or timeout).${NC}"
    echo -e "${RED}Please check your corporate proxy or network settings.${NC}"
    exit 1
fi

# --- Step 2: Install Kubectl via Manual Binary Download ---
if ! command -v kubectl &> /dev/null; then
    echo -e "${INFO}kubectl is not present. Starting manual installation...${NC}"
    
    # 1. Determine CPU Architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        KUBE_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        KUBE_ARCH="arm64"
    else
        echo -e "${RED}Unsupported system architecture: $ARCH${NC}"
        exit 1
    fi

    # 2. Get the latest stable Kubernetes version
    echo -e "${INFO}Resolving the latest stable kubectl version...${NC}"
    LATEST_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

    # 3. Download the binary
    echo -e "${INFO}Downloading kubectl binary ($LATEST_VERSION) for $KUBE_ARCH...${NC}"
    curl -LO "https://dl.k8s.io/release/${LATEST_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"

    # 4. Make executable and move to local path
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl

    echo -e "${GREEN}✔ kubectl installed successfully! (Version: $(kubectl version --client --output=yaml | grep gitVersion | head -n 1 | awk '{print $2}'))${NC}"
else
    echo -e "${GREEN}✔ kubectl is already installed.${NC}"
fi

# --- Step 3: Install Kind via Native Ubuntu Repositories ---
if ! command -v kind &> /dev/null; then
    echo -e "${INFO}Installing Kind from native Ubuntu repositories...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y kind
    echo -e "${GREEN}✔ Kind installed successfully!${NC}"
else
    echo -e "${GREEN}✔ Kind is already installed.${NC}"
fi

# --- Step 4: Install Docker via Native Ubuntu Repositories ---
if ! command -v docker &> /dev/null; then
    echo -e "${INFO}Installing Docker from native Ubuntu repositories...${NC}"
    sudo apt-get update -y
    
    # In Ubuntu repos, the Docker engine package is named 'docker.io'
    sudo apt-get install -y docker.io

    # Enable Docker service so it can be managed by systemd
    sudo systemctl enable docker

    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    echo -e "${GREEN}✔ Docker installed successfully!${NC}"
else
    echo -e "${GREEN}✔ Docker is already installed.${NC}"
fi

# --- Step 5: Configure Docker Daemon Proxy Settings conditionally ---
PROXY_CONF_FILE="/etc/systemd/system/docker.service.d/http-proxy.conf"
PROXY_CHANGED=false

if [ -f "$PROXY_CONF_FILE" ]; then
    echo -e "${GREEN}✔ Docker daemon proxy settings already exist in $PROXY_CONF_FILE. Skipping configuration.${NC}"
else
    echo -e "${INFO}No existing Docker daemon proxy configuration found. Checking user environment variables...${NC}"

    # Resolve proxy values from user's current environment (checks both upper and lower case)
    RESOLVED_HTTP_PROXY="${HTTP_PROXY:-$http_proxy}"
    RESOLVED_HTTPS_PROXY="${HTTPS_PROXY:-$https_proxy}"
    RESOLVED_NO_PROXY="${NO_PROXY:-$no_proxy}"

    if [ -n "$RESOLVED_HTTP_PROXY" ] || [ -n "$RESOLVED_HTTPS_PROXY" ]; then
        echo -e "${INFO}Proxy settings detected in user environment. Writing systemd override for Docker...${NC}"
        
        # Create systemd drop-in directory for docker service overrides
        sudo mkdir -p /etc/systemd/system/docker.service.d

        # Generate the http-proxy.conf drop-in file
        sudo tee "$PROXY_CONF_FILE" > /dev/null <<EOF
[Service]
EOF

        if [ -n "$RESOLVED_HTTP_PROXY" ]; then
            echo "Environment=\"HTTP_PROXY=$RESOLVED_HTTP_PROXY\"" | sudo tee -a "$PROXY_CONF_FILE" > /dev/null
            echo -e "-> Configured HTTP_PROXY: ${RESOLVED_HTTP_PROXY}"
        fi

        if [ -n "$RESOLVED_HTTPS_PROXY" ]; then
            echo "Environment=\"HTTPS_PROXY=$RESOLVED_HTTPS_PROXY\"" | sudo tee -a "$PROXY_CONF_FILE" > /dev/null
            echo -e "-> Configured HTTPS_PROXY: ${RESOLVED_HTTPS_PROXY}"
        fi

        if [ -n "$RESOLVED_NO_PROXY" ]; then
            echo "Environment=\"NO_PROXY=$RESOLVED_NO_PROXY\"" | sudo tee -a "$PROXY_CONF_FILE" > /dev/null
            echo -e "-> Configured NO_PROXY: ${RESOLVED_NO_PROXY}"
        fi

        PROXY_CHANGED=true
    else
        echo -e "${INFO}No active proxy environment variables found. Skipping Docker proxy configuration.${NC}"
    fi
fi

# --- Step 6: Start or Restart Docker and Verify Pull Access ---
echo -e "${INFO}Verifying Docker daemon status and Docker Hub image pulling...${NC}"

if [ "$PROXY_CHANGED" = true ]; then
    echo -e "${INFO}Proxy settings were changed. Reloading systemd daemon and restarting Docker service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl restart docker
else
    # Just ensure Docker is started if we didn't touch the systemd configuration
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${INFO}Docker is not active. Starting Docker service...${NC}"
        sudo systemctl start docker
    else
        echo -e "${GREEN}✔ Docker is already active. No restart required.${NC}"
    fi
fi

# Test pulling a minimal image (alpine) from Docker Hub
echo -e "${INFO}Testing pull access from Docker Hub (pulling 'alpine:latest')...${NC}"
if sudo docker pull alpine:latest > /dev/null 2>&1; then
    echo -e "${GREEN}✔ Docker Hub image pull test successful!${NC}"
else
    echo -e "${RED}✘ Docker Hub pull failed!${NC}"
    echo -e "${RED}If you are on a restricted corporate network, check your proxy settings or DNS config.${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Verification, Installation, and Pull tests completed successfully using native Ubuntu packages!${NC}"
echo -e "${INFO}You are ready to manage your Kubernetes cluster! Try: kind create cluster${NC}"

