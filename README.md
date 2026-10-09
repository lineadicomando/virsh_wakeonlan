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

The listener listens on UDP ports `7`, `9`, and `40000`. With `firewalld`, they
have to be open in the zone of the interface the packets arrive on: for a packet
sent from the host itself, the bridge of the libvirt network (`virbr0` for the
`default` network, see `virsh net-info <name>`).

Check which zone the bridge is in:

```bash
sudo firewall-cmd --get-zone-of-interface=virbr0
```

libvirt puts its bridges in the `libvirt` zone when it starts a network, but that
binding is a runtime one and can be missing after a boot. `no zone` means the
bridge falls back to the default zone, where the ports opened in `libvirt` do
not apply: `FedoraWorkstation`, for instance, rejects everything below 1025, so
ports `7` and `9` are closed. Bind the bridge to the zone permanently:

```bash
sudo firewall-cmd --permanent --zone=libvirt --add-interface=virbr0
```

Then open the ports in that zone and load the permanent configuration:

```bash
sudo firewall-cmd --permanent --zone=libvirt --add-port=7/udp
sudo firewall-cmd --permanent --zone=libvirt --add-port=9/udp
sudo firewall-cmd --permanent --zone=libvirt --add-port=40000/udp
sudo firewall-cmd --reload
```

Without `--permanent` a change lasts until the next reload or reboot. Check the
result, which has to list the bridge and the three ports:

```bash
sudo firewall-cmd --permanent --zone=libvirt --list-all
sudo firewall-cmd --get-zone-of-interface=virbr0   # expected: libvirt
```

Packets that come from another machine arrive on the physical interface instead:
open the same ports in its zone.

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

**Nothing in the journal although the route is right.** The firewall dropped the
packet: the bridge is not in the zone where the ports are open. See
[Firewall](#firewall). The same condition keeps the guests from reaching the DNS
of the libvirt network, so name resolution failing inside the VMs after a host
reboot points here too.

```bash
sudo firewall-cmd --get-zone-of-interface=virbr0   # "no zone" is the problem
```

## Uninstall

Remove the installed files and disable the service:

```bash
sudo make uninstall
```
