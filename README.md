# virsh_wakeonlan

`virsh_wakeonlan` is a small system service that listens for Wake-on-LAN (WoL) packets and starts the matching `libvirt` virtual machine through `virsh`.

When a WoL packet is received, the listener extracts the target MAC address, finds the VM that owns that MAC, and starts it.

## Requirements

- A Linux host with `systemd`
- `/usr/bin/python3` (`>= 3.8`)
- `virsh` / `libvirt`
- Root privileges for installation and removal
- Virtual machines already defined in `libvirt`
- Guest network interfaces configured with known MAC addresses

## Installation

Install the scripts and enable the systemd service:

```bash
sudo make install
```

## Firewall

If you are using `firewalld`, check which zone applies to the relevant interface, then open the WoL UDP ports on that zone:

```bash
sudo firewall-cmd --get-zone-of-interface=virbr1
sudo firewall-cmd --zone=<zone> --add-port=9/udp --permanent
sudo firewall-cmd --zone=<zone> --add-port=7/udp --permanent
sudo firewall-cmd --zone=<zone> --add-port=40000/udp --permanent
sudo firewall-cmd --reload
```

The listener listens on UDP ports `7`, `9`, and `40000`.

## Verification

Check that the service is installed and running:

```bash
sudo systemctl status virsh_wakeonlan.service
```

The listener logs every packet it receives, valid or not, and the outcome of each
VM start to the journal:

```bash
sudo journalctl -u virsh_wakeonlan.service
```

To also append the same messages to `/var/log/virsh_wakeonlan.log`, add a
`systemd` override:

```ini
[Service]
Environment=VIRSH_WAKEONLAN_LOG_ENABLED=1
```

```bash
sudo systemctl edit virsh_wakeonlan.service
sudo systemctl daemon-reload
sudo systemctl restart virsh_wakeonlan.service
```

Then send a Wake-on-LAN packet to the MAC address of a configured VM and confirm that the VM starts.

## Troubleshooting

**Nothing in the journal when a packet is sent from the host itself.** The packet
never reached the listener. A packet addressed to the broadcast address of a
libvirt network, such as `192.168.122.255`, is delivered locally only while the
bridge of that network exists; otherwise it follows the default route and leaves
the host. Check with:

```bash
ip route get 192.168.122.255   # expected: "broadcast ... dev virbr0", not "via <gateway>"
virsh net-list --all
```

The unit pulls in `virtnetworkd.service` so that networks set to autostart are
up at boot. A network without autostart has to be started by hand
(`virsh net-start <name>`) or set to autostart (`virsh net-autostart <name>`).

## Uninstall

Remove the installed files and disable the service:

```bash
sudo make uninstall
```
