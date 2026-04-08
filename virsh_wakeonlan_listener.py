#!/usr/bin/python3
import logging
import os
import select
import socket
import subprocess

# Logging configuration
LOG_FILE = "/var/log/virsh_wakeonlan.log"
LOG_ENABLED_VALUES = {"1", "true", "yes", "on"}
log_enabled = (
    os.getenv("VIRSH_WAKEONLAN_LOG_ENABLED", "").strip().lower()
    in LOG_ENABLED_VALUES
)

if log_enabled:
    logging.basicConfig(
        filename=LOG_FILE,
        filemode="a",
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
else:
    logging.getLogger().addHandler(logging.NullHandler())

# Standard Wake-on-LAN ports
PORTS = [9, 7, 40000]

# Script to execute
SCRIPT_PATH = "/usr/local/bin/virsh_wakeonlan_start_vm.sh"

# Create UDP sockets for each port
sockets = []
for port in PORTS:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", port))
    sockets.append(sock)
    logging.info("Listening on port %d for Wake-on-LAN packets...", port)

try:
    while True:
        readable_sockets, _, _ = select.select(sockets, [], [])
        for sock in readable_sockets:
            data, addr = sock.recvfrom(1024)  # Receive WoL packet
            if len(data) >= 102 and data[:6] == b"\xff" * 6:
                raw_mac = data[6:12]
                expected_payload = raw_mac * 16
                if data[6:102] != expected_payload:
                    logging.warning(
                        "Invalid WoL packet structure received from %s on port %d",
                        addr,
                        sock.getsockname()[1],
                    )
                    continue

                raw_mac = data[6:12]  # MAC address is in bytes 6-12
                mac_address = ":".join(format(x, "02x") for x in raw_mac)
                port = sock.getsockname()[1]
                logging.info(
                    "Received WoL packet from %s for MAC %s on port %d",
                    addr,
                    mac_address,
                    port,
                )

                # Execute the bash script with the received MAC address
                try:
                    subprocess.run([SCRIPT_PATH, mac_address], check=True)
                    logging.info(
                        "Executed script for MAC %s on port %d", mac_address, port
                    )
                except subprocess.CalledProcessError as e:
                    logging.error(
                        "Error executing script for MAC %s on port %d: %s",
                        mac_address,
                        port,
                        e,
                    )
            else:
                logging.warning(
                    "Invalid WoL packet received from %s on port %d",
                    addr,
                    sock.getsockname()[1],
                )
except KeyboardInterrupt:
    logging.info("Shutting down WoL listener.")
finally:
    for sock in sockets:
        sock.close()
