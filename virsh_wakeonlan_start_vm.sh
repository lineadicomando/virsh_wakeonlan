#!/bin/bash

# Function to print script usage
usage() {
    echo "Usage: $0 <MAC_ADDRESS>"
    exit 1
}

# Function to validate a MAC address
validate_mac() {
    local mac_regex="^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
    if [[ "$1" =~ $mac_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Parse arguments
MAC_ADDRESS=""

for arg in "$@"; do
    if [[ "$arg" =~ ^- ]]; then
        # Ignore options starting with "-" or "--"
        continue
    elif validate_mac "$arg"; then
        MAC_ADDRESS="$arg"
        break
    fi
done

# Check if a valid MAC was found
if [[ -z "$MAC_ADDRESS" ]]; then
    echo "Error: no valid MAC address provided."
    usage
fi

# Search for the VM associated with the MAC address
VM_NAME=$(virsh list --all --name | while read -r vm; do
    if virsh domiflist "$vm" | grep -i "$MAC_ADDRESS" &>/dev/null; then
        echo "$vm"
        break
    fi
done)

# Output result
if [[ -n "$VM_NAME" ]]; then
    echo "Starting VM: $VM_NAME"
    virsh start "$VM_NAME"
else
    echo "No VM found with MAC address $MAC_ADDRESS"
    exit 1
fi
