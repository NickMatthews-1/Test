echo -e "\e[0;31m Please put /24 at the end \e[0m"
# fetch ip
read -p 'ip: ' ip

#fetch gateway
read -p 'gateway: ' gateway

# This grabs the hostname
read -p 'hostname: ' host_name

# This sets the hostname varirable
hostnamectl set-hostname $host_name

# This deletes the machine id
sudo rm -f /etc/machine-id

# This deletes the machine id
sudo rm -f /var/lib/dbus/machine-id

# This sets up the machine id
sudo systemd-machine-id-setup

sed -i 's/debian/$host_name/g' /etc/hosts

# This sets the networking to static
sed -i 's/dhcp/static/g' /etc/network/interfaces

#set ip and gateway 
echo '    address '$ip >> /etc/network/interfaces
echo '    gateway '$gateway >> /etc/network/interfaces
systemctl restart networking
