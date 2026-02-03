#!/bin/bash
set -e

# === Default Configuration ===
DEFAULT_VM_NAME="vm"
DEFAULT_USER=$(whoami)
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
BASE_IMAGE_QCOW2="/home/gerero/qemu/noble-server-cloudimg-amd64.img"
DISK_SIZE="30G"
RAM_MB=8192
VCPUS=8
BRIDGE_IF="br0"

SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE72b3XfwOpPH8b+FeihMFh8MO2XU1zqIus9OMafmy6k"
PASSWORD_HASH='$6$AuP2kZBsrrkwKTVM$l.ltNV/gE6ODlwXRs/k4ABTMMFKGiHy8EETL0kz8TcTxuAvSlMyFKFNU5jX0QCCvkuRNt/E.LEeoJl0Yvb1dR1' # Hash for 1234

# === Help Function ===
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  --vmname NAME        Set VM name (default: $DEFAULT_VM_NAME)"
    echo "  --user USERNAME      Set sudo user in VM (default: $DEFAULT_USER)"
    echo "  --destroy            Destroy the specified VM and delete its storage"
    echo "  --genpass            Generate a random password and hash it for cloud-init"
    echo ""
    echo "Examples:"
    echo "  $0 --vmname node-01 --user admin --genpass"
    echo "  $0 --vmname node-01 --destroy"
    exit 0
}

# === Argument Parsing ===
VM_NAME=$DEFAULT_VM_NAME
VM_USER=$DEFAULT_USER
DESTROY_MODE=false
GENERATE_PASS=false

PARSED_ARGS=$(getopt -n "$0" -o "h" -l "help,vmname:,user:,destroy,genpass" -- "$@")
eval set -- "$PARSED_ARGS"

while true; do
    case "$1" in
        -h|--help) usage ;;
        --vmname) VM_NAME="$2"; shift 2 ;;
        --user) VM_USER="$2"; shift 2 ;;
        --destroy) DESTROY_MODE=true; shift ;;
        --genpass) GENERATE_PASS=true; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

# Derived path
DISK_IMAGE="/var/lib/libvirt/images/${VM_NAME}.raw"

# === Logic: Destroy Mode ===
if [ "$DESTROY_MODE" = true ]; then
    echo "[!] Target VM: $VM_NAME"
    if sudo virsh list --all | grep -q " $VM_NAME "; then
        echo "[!] Destroying and removing $VM_NAME..."
        sudo virsh destroy "$VM_NAME" 2>/dev/null || true
        sudo virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
        echo "[✓] VM and storage deleted successfully."
    else
        echo "[!] VM '$VM_NAME' not found. Nothing to destroy."
    fi
    exit 0
fi

# === Logic: Password Generation ===
if [ "$GENERATE_PASS" = true ]; then
    if ! command -v mkpasswd &> /dev/null; then
        echo "[!] Error: 'mkpasswd' not found. Install it via 'sudo apt install whois'."
        exit 1
    fi
    RAW_PASS=$(openssl rand -base64 12)
    PASSWORD_HASH=$(mkpasswd -m sha-512 "$RAW_PASS")
    echo "------------------------------------------"
    echo "GENERATED PASSWORD FOR USER '$VM_USER':"
    echo "Password: $RAW_PASS"
    echo "------------------------------------------"
fi

# === Temporary Files (Cloud-Init) ===
USERDATA_TMP=$(mktemp /tmp/user-data.XXXXXX)
METADATA_TMP=$(mktemp /tmp/meta-data.XXXXXX)
trap 'rm -f "$USERDATA_TMP" "$METADATA_TMP"' EXIT

# === Generate Cloud-Init Data ===
cat <<EOF > "$USERDATA_TMP"
#cloud-config
hostname: ${VM_NAME}
users:
  - name: ${VM_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh-authorized-keys:
      - ${SSH_KEY}
    passwd: ${PASSWORD_HASH}
    lock_passwd: false
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
  - curl https://get.docker.com | sh -
  - systemctl enable --now docker
  - usermod -aG docker ${VM_USER}
  - echo "Welcome to ${VM_NAME}, ${VM_USER}!" > /etc/motd
EOF

cat <<EOF > "$METADATA_TMP"
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

# === Prepare Base Image ===
if [ ! -f "$BASE_IMAGE_QCOW2" ]; then
    echo "[+] Downloading Ubuntu cloud image..."
    wget -O "$BASE_IMAGE_QCOW2" "$IMAGE_URL"
fi

# === Create RAW Disk ===
if [ ! -f "$DISK_IMAGE" ]; then
    echo "[+] Creating RAW disk for $VM_NAME..."
    sudo qemu-img convert -f qcow2 -O raw "$BASE_IMAGE_QCOW2" "$DISK_IMAGE"
    sudo qemu-img resize -f raw "$DISK_IMAGE" "$DISK_SIZE"
else
    echo "[!] Disk image already exists: $DISK_IMAGE"
    echo "[!] Use --destroy first if you want to recreate it."
    exit 1
fi

# === Provision VM ===
echo "[+] Provisioning VM: $VM_NAME (User: $VM_USER)..."
sudo virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --os-variant ubuntu24.04 \
  --import \
  --disk path="$DISK_IMAGE",format=raw,bus=virtio,cache=none,io=native \
  --network bridge="$BRIDGE_IF",model=virtio \
  --graphics none \
  --noautoconsole \
  --cloud-init user-data="$USERDATA_TMP",meta-data="$METADATA_TMP"

echo "[✓] VM '$VM_NAME' created successfully."

# === Fetch IP Address ===
echo "[i] Waiting for QEMU Guest Agent to report IP..."
for i in {1..15}; do
    sleep 5
    IP=$(sudo virsh domifaddr "$VM_NAME" --source agent 2>/dev/null | awk '$1 ~ /^(eth|enp)/ && /ipv4/ {print $4}' | cut -d/ -f1)
    if [ ! -z "$IP" ]; then
        echo "[i] VM IP: $IP"
        exit 0
    fi
done
