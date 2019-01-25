#!/bin/bash

## Default variables to use
export INTERACTIVE=${INTERACTIVE:="true"}
export PVS=${INTERACTIVE:="true"}
#export DOMAIN=${DOMAIN:="$(curl -s ipinfo.io/ip).nip.io"}
export DOMAIN=${DOMAIN:="$(hostname)"}
export USERNAME=${USERNAME:="$(whoami)"}
export PASSWORD=${PASSWORD:=admin}
export VERSION="3.11"
export BASTION="yes"
export REPOVERSION=${REPOVERSION:="$(echo $VERSION | tr -d .)"}
export SCRIPT_REPO=${SCRIPT_REPO:="https://raw.githubusercontent.com/dpdevel/openshift311-on-centos/master"}
export IP_MST=${IP_MST:="$(ip route get 8.8.8.8 | awk '{print $NF; exit}')"}
export API_PORT=${API_PORT:="8443"}

## Make the script interactive to set the variables
if [ "$INTERACTIVE" = "true" ]; then
	read -rp "Domain to use: ($DOMAIN): " choice;
	if [ "$choice" != "" ] ; then
		export DOMAIN="$choice";
	fi

	read -rp "Username: ($USERNAME): " choice;
	if [ "$choice" != "" ] ; then
		export USERNAME="$choice";
	fi

	read -rp "Password: ($PASSWORD): " choice;
	if [ "$choice" != "" ] ; then
		export PASSWORD="$choice";
	fi

	read -rp "IP_MST: ($IP_MST): " choice;
	if [ "$choice" != "" ] ; then
		export IP_MST="$choice";
	fi

	read -rp "API Port: ($API_PORT): " choice;
	if [ "$choice" != "" ] ; then
		export API_PORT="$choice";
	fi 
	
	read -rp "IP INF: ($IP_INF): " choice;
	if [ "$choice" != "" ] ; then
		export IP_INF="$choice";
	fi 
	
	read -rp "IP APP: ($IP_APP): " choice;
	if [ "$choice" != "" ] ; then
		export IP_APP="$choice";
	fi 
	
	read -rp "BASTION: ($BASTION): " choice;
	if [ "$choice" != "" ] ; then
		export BASTION="$choice";
	fi 

	echo

fi

echo "******"
echo "* Your domain is $DOMAIN "
echo "* Your IP_MST is $IP_MST "
echo "* Your IP_INF is $IP_INF "
echo "* Your IP_APP is $IP_APP "
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "* OpenShift version: $VERSION "
echo "******"

# install updates
yum update -y

# install the following base packages
yum install -y  wget git zile nano net-tools docker-1.13.1\
				bind-utils iptables-services \
				bridge-utils bash-completion \
				kexec-tools sos psacct openssl-devel \
				httpd-tools NetworkManager \
				python-cryptography python2-pip python-devel  python-passlib \
				java-1.8.0-openjdk-headless "@Development Tools"

#install epel
yum -y install epel-release

# Disable the EPEL repository globally so that is not accidentally used during later steps of the installation
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

systemctl | grep "NetworkManager.*running" 
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

# install the packages for Ansible
yum -y --enablerepo=epel install pyOpenSSL

if [ $BASTION == "yes" ]; then
	curl -o ansible.rpm https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.6.5-1.el7.ans.noarch.rpm
	yum -y --enablerepo=epel install ansible.rpm

	[ ! -d openshift-ansible ] && git clone --branch release-${VERSION} https://github.com/openshift/openshift-ansible.git

	cd openshift-ansible && git fetch && git checkout release-${VERSION} && cd ..
fi

cat <<EOD > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
${IP_MST}		ocp-mst01 console console.${DOMAIN}
${IP_INF}		ocp-inf01 
${IP_APP}		ocp-app01
EOD

if [ -z $DISK ]; then 
	echo "Not setting the Docker storage."
