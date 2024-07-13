#!/bin/bash

msg() {
    echo "-> $@"
    dialog --msgbox "-> $@" 10 40
}

run_chroot() {
    arch-chroot /mnt/lfs /bin/bash -c "$@"
}

unmount() {
    while true; do
        mountpoint -q $1 || break
        umount $1 2>/dev/null
    done
}

check_network() {
    ping -c 1 google.com &> /dev/null
    if [ $? -ne 0 ]; then
        dialog --msgbox "Network is not reachable. Please check your network connection." 10 40
        exit 1
    fi
}

show_menu() {
    dialog --clear --backtitle "Arch Linux Installation" \
    --title "Main Menu" \
    --menu "Choose an option:" 15 50 7 \
    1 "Prepare Partitions" \
    2 "Install Base System" \
    3 "Configure System" \
    4 "Install Bootloader" \
    5 "Install Additional Software" \
    6 "Finalize Installation" \
    7 "Exit" 2>&1 > /dev/tty
}

prepare_partitions() {
    dialog --msgbox "Preparing partitions using gparted. This will erase all data on the target disk." 10 40

    gparted &
    gparted_pid=$!

    dialog --msgbox "Please use gparted to prepare the partitions. Close gparted when done." 10 40
    wait $gparted_pid

    local disk=$(dialog --inputbox "Enter the target disk (e.g., /dev/sda):" 10 40 3>&1 1>&2 2>&3)
    local boot_part=$(dialog --inputbox "Enter the boot partition (e.g., ${disk}1):" 10 40 3>&1 1>&2 2>&3)
    local root_part=$(dialog --inputbox "Enter the root partition (e.g., ${disk}2):" 10 40 3>&1 1>&2 2>&3)

    if [ -z "$disk" ] || [ -z "$boot_part" ] || [ -z "$root_part" ]; then
        dialog --msgbox "Invalid input. Aborting." 10 30
        return 1
    fi

    mkfs.ext4 $boot_part
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to format the boot partition $boot_part." 10 40
        return 1
    fi
    mkfs.ext4 $root_part
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to format the root partition $root_part." 10 40
        return 1
    fi

    mkdir -p /mnt/lfs
    mount $root_part /mnt/lfs
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to mount the root partition $root_part." 10 40
        return 1
    fi
    mkdir -p /mnt/lfs/boot
    mount $boot_part /mnt/lfs/boot
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to mount the boot partition $boot_part." 10 40
        return 1
    fi

    dialog --msgbox "Partitions prepared and mounted" 10 30
}

install_base_system() {
    check_network

    dialog --msgbox "Installing base system. This may take a while." 10 40

    pacstrap /mnt/lfs base base-devel linux linux-firmware
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to install base system. Check your internet connection and try again." 10 50
        return 1
    fi

    dialog --msgbox "Base system installed" 10 30
}

configure_system() {
    dialog --msgbox "Configuring system" 10 30

    # Generate fstab
    genfstab -U /mnt/lfs > /mnt/lfs/etc/fstab
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to generate fstab." 10 40
        return 1
    fi

    # Set hostname
    local hostname=$(dialog --inputbox "Enter hostname:" 10 40 3>&1 1>&2 2>&3)
    echo $hostname > /mnt/lfs/etc/hostname

    # Set root password
    run_chroot "passwd"

    # Set timezone
    local timezone=$(dialog --inputbox "Enter timezone (e.g., America/New_York):" 10 40 3>&1 1>&2 2>&3)
    run_chroot "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
    run_chroot "hwclock --systohc"

    # Generate locale
    run_chroot "sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen"
    run_chroot "locale-gen"
    echo "LANG=en_US.UTF-8" > /mnt/lfs/etc/locale.conf

    dialog --msgbox "System configured" 10 30
}

install_bootloader() {
    dialog --msgbox "Installing GRUB bootloader" 10 30

    run_chroot "pacman -S grub --noconfirm"
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to install GRUB. Check your internet connection and try again." 10 50
        return 1
    fi

    local disk=$(dialog --inputbox "Enter the target disk (e.g., /dev/sda):" 10 40 3>&1 1>&2 2>&3)

    run_chroot "grub-install $disk"
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to install GRUB on $disk. Check if the device exists and you have necessary permissions." 10 50
        return 1
    fi

    run_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
    if [ $? -ne 0 ]; then
        dialog --msgbox "Failed to generate GRUB config. You may need to create it manually." 10 50
        return 1
    fi

    dialog --msgbox "Bootloader installed" 10 30
}

install_additional_software() {
    dialog --checklist "Select additional software to install:" 20 70 10 \
    1 "Xorg" off \
    2 "GNOME" off \
    3 "KDE Plasma" off \
    4 "XFCE" off \
    5 "NetworkManager" off \
    6 "Firefox" off \
    7 "LibreOffice" off \
    8 "VLC" off \
    9 "GIMP" off \
    10 "GParted" off 2> /tmp/software_choices

    choices=$(cat /tmp/software_choices)

    for choice in $choices; do
        case $choice in
            1) run_chroot "pacman -S xorg xorg-server --noconfirm" ;;
            2) run_chroot "pacman -S gnome --noconfirm" ;;
            3) run_chroot "pacman -S plasma --noconfirm" ;;
            4) run_chroot "pacman -S xfce4 xfce4-goodies --noconfirm" ;;
            5) run_chroot "pacman -S networkmanager --noconfirm" ;;
            6) run_chroot "pacman -S firefox --noconfirm" ;;
            7) run_chroot "pacman -S libreoffice-fresh --noconfirm" ;;
            8) run_chroot "pacman -S vlc --noconfirm" ;;
            9) run_chroot "pacman -S gimp --noconfirm" ;;
            10) run_chroot "pacman -S gparted --noconfirm" ;;
        esac
        if [ $? -ne 0 ]; then
            dialog --msgbox "Failed to install package: $choice. Check your internet connection and try again." 10 50
        fi
    done

    dialog --msgbox "Additional software installed" 10 30
}

finalize_installation() {
    dialog --msgbox "Finalizing installation" 10 30

    unmount /mnt/lfs/boot
    unmount /mnt/lfs

    dialog --msgbox "Installation complete. You can now reboot into your new Arch Linux system." 10 50
}

while true; do
    choice=$(show_menu)
    case $choice in
        1) prepare_partitions ;;
        2) install_base_system ;;
        3) configure_system ;;
        4) install_bootloader ;;
        5) install_additional_software ;;
        6) finalize_installation ;;
        7) exit 0 ;;
    esac
done