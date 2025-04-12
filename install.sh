#!/bin/sh
#
# Interactive installation script for NixOS using the minimal USB environment.
#
# Modes:
#   1. Full disk reformat (existing system will be overwritten)
#   2. Multiboot – manually choose partitions for NixOS, swap, and EFI.
#
# WARNING: Choosing the wrong options may result in irreversible data loss.
#

# ----------------------------------------------------------------------
# Step 1: Display attached storage devices and select a device

echo "------------------------------------------------------------"
echo "Listing all attached storage devices."
echo "Press Enter to continue (CTRL+C to abort)."
read NULL

sudo fdisk -l | less

echo "------------------------------------------------------------"
echo "Detected devices:"
echo

i=0
unset DEVICES
for device in $(sudo fdisk -l | grep "^Disk /dev" | awk '{print $2}' | sed 's/://'); do
    echo "[$i] $device"
    DEVICES[$i]=$device
    i=$((i+1))
done

echo
read -p "Enter the number of the device for NixOS installation: " DEVICEINDEX
DEV=${DEVICES[$DEVICEINDEX]}

echo "Selected device: ${DEV}"

# ----------------------------------------------------------------------
# Step 2: Select installation mode: Full reformat or Multiboot
echo "------------------------------------------------------------"
echo "Choose installation mode:"
echo "1: Full disk reformat (will overwrite the existing system)"
echo "2: Multiboot – manually choose and optionally format partitions"
read -p "Your choice (1 or 2): " MODE

# ----------------------------------------------------------------------
if [ "$MODE" = "1" ]; then
  echo "------------------------------------------------------------"
  echo "The entire disk ${DEV} will be repartitioned."
  read -p "Enter the desired swap size in GiB (e.g. 8): " SWAP
  echo "The following partitioning will be executed:"
  echo "- Partition 1: EFI System Partition (512M)"
  echo "- Partition 2: NixOS-root (from start until ${SWAP}GiB before end)"
  echo "- Partition 3: Swap (last ${SWAP}GiB)"
  read -p "Type 'go' to continue: " ANSWER

  if [ "$ANSWER" != "go" ]; then
      echo "Installation cancelled."
      exit 1
  fi

  echo "Repartitioning ${DEV}..."
  (
    echo g       # Create a new GPT partition table

    # Partition 1: EFI (512M)
    echo n
    echo 1     # Partition 1
    echo       # Default start sector
    echo +512M

    # Partition 2: NixOS-root (Rest of disk minus swap area)
    echo n
    echo 2     # Partition 2
    echo       # Default start sector
    echo -${SWAP}G

    # Partition 3: Swap (last SWAP GiB)
    echo n
    echo 3     # Partition 3
    echo       # Default start sector
    echo       # Default end sector (end of disk)

    # Set partition types
    echo t
    echo 1
    echo 1     # EFI System

    echo t
    echo 2
    echo 20    # Linux Filesystem

    echo t
    echo 3
    echo 19    # Linux Swap

    echo p     # Display partition table
    echo w     # Write changes
  ) | sudo fdisk ${DEV}

  # Wait for the system to recognize the new partition table
  sleep 2

  # Determine partition names (fallback: assume EFI is partition 1, root is 2, swap is 3)
  P_EFI=$(sudo fdisk -l | grep "^/dev" | grep "$DEV" | grep -i "EFI" | awk '{print $1}')
  [ -z "$P_EFI" ] && P_EFI="${DEV}1"
  P_ROOT="${DEV}2"
  P_SWAP="${DEV}3"

  echo "Created partitions:"
  echo "EFI: $P_EFI"
  echo "NixOS-root: $P_ROOT"
  echo "Swap: $P_SWAP"

  # Formatting partitions
  echo "------------------------------------------------------------"
  echo "Creating file systems..."
  echo "Formatting NixOS-root ($P_ROOT) as ext4..."
  sudo mkfs.ext4 -L nixos $P_ROOT

  echo "Formatting EFI partition ($P_EFI) as FAT32..."
  sudo mkfs.fat -F32 -n boot $P_EFI

  echo "Preparing swap on ($P_SWAP)..."
  sudo mkswap -L swap $P_SWAP
  sudo swapon $P_SWAP

elif [ "$MODE" = "2" ]; then
  echo "------------------------------------------------------------"
  echo "Multiboot mode: Existing disk structure will be preserved."
  echo "WARNING: It is recommended to back up your data first."
  echo "Displaying current partition table for ${DEV}:"
  sudo fdisk -l ${DEV} | less

  echo "Select the partition to be used as NixOS-root."
  read -p "Enter the device name (e.g. /dev/sda3): " P_ROOT
  read -p "Format this partition? (yes/no): " FORMAT_ROOT
  if [ "$FORMAT_ROOT" = "yes" ]; then
      echo "Formatting ${P_ROOT}..."
      sudo mkfs.ext4 -L nixos ${P_ROOT}
  else
      echo "Keeping the existing filesystem."
  fi

  echo "Select the partition to be used as Swap."
  read -p "Enter the Swap partition device name (e.g. /dev/sda4): " P_SWAP
  read -p "Recreate swap on this partition? (yes/no): " FORMAT_SWAP
  if [ "$FORMAT_SWAP" = "yes" ]; then
      echo "Preparing swap on ${P_SWAP}..."
      sudo mkswap -L swap ${P_SWAP}
  fi
  sudo swapon ${P_SWAP}

  echo "Select the EFI System Partition (ESP)."
  read -p "Enter the ESP device name (e.g. /dev/sda1): " P_EFI
  read -p "Format the EFI partition? (WARNING: For multiboot it is usually not recommended) (yes/no): " FORMAT_EFI
  if [ "$FORMAT_EFI" = "yes" ]; then
      echo "Formatting EFI partition ${P_EFI} as FAT32..."
      sudo mkfs.fat -F32 -n boot ${P_EFI}
  fi

else
  echo "Invalid selection. Please restart the script."
  exit 1
fi

# ----------------------------------------------------------------------
# Step 3: Mount partitions
echo "------------------------------------------------------------"
echo "Mounting NixOS-root partition..."
if ! sudo mount /dev/disk/by-label/nixos /mnt; then
    sudo mount ${P_ROOT} /mnt
fi

echo "Setting up and mounting the EFI system partition..."
sudo mkdir -p /mnt/boot
if ! sudo mount /dev/disk/by-label/boot /mnt/boot; then
    sudo mount ${P_EFI} /mnt/boot
fi

# ----------------------------------------------------------------------
# Step 4: Generate and edit NixOS configuration
echo "------------------------------------------------------------"
echo "Generating NixOS configuration..."
sudo nixos-generate-config --root /mnt

read -p "Press Enter to open the configuration in nano."
sudo nano /mnt/etc/nixos/configuration.nix

# ----------------------------------------------------------------------
# Step 5: Install NixOS
echo "------------------------------------------------------------"
echo "Installing NixOS..."
sudo nixos-install

read -p "Installation complete. Remove the installation media and press Enter to reboot." NULL
reboot
