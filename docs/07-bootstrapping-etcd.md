# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/coreos/etcd). In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

## Prerequisites

### Saving private IPs to pass to the instances

Because the private IP addresses assigned to the individual instances aren't predictable or able to be specified (linode doesn't offer the network abstraction option of a VPC), and each of the controllers needs to know the private IPs of the other controllers, we need a way to pass through what all three of the controller instance private IPs are to the instances themselves.

```
controller_0_instance_id=$(linode-cli linodes list --label controller-0 --json     | jq -r '.[].id')
controller_0_private_ip=$(linode-cli linodes ips-list $controller_0_instance_id     --json | jq -r '.[].ipv4.private | .[].address')
controller_1_instance_id=$(linode-cli linodes list --label controller-1 --json     | jq -r '.[].id')
controller_1_private_ip=$(linode-cli linodes ips-list $controller_1_instance_id     --json | jq -r '.[].ipv4.private | .[].address')
controller_2_instance_id=$(linode-cli linodes list --label controller-2 --json     | jq -r '.[].id')
controller_2_private_ip=$(linode-cli linodes ips-list $controller_2_instance_id     --json | jq -r '.[].ipv4.private | .[].address')

tee private_ip_mappings <<EOF
  controller_0 "$controller_0_private_ip"
  controller_1 "$controller_1_private_ip"
  controller_2 "$controller_2_private_ip"
EOF
```

Now, we copy this file to each of the controllers so we can use it once we're setting up etcd. Let's also explicitly set the hostnames, since Linode doesn't have an easy way to do this via the cli and it's needed for the etcd config later.

```
for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label "$instance" --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" \
  --json | jq -r '.[].ipv4.public | .[].address')

   scp -i kubernetes.ed25519 \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     private_ip_mappings root@${external_ip}:~/

   ssh -i kubernetes.ed25519 \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     root@$external_ip "hostnamectl set-hostname $instance"
done
```

The rest of the commands in this lab must be run on each controller instance: `controller-0`, `controller-1`, and `controller-2`. Login to each controller instance using the `ssh` command. Example:

```
for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label "$instance" --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" \
  --json | jq -r '.[].ipv4.public | .[].address')

  echo ssh -i kubernetes.ed25519 root@$external_ip
done
```

Now ssh into each one of the IP addresses received in last step.

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [coreos/etcd](https://github.com/coreos/etcd) GitHub project:

```
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.3.18/etcd-v3.3.18-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
tar -xvf etcd-v3.3.18-linux-amd64.tar.gz
sudo mv etcd-v3.3.18-linux-amd64/etcd* /usr/local/bin/
```

### Configure the etcd Server

```
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:

> it would be nice if linode had some sort of metadata service like AWS, but this piped command should work

```
INTERNAL_IP=$(ip a | grep 192 | awk -F ' ' '{print $2}' | awk -F \/ '{print $1}')
```

And for the rest of the controller private IPs, we can grab the values from the `private_ip_mappings` file we copied in earlier:

```
controller_0_private_ip=$(grep controller_0 private_ip_mappings | awk -F ' ' '{print $2}')
controller_1_private_ip=$(grep controller_1 private_ip_mappings | awk -F ' ' '{print $2}')
controller_2_private_ip=$(grep controller_2 private_ip_mappings | awk -F ' ' '{print $2}')
```

Create the `etcd.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name $(hostname) \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://${controller_0_private_ip}:2380,controller-1=https://${controller_1_private_ip}:2380,controller-2=https://${controller_2_private_ip}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the etcd Server

```
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

List the etcd cluster members:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output

```
3b36699f928b9611, started, controller-0, https://192.168.205.183:2380, https://192.168.205.183:2379
7af3acd247f74985, started, controller-2, https://192.168.205.191:2380, https://192.168.205.191:2379
ebc8a0424fde72e0, started, controller-1, https://192.168.205.188:2380, https://192.168.205.188:2379
```

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)
