#!/bin/bash

set -e  # Exit on any error

# Ask if this is an untrusted device
read -r -p "Is this an untrusted device? (y/N): " untrusted

if [[ "$untrusted" =~ ^[Yy]$ ]]; then
    echo "Creating preauth key for untrusted device..."
    docker exec headscale headscale preauthkeys create --tags tag:untrusted
    exit 0
fi

# Prompt for username
read -r -p "Enter the username: " username

# Validate inputs
if [ -z "$username" ]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

# Check if the user exists
if ! docker exec headscale headscale user list | grep -q "${username}"; then
    echo "Error: User does not exist"
    exit 1
fi

# Get user ID
user_id=$(docker exec headscale headscale users list | grep "${username}" | awk '{print $1}' | sed 's/\x1b\[[0-9;]*m//g')

# Create a preauth key for the user
echo "Creating preauth key..."
docker exec headscale headscale preauthkeys create --user "${user_id}"
