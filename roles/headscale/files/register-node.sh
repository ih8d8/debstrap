#!/bin/bash

set -e  # Exit on any error

# Prompt for username and key
read -r -p "Enter the username: " username
read -r -p "Enter the key: " key
read -r -p "Enter the node name: " node_name

# Validate inputs
if [ -z "$username" ] || [ -z "$key" ]; then
    echo "Error: Username and key cannot be empty"
    exit 1
fi

# Check if the user exists
if ! docker exec headscale headscale user list | grep -q "${username}"; then
    echo "Error: User does not exist"
    exit 1
fi

# Register the user's node with the key
echo "Registering node..."
docker exec headscale headscale nodes register --user "${username}" --key "${key}"

# Get the node's ID and strip ANSI color codes
node_id=$(docker exec headscale headscale nodes list | awk 'NF {last=$1} END {print last}' |  sed 's/\x1b\[[0-9;]*m//g')

# Validate node_id
if [ -z "$node_id" ]; then
    echo "Error: Could not retrieve node ID"
    exit 1
fi

if ! [[ "$node_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid node ID retrieved: $node_id"
    exit 1
fi

# Change the node's name using the extracted node_id
echo "Renaming node..."
docker exec headscale headscale nodes rename "${node_name}" -i "${node_id}"

# List the nodes to confirm changes
echo -e "\nCurrent nodes:"
docker exec headscale headscale nodes list