#!/bin/bash

apt-get update
apt-get -y install libncurses5-dev
apt-get -y install gcc-4.8 g++-4.8

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 50
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 20
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 50
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 20

cd /home/pi
mkdir empc-arpi-linux-drivers
cd empc-arpi-linux-drivers

sudo wget https://raw.githubusercontent.com/notro/rpi-source/master/rpi-source -O /usr/bin/rpi-source && sudo chmod +x /usr/bin/rpi-source && /usr/bin/rpi-source -q --tag-update

rpi-source
cd /root/linux-*

wget https://raw.githubusercontent.com/janztec/empc-arpi-linux/rpi-3.18.y/arch/arm/boot/dts/overlays/sc16is7xx-ttysc0-overlay.dts -O arch/arm/boot/dts/overlays/sc16is7xx-ttysc0-overlay.dts
wget https://raw.githubusercontent.com/janztec/empc-arpi-linux/rpi-3.18.y/arch/arm/boot/dts/overlays/mcp2515-can0-overlay.dts -O arch/arm/boot/dts/overlays/mcp2515-can0-overlay.dts
wget https://raw.githubusercontent.com/janztec/empc-arpi-linux/rpi-3.18.y/drivers/spi/spi-bcm2835.c -O drivers/spi/spi-bcm2835.c
wget https://raw.githubusercontent.com/janztec/empc-arpi-linux/rpi-3.18.y/drivers/net/can/spi/mcp251x.c -O drivers/net/can/mcp251x.c
wget https://raw.githubusercontent.com/janztec/empc-arpi-linux/rpi-3.18.y/drivers/tty/serial/sc16is7xx.c -O drivers/tty/serial/sc16is7xx.c


make SUBDIRS=arch/arm/boot/dts/overlays modules
make SUBDIRS=drivers/tty/serial modules
make SUBDIRS=drivers/net/can modules
make SUBDIRS=drivers/spi modules

KERNEL=$(uname -r)

mkdir -p /lib/modules/$KERNEL/kernel/drivers/net/can/spi
mkdir -p /lib/modules/$KERNEL/kernel/drivers/tty/serial

cp arch/arm/boot/dts/overlays/sc16is7xx-ttysc0-overlay.dtb /boot/overlays/sc16is7xx-ttysc0-overlay.dtb
cp arch/arm/boot/dts/overlays/mcp2515-can0-overlay.dtb /boot/overlays/mcp2515-can0-overlay.dtb
cp drivers/spi/spi-bcm2835.ko /lib/modules/$KERNEL/kernel/drivers/spi/spi-bcm2835.ko
cp drivers/net/can/spi/mcp251x.ko /lib/modules/$KERNEL/kernel/drivers/net/can/spi/mcp251x.ko
cp drivers/tty/serial/sc16is7xx.ko /lib/modules/$KERNEL/kernel/drivers/tty/serial/sc16is7xx.ko

depmod -a

if grep -q "spi-bcm2835" "/boot/config.txt"; then
        echo ""
else
        echo "INFO: Enabling I2C in /boot/config.txt"
        echo "" >>/boot/config.txt
        echo "dtparam=i2c_arm=on" >>/boot/config.txt

        echo "INFO: Installing CAN and RS232/RS485 driver DT in /boot/cmdline.txt"
        echo "dtparam=spi=on" >>/boot/config.txt
        echo "dtoverlay=mcp2515-can0-overlay,oscillator=16000000,interrupt=25" >>/boot/config.txt
        echo "dtoverlay=spi-bcm2835-overlay" >>/boot/config.txt
        echo "dtoverlay=sc16is7xx-ttysc0-overlay" >>/boot/config.txt
fi

if grep -q "sc16is7xx" "/etc/modules"; then
        echo ""
else
        echo "INFO: Installing RS232/RS485 driver module in /etc/modules"
        echo "sc16is7xx" >>/etc/modules
fi

if grep -q "sc16is7xx.RS485" "/boot/cmdline.txt"; then
        echo ""
else
        echo "INFO: Configuring green LED as microSD-card activity LED in /boot/cmdline.txt"
        sed -i 's/rootwait/rootwait bcm2709.disk_led_gpio=5 bcm2709.disk_led_active_low=0/g' /boot/cmdline.txt

        echo "INFO: setting RS232/RS485 mode based on jumper J301 in /boot/cmdline.txt"
        sed -i 's/rootwait/rootwait sc16is7xx.RS485=2/g' /boot/cmdline.txt
fi



if grep -q "ssh_host_dsa_key" "/etc/rc.local"; then
        echo ""
else
        echo "INFO: Installating SSH key generation /etc/rc.local"
        echo "test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server" >>/etc/rc.local
fi


if grep -q "mcp7940x 0x6f" "/etc/rc.local"; then
        echo ""
else
        echo "INFO: Installating RTC auto start into /etc/rc.local"
        sed -i 's/exit 0//g' /etc/rc.local
        echo "echo mcp7940x 0x6f > /sys/class/i2c-adapter/i2c-1/new_device" >>/etc/rc.local
        echo "exit 0" >>/etc/rc.local
fi

if grep -q "max_usb_current=1" "/boot/config.txt"; then
        echo ""
else
        echo "" >>/boot/config.txt
        echo "INFO: Configuring USB max current in /boot/config.txt"
        echo "max_usb_current=1" >>/boot/config.txt

        echo "INFO: Enabling green LED as microSD activity LED"
        echo "dtparam=act_led_gpio=5" >>/boot/config.txt
fi

if grep -q "triple-sampling" "/etc/network/interfaces"; then
        echo ""
else
        echo "INFO: Configuring auto start can0 at 500KBit in /etc/network/interfaces"
        echo "" >>/etc/network/interfaces
        echo "allow-hotplug can0" >>/etc/network/interfaces
        echo "iface can0 inet manual" >>/etc/network/interfaces
        echo -e "\tpre-up /sbin/ip link set can0 type can bitrate 500000 triple-sampling on" >>/etc/network/interfaces
        echo -e "\tup /sbin/ifconfig can0 txqueuelen 1000" >>/etc/network/interfaces
        echo -e "\tup /sbin/ifconfig can0 up" >>/etc/network/interfaces
        echo -e "\tdown /sbin/ifconfig can0 down" >>/etc/network/interfaces
fi



