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
	sudo apt -y install suricata
	
	# stop suricata
	sudo systemctl stop suricata

	# config suricata
	sudo mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
	sudo cp conf/suricata.yaml /etc/suricata/
	sed -i "s/CHANGE-IFACE/$LIFACE/g" /etc/suricata/suricata.yaml

	# add support for cloud server type
	PUBLIC=$(curl -s ifconfig.me)
	LOCAL=$(hostname -I | cut -d' ' -f1)
	DEFIP="192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
	LOCIP="$LOCAL/24"

	if [[ $LOCAL = $PUBLIC ]];then
		sed -i "s~IP-ADDRESS~$LOCIP~" /etc/suricata/suricata.yaml
	else
		sed -i "s~IP-ADDRESS~$DEFIP~" /etc/suricata/suricata.yaml
	fi
	
	# update suricata rules with 'suricata-update' command
	# currently using rules source from 'Emerging Threats Open Ruleset'
	# -D command to specify directory from default value '/var/lib/suricata' to '/etc/suricata/'
	sudo suricata-update -D /etc/suricata/ enable-source et/open
	sudo suricata-update -D /etc/suricata/ update-sources
	# --no-merge command 'Do not merge the rules into a single rule file'
	# Detail on suricata-update command 'https://suricata-update.readthedocs.io/en/latest/update.html'
	sudo suricata-update -D /etc/suricata/ --no-merge


	# enable suricata at startup
	sudo systemctl enable suricata

	# start suricata
	sudo systemctl start suricata

	# print suricata version
	suricata -V

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


