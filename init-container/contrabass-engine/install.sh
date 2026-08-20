#!/bin/bash
image_file="openstack-ansible.tar"
image_version="v1.6"

mkdir -p /opt/cni/bin
mkdir /etc/containerd
mkdir /etc/nerdctl
mkdir /etc/buildkit

tar -zxf containerd-2.1.5-linux-amd64.tar.gz -C /usr/local/ && \
install -m 755 runc.amd64 /usr/local/bin/runc && \
tar -zxf nerdctl-2.1.6-linux-amd64.tar.gz -C /usr/local/bin/ && \
tar -zxf buildkit-v0.12.4.linux-amd64.tar.gz -C /usr/local/ && \
tar -zxf cni-plugins-linux-amd64-v1.8.0.tgz -C /opt/cni/bin/

cp ./containerd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now containerd.service

containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd.service

cp ./nerdctl.toml /etc/nerdctl/

cp ./buildkit.socket /etc/systemd/system/
cp ./buildkit.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now buildkit.socket
systemctl enable --now buildkit.service

cp ./buildkitd.toml /etc/buildkit/
systemctl restart buildkit.service


echo "##Start OpenStack Init Container##"

nerdctl load -i $image_file
nerdctl run -dt --name okestro-os-ansible --ulimit nofile=65536:65536 -v ./okestro/okestro-openstack:/root/okestro/okestro-openstack openstack-ansible:$image_version
nerdctl cp ./cirros-0.6.2-x86_64-disk.img okestro-os-ansible:/root/okestro/
nerdctl exec -it okestro-os-ansible sh -c "rc-status"
nerdctl exec -it okestro-os-ansible sh -c "mkdir /root/.ssh"
nerdctl exec -it okestro-os-ansible sh -c "sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config"
nerdctl exec -it okestro-os-ansible sh -c "echo 'root:cloud1234' | chpasswd"
nerdctl exec -it okestro-os-ansible sh -c "service sshd restart"
nerdctl exec -it okestro-os-ansible sh -c "mkdir /root/ansible"
