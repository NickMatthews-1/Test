# This grabs the hostname
read -p 'hostname:' host_name

# This sets the hostname varirable
hostnamectl set-hostname $host_name

# This deletes the machine id
sudo rm -f /etc/machine-id

# This deletes the machine id
sudo rm -f /var/lib/dbus/machine-id

# This sets up the machine id
sudo systemd-machine-id-setup

sed -i 's/debian/$host_name/g' /etc/hosts

sed -i 's/dhcp/static/g' /etc/network/interfaces
