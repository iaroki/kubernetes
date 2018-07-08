#! /bin/sh

IPADDRESS=10.0.0.210
HOSTNAME="kubernetes"

echo "==> Updating system..."
yum update -y

echo "==> Disabling SWAP..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "==> Setting hostname..."
hostnamectl set-hostname $HOSTNAME

echo "===> Adding hostname to /etc/hosts..."
echo "$IPADDRESS  $HOSTNAME" >> /etc/hosts

echo "==> Disabling SELinux..."
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

echo "===> Disabling Firewalld..."
systemctl stop firewalld
systemctl disable firewalld

echo "==> Loading br_netfilter kernel module..."
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
modprobe br_netfilter

echo "==> Installing Docker..."
yum install -y docker

echo "===> Starting Docker..."
systemctl enable docker
systemctl start docker

echo "==> Adding Kubernetes repo..."
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "===> Installing kubernetes..."
yum install -y kubelet kubeadm kubectl

echo "====> Starting kubelet..."
systemctl enable kubelet
systemctl start kubelet

echo "==> Tweaking sysctl..."
cat <<EOF >  /etc/sysctl.d/kubernetess.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

echo "==> Kubernetes Initialization..."
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$IPADDRESS

echo "==> Copying credentials to /home/vagrant..."
sudo --user=vagrant mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config

echo "==> Disabling Master Node Isolation..."
kubectl --kubeconfig /etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/master-

echo "==> Installing pod network add-on..."
kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml

echo "==> All set and ready"
echo "===> Done"
