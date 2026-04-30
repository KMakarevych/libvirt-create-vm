---
name: libvirt-vm
description: Create and manage Ubuntu virtual machines using libvirt/QEMU with cloud-init automation. Use when user wants to create VMs, destroy VMs, or manage virtual machines.
---

# libvirt-vm

Create and manage Ubuntu 24.04 VMs using libvirt/QEMU with cloud-init automation.

## Context

- Current VMs: !`virsh list --all 2>/dev/null || echo "libvirt not running"`
- Bridge interfaces: !`ip link show type bridge 2>/dev/null | grep -oP "^\d+:\s+\K[^:@]+" || echo "No bridges"`

## Script Source

**URL:** `https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh`

## Available Options

| Option | Description |
|--------|-------------|
| `--vmname NAME` | VM name (default: "vm") |
| `--user USERNAME` | Sudo user in VM (default: current user) |
| `--destroy` | Remove VM and associated disk |
| `--genpass` | Generate random password |
| `-h, --help` | Display help |

## Default VM Specs

- **Disk:** 30GB (RAW format)
- **RAM:** 8192 MB
- **vCPU:** 8 cores
- **Bridge:** br0
- **OS:** Ubuntu 24.04 Noble
- **Extras:** Docker pre-installed, QEMU Guest Agent enabled

## Commands

### Create VM
```bash
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname <name> --user <username>
```

### Create VM with Random Password
```bash
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname <name> --user <username> --genpass
```

### Destroy VM
```bash
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname <name> --destroy
```

### Check VM IP Address
```bash
virsh domifaddr <vmname>
```

### List All VMs
```bash
virsh list --all
```

## Instructions

When the user invokes this skill:

1. **For VM creation:** Ask for VM name and username if not provided, then execute the curl command
2. **For VM destruction:** Confirm the VM name, then execute with `--destroy` flag
3. **After creation:** Use `virsh domifaddr <vmname>` to retrieve and display the IP address
4. **For status checks:** Use `virsh list --all` or `virsh dominfo <vmname>`

## Requirements

Ensure the host has:
- Linux with KVM support
- libvirt, QEMU, virt-install installed
- Bridge interface `br0` configured
- `whois` package (for password generation)

Install command: `sudo apt install qemu-kvm libvirt-daemon-system virtinst bridge-utils whois`

## Storage

VM disks are stored in: `/var/lib/libvirt/images/`

## Notes

- The script has hardcoded SSH keys and password hashes - fork and modify for production use
- Ubuntu Cloud Image is automatically downloaded and cached for reuse
- Docker is automatically installed in the VM

---

## SSH Config Management (MANDATORY)

**CRITICAL:** After EVERY VM creation or destruction, you MUST manage SSH config aliases in `/home/gerero/ssh_config.d/my.conf`

### SSH Config File Location
```
/home/gerero/ssh_config.d/my.conf
```

### SSH Alias Template

When creating a VM, add this block to the END of `my.conf`:

```
Host gerero.<vmname>
  HostName <IP_ADDRESS>
  User <username>
  IdentitiesOnly yes
  IdentityFile "/home/gerero/ssh_config.d/pub/bastion.pub"
  StrictHostKeyChecking no

```

**Variables:**
- `<vmname>` - The VM name provided by user
- `<IP_ADDRESS>` - IP address obtained via `virsh domifaddr <vmname>` (wait up to 60 seconds for IP assignment)
- `<username>` - The username provided by user (same as used in VM creation)

### On VM Creation - Add SSH Alias

1. Execute the VM creation script
2. Wait for VM to start and get IP address:
   ```bash
   for i in {1..12}; do
     IP=$(virsh domifaddr <vmname> 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
     [ -n "$IP" ] && break
     sleep 5
   done
   ```
3. Read current `/home/gerero/ssh_config.d/my.conf`
4. Append the SSH alias block using the Edit tool
5. Display summary

### On VM Destruction - Remove SSH Alias

1. Read current `/home/gerero/ssh_config.d/my.conf`
2. Find and remove the entire Host block for `gerero.<vmname>` (from `Host gerero.<vmname>` line to the next empty line or next `Host` line)
3. Execute the VM destruction script
4. Display summary

---

## Summary Output (MANDATORY)

**CRITICAL:** After EVERY operation (create or destroy), you MUST display a formatted summary box.

### Summary Box Format

Use this exact format with Unicode box-drawing characters:

```
┌─────────────────────────────────────────────────────────────┐
│                    VM Operation Summary                      │
├─────────────────────────────────────────────────────────────┤
│  Action:      <CREATED|DESTROYED>                           │
│  VM Name:     <vmname>                                      │
│  IP Address:  <ip_address>                                  │
│  SSH Alias:   gerero.<vmname>                               │
│  User:        <username>                                    │
│  Config:      /home/gerero/ssh_config.d/my.conf             │
├─────────────────────────────────────────────────────────────┤
│  SSH Command: ssh gerero.<vmname>                           │
└─────────────────────────────────────────────────────────────┘
```

### For VM Creation:
```
┌─────────────────────────────────────────────────────────────┐
│                    VM Operation Summary                      │
├─────────────────────────────────────────────────────────────┤
│  Action:      CREATED                                       │
│  VM Name:     <vmname>                                      │
│  IP Address:  <ip_address>                                  │
│  SSH Alias:   gerero.<vmname> (ADDED)                       │
│  User:        <username>                                    │
│  Config:      /home/gerero/ssh_config.d/my.conf             │
├─────────────────────────────────────────────────────────────┤
│  SSH Command: ssh gerero.<vmname>                           │
└─────────────────────────────────────────────────────────────┘
```

### For VM Destruction:
```
┌─────────────────────────────────────────────────────────────┐
│                    VM Operation Summary                      │
├─────────────────────────────────────────────────────────────┤
│  Action:      DESTROYED                                     │
│  VM Name:     <vmname>                                      │
│  SSH Alias:   gerero.<vmname> (REMOVED)                     │
│  Config:      /home/gerero/ssh_config.d/my.conf             │
└─────────────────────────────────────────────────────────────┘
```

## Workflow Checklist

### VM Creation Workflow:
- [ ] Get VM name from user
- [ ] Get username from user
- [ ] Execute creation script
- [ ] Wait for IP address (up to 60 seconds)
- [ ] Read my.conf file
- [ ] Add SSH alias block to my.conf
- [ ] Display summary box

### VM Destruction Workflow:
- [ ] Get VM name from user
- [ ] Read my.conf file
- [ ] Remove SSH alias block from my.conf
- [ ] Execute destruction script
- [ ] Display summary box
