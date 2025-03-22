#!/bin/bash

# Step 1: Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.com/download/linux | bash
ollama --version
if [ $? -ne 0 ]; then
    echo "Ollama installation failed"
    exit 1
fi
echo "Ollama installed successfully."

# Step 2: Install Dria Compute Launcher
echo "Installing Dria Compute Launcher..."
curl -fsSL https://dria.co/launcher | bash
if [ $? -ne 0 ]; then
    echo "Dria Compute Launcher installation failed"
    exit 1
fi
echo "Dria Compute Launcher installed successfully."

# Step 3: Create directories for profiles
echo "Creating directories for node profiles..."
PROFILE_1_DIR="$HOME/node_profiles/profile_1"
PROFILE_2_DIR="$HOME/node_profiles/profile_2"
PROFILE_3_DIR="$HOME/node_profiles/profile_3"

mkdir -p "$PROFILE_1_DIR" "$PROFILE_2_DIR" "$PROFILE_3_DIR"

# Step 4: Create systemd service for each node profile
create_systemd_service() {
    local profile_dir=$1
    local profile_name=$2
    local private_key=$3
    local service_name="node_${profile_name}.service"
    
    # Create the systemd service file
    echo "Creating systemd service for $profile_name..."
    sudo bash -c "cat > /etc/systemd/system/$service_name <<EOF
[Unit]
Description=Node for $profile_name
After=network.target

[Service]
ExecStart=/usr/local/bin/dkn-compute-launcher start --private-key $private_key --profile-dir $profile_dir
WorkingDirectory=$profile_dir
Restart=always
User=$USER
Environment=HOME=$HOME
Environment=USER=$USER

[Install]
WantedBy=multi-user.target
EOF"

    # Enable the service to start on boot
    sudo systemctl daemon-reload
    sudo systemctl enable $service_name
    echo "$profile_name service created and enabled to start on boot."
}

# Step 5: Start the nodes with user input for private keys
echo "Enter the private keys (without 0x prefix) for each profile."

# Profile 1
read -p "Enter private key for Profile 1: " PRIVATE_KEY_1
create_systemd_service "$PROFILE_1_DIR" "Profile_1" "$PRIVATE_KEY_1"

# Profile 2
read -p "Enter private key for Profile 2: " PRIVATE_KEY_2
create_systemd_service "$PROFILE_2_DIR" "Profile_2" "$PRIVATE_KEY_2"

# Profile 3
read -p "Enter private key for Profile 3: " PRIVATE_KEY_3
create_systemd_service "$PROFILE_3_DIR" "Profile_3" "$PRIVATE_KEY_3"

# Step 6: Start nodes immediately (if you don't want to reboot)
echo "Starting nodes immediately..."
sudo systemctl start node_Profile_1.service
sudo systemctl start node_Profile_2.service
sudo systemctl start node_Profile_3.service

echo "All nodes are running in separate profiles. They will restart automatically after a reboot."

# Step 7: Check the status of the services
echo "Checking status of all nodes..."
sudo systemctl status node_Profile_1.service
sudo systemctl status node_Profile_2.service
sudo systemctl status node_Profile_3.service

echo "Setup complete! Your nodes will start automatically after a reboot."