else
	cp /etc/sysconfig/docker-storage-setup /etc/sysconfig/docker-storage-setup.bk

	echo DEVS=$DISK > /etc/sysconfig/docker-storage-setup
	echo VG="docker-vg" >> /etc/sysconfig/docker-storage-setup
	echo DATA_SIZE="95%VG" >> /etc/sysconfig/docker-storage-setup
	echo STORAGE_DRIVER=overlay2 >> /etc/sysconfig/docker-storage-setup
	echo CONTAINER_ROOT_LV_NAME="dockerlv" >> /etc/sysconfig/docker-storage-setup
	echo CONTAINER_ROOT_LV_MOUNT_PATH="/var/lib/docker" >> /etc/sysconfig/docker-storage-setup
	echo CONTAINER_ROOT_LV_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup
	echo WIPE_SIGNATURES=true >> /etc/sysconfig/docker-storage-setup

	systemctl stop docker

	rm -rf /var/lib/docker
	wipefs --all $DISK
	docker-storage-setup
fi

systemctl restart docker
systemctl enable docker

if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -q -f ~/.ssh/id_rsa -N ""
	cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	ssh -o StrictHostKeyChecking=no root@$IP "pwd" < /dev/null
fi

if [ $BASTION == "no" ]; then
	exit
fi

export METRICS="True"
export LOGGING="True"

memory=$(cat /proc/meminfo | grep MemTotal | sed "s/MemTotal:[ ]*\([0-9]*\) kB/\1/")

if [ "$memory" -lt "4194304" ]; then
	export METRICS="False"
fi

if [ "$memory" -lt "16777216" ]; then
	export LOGGING="False"
fi

curl -o inventory.download $SCRIPT_REPO/inventory.ini
envsubst < inventory.download > inventory.ini

# add proxy in inventory.ini if proxy variables are set
if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
	echo >> inventory.ini
	echo "openshift_http_proxy=\"${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}\"" >> inventory.ini
	echo "openshift_https_proxy=\"${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}\"" >> inventory.ini
	if [ ! -z "${NO_PROXY:-${no_proxy}}" ]; then
		__no_proxy="${NO_PROXY:-${no_proxy}},${IP},.${DOMAIN}"
	else
		__no_proxy="${IP},.${DOMAIN}"
	fi
	echo "openshift_no_proxy=\"${__no_proxy}\"" >> inventory.ini
fi

mkdir -p /etc/origin/master/
touch /etc/origin/master/htpasswd
htpasswd -b /etc/origin/master/htpasswd ${USERNAME} ${PASSWORD}

echo "********************************"
echo "*** NOW YOU CAN EXCUTE: ***"
echo "--> ansible-playbook -i inventory.ini openshift-ansible/playbooks/prerequisites.yml"
echo "--> ansible-playbook -i inventory.ini openshift-ansible/playbooks/deploy_cluster.yml"
echo 

#if [ $? -ne 0 ]; then
#	echo "error install ocp-$VERSION"
#	exit
#fi

echo "--> oc adm policy add-cluster-role-to-user cluster-admin ${USERNAME}"

#if [ "$PVS" = "true" ]; then
#
#	curl -o vol.yaml $SCRIPT_REPO/vol.yaml
#
#	for i in `seq 1 200`;
#	do
#		DIRNAME="vol$i"
#		mkdir -p /mnt/data/$DIRNAME 
#		chcon -Rt svirt_sandbox_file_t /mnt/data/$DIRNAME
#		chmod 777 /mnt/data/$DIRNAME
#		
#		sed "s/name: vol/name: vol$i/g" vol.yaml > oc_vol.yaml
#		sed -i "s/path: \/mnt\/data\/vol/path: \/mnt\/data\/vol$i/g" oc_vol.yaml
#		oc create -f oc_vol.yaml
#		echo "created volume $i"
#	done
#	rm oc_vol.yaml
#fi

echo
echo "******** After install: ************"
echo "* Your console is https://console.$DOMAIN:$API_PORT"
echo "* Your username is $USERNAME "
echo "* Your password is $PASSWORD "
echo "*"
echo "* Login using:"
echo "*"
echo "$ oc login -u ${USERNAME} -p ${PASSWORD} https://console.$DOMAIN:$API_PORT/"
echo "******"
