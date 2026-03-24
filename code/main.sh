#!/bin/bash

# ==========================================================
# Linux Network Namespace Simulation Script
# Author: SysGopher
# ==========================================================

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: Please run this script with sudo."
   exit 1
fi

function cleanup {
    echo "---------------------------------------"
    echo "Cleaning up existing namespaces and bridges..."
    ip netns del ns1 2>/dev/null
    ip netns del ns2 2>/dev/null
    ip netns del router-ns 2>/dev/null
    ip link del br0 2>/dev/null
    ip link del br1 2>/dev/null
    echo "Cleanup complete. Environment is now fresh."
    echo "---------------------------------------"
}

function setup {
    echo "Starting Network Simulation Setup..."

    # 1. Create Network Bridges
    ip link add br0 type bridge
    ip link add br1 type bridge
    ip link set br0 up
    ip link set br1 up
    echo "[✓] Bridges br0 and br1 created and activated."

    # 2. Create Network Namespaces
    ip netns add ns1
    ip netns add ns2
    ip netns add router-ns
    echo "[✓] Namespaces ns1, ns2, and router-ns created."

    # 3. Create Virtual Interfaces and Connections
    # Connect ns1 to br0
    ip link add veth-ns1 type veth peer name veth-br0
    ip link set veth-ns1 netns ns1
    ip link set veth-br0 master br0
    ip link set veth-br0 up

    # Connect ns2 to br1
    ip link add veth-ns2 type veth peer name veth-br1
    ip link set veth-ns2 netns ns2
    ip link set veth-br1 master br1
    ip link set veth-br1 up

    # Connect router-ns to br0
    ip link add veth-r0 type veth peer name veth-br0-r
    ip link set veth-r0 netns router-ns
    ip link set veth-br0-r master br0
    ip link set veth-br0-r up

    # Connect router-ns to br1
    ip link add veth-r1 type veth peer name veth-br1-r
    ip link set veth-r1 netns router-ns
    ip link set veth-br1-r master br1
    ip link set veth-br1-r up
    echo "[✓] Veth pairs created and connected to bridges."

    # 4. Configure IP Addresses
    # ns1 (Subnet 192.168.1.0/24)
    ip netns exec ns1 ip addr add 192.168.1.2/24 dev veth-ns1
    ip netns exec ns1 ip link set veth-ns1 up
    ip netns exec ns1 ip link set lo up

    # ns2 (Subnet 192.168.2.0/24)
    ip netns exec ns2 ip addr add 192.168.2.2/24 dev veth-ns2
    ip netns exec ns2 ip link set veth-ns2 up
    ip netns exec ns2 ip link set lo up

    # router-ns (Connected to both subnets)
    ip netns exec router-ns ip addr add 192.168.1.1/24 dev veth-r0
    ip netns exec router-ns ip addr add 192.168.2.1/24 dev veth-r1
    ip netns exec router-ns ip link set veth-r0 up
    ip netns exec router-ns ip link set veth-r1 up
    ip netns exec router-ns ip link set lo up
    echo "[✓] IP addresses assigned to all interfaces."

    # 5. Set Up Routing and IP Forwarding
    # Enable IP forwarding inside router-ns
    ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Establish default routes for ns1 and ns2
    ip netns exec ns1 ip route add default via 192.168.1.1
    ip netns exec ns2 ip route add default via 192.168.2.1
    echo "[✓] Routing and IP forwarding configured."

    echo "---------------------------------------"
    echo "Setup finished successfully."
    echo "---------------------------------------"
}

function test_connectivity {
    echo "Testing connectivity from ns1 (192.168.1.2) to ns2 (192.168.2.2)..."
    ip netns exec ns1 ping -c 3 192.168.2.2
}

case "$1" in
    setup) setup ;;
    cleanup) cleanup ;;
    test) test_connectivity ;;
    *) echo "Usage: sudo $0 {setup|cleanup|test}" ;;
esac