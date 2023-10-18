read -p 'hostname:' host_name

hostnamectl set-hostname $host_name
sudo rm -f /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
