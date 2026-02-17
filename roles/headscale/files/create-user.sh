#!/bin/bash

set -e  # Exit on any error

# Prompt for username
read -r -p "Enter the username: " username

# Validate the input
if [ -z "$username" ]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

# Create a new user in headscale
echo "Creating user..."
docker exec headscale headscale user create "${username}"
