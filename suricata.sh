#!/bin/bash
set -euo pipefail

check_root() {
	if [[ $EUID -ne 0 ]]; then
	   echo "[-] This script must be run as root"
	   exit 1
	fi
}

check_update() {

	sudo apt update
}

check_iface() {
	
	IfaceAll=$(ip --oneline link show up | grep -v "lo" | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1)
	CountIface=$(wc -l <<< "${IfaceAll}")
	if [[ $CountIface -eq 1 ]]; then
		LIFACE=$IfaceAll
	else
		for iface in $IfaceAll
		do 
			echo "Available interface: "$iface
		done
		echo ""
	
		echo "Which Interface you want suricata to Listen(captured)?"
		read -p "Interface: " LIFACE
	fi
}

install_suricata() {
	
	# install dependencies
	sudo apt -y install libpcre3 libpcre3-dbg libpcre3-dev build-essential autoconf automake libtool libpcap-dev \
	libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev libmagic-dev libcap-ng-dev libjansson4 libjansson-dev pkg-config \
	rustc cargo libnetfilter-queue-dev geoip-bin geoip-database geoipupdate apt-transport-https libnetfilter-queue-dev \
        libnetfilter-queue1 libnfnetlink-dev tcpreplay

	# install with ubuntu package
	sudo add-apt-repository -y ppa:oisf/suricata-stable
	sudo apt update
	sudo apt -y install suricata suricata-dbg 
	
	# stop suricata
	sudo systemctl stop suricata

	# config suricata
	sudo mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
	sudo cp conf/suricata.yaml /etc/suricata/
	sed -i "s/CHANGE-IFACE/$LIFACE/g" /etc/suricata/suricata.yaml
	sudo rm -rf /etc/suricata/rules/*
	sudo cp rules/* /etc/suricata/rules/
	
	# enable suricata at startup
	sudo systemctl enable suricata

	# start suricata
	sudo systemctl start suricata

}

main() {

	#check root
	check_root

	# update
	check_update

	# check interface
	check_iface

	# install suricata 
	install_suricata	
}

main


