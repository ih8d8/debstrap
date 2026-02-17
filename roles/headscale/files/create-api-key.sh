#!/bin/bash

# Prompt for username and key
read -r -p "Enter human-readable expiration of the key (e.g. 30m, 24h) (default \"90d\"): " expiration


# Validate inputs
if [ -z "$expiration" ]; then
    echo "Error: expiration cannot be empty"
    exit 1
fi

# Create an API key
echo "Creating API key..."
docker exec headscale headscale apikeys create --expiration "${expiration}"

# List API keys
echo "Listing API keys..."
docker exec headscale headscale apikeys list