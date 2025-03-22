#!/usr/bin/env bash

# inspired from: https://github.com/chaqchase/lla/blob/main/install.sh
# this script is for Linux / macOS
#
# use with command:
#
# ```bash
# curl -fsSL https://dria.co/launcher | bash
#
# # or the direct link
# curl -fsSL https://raw.githubusercontent.com/firstbatchxyz/dkn-compute-launcher/refs/heads/master/install.ps1 | bash
# ```

# exit on error
set -e

################# LOGGERS #################

NC='\033[0m' 
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}
print_success() {
    echo -e "${GREEN}==>${NC} $1"
}
print_error() {
    echo -e "${RED}==>${NC} $1"
}

################## LOGIC ##################

# detects the platform and returns the respective asset name
# e.g. dkn-compute-launcher-linux-amd64
#
# this can be used with version to obtain the download URL like:
# https://github.com/firstbatchxyz/dkn-compute-launcher/releases/download/v0.1.0/dkn-compute-launcher-linux-amd64
get_release_name() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)     OS="linux" ;;
        Darwin)    OS="macOS" ;;
        *)
            print_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        arm64)   ARCH="arm64" ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    RELEASE_NAME="dkn-compute-launcher-${OS}-${ARCH}"
}

get_latest_version() {
    LATEST_RELEASE_URL="https://api.github.com/repos/firstbatchxyz/dkn-compute-launcher/releases/latest"
    VERSION=$(curl -s $LATEST_RELEASE_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi
}

download_binary() {
    print_step "Downloading Dria Compute Launcher ${VERSION} for ${OS}-${ARCH}..."
    
    DOWNLOAD_URL="https://github.com/firstbatchxyz/dkn-compute-launcher/releases/download/${VERSION}/${RELEASE_NAME}"
    print_step "Downloading from $DOWNLOAD_URL"
    TMP_DIR=$(mktemp -d)
    curl -f -L "$DOWNLOAD_URL" -o "${TMP_DIR}/dkn-compute-launcher"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to download launcher"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    print_success "Downloaded launcher to ${TMP_DIR}"
}

install_binary() {
    print_step "Extracting binary to /usr/local/bin (will ask for password)"
    sudo mkdir -p /usr/local/bin
    sudo chmod +x "${TMP_DIR}/dkn-compute-launcher"
    sudo mv "${TMP_DIR}/dkn-compute-launcher" /usr/local/bin/
    rm -rf "$TMP_DIR"
}

run_node_for_wallet() {
    local wallet_id=$1
    local private_key=$2
    print_step "Running node for wallet $wallet_id with private key $private_key"
    # Run the node with the provided private key (customize this command as needed)
    dkn-compute-launcher start --private-key "$private_key" --wallet-id "$wallet_id" &
}

main() {
    print_step "Installing Dria Compute Launcher to $(pwd)"
    
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    get_release_name
    get_latest_version
    download_binary
    install_binary

    print_success "DKN Compute Launcher ${VERSION} has been installed successfully!"
    
    # Ask the user for the number of wallets to run nodes with
    read -p "How many wallets do you want to run nodes for? " num_wallets
    if ! [[ "$num_wallets" =~ ^[0-9]+$ ]] || [ "$num_wallets" -le 0 ]; then
        print_error "Invalid number of wallets"
        exit 1
    fi
    
    # Loop over the number of wallets and ask for the private key for each wallet
    for ((i = 1; i <= num_wallets; i++)); do
        read -p "Enter the private key for wallet $i: " private_key
        run_node_for_wallet "$i" "$private_key"
    done
    
    # Inform the user that the nodes are running in the background
    print_success "Nodes for $num_wallets wallets are now running in the background."
}

main
