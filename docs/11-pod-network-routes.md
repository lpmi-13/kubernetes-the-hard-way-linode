# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes.

In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

Essentially, we want a pod in each worker node to be able to find a pod in another worker node. So in case of a pod on worker-0 communicating with a pod on worker-1, the route is something like the following:

- pod on worker-0 has a CIDR range of 10.200.0.0/24 (from the kubelet config on that node). It needs to know that for contacting a pod in CIDR range 10.200.1.0/24 (a different subnet), it can use the worker-1 node as a gateway.

- we want to add a route like the following:

```sh
$ ip route add 10.200.1.0/24 via 192.168.138.48
```
(10.200.1.0/24 is the possible range for a pod on worker-1, and 192.168.138.48 is an example of a possible internal IP address for worker-1...because Linode private IPs are assigned randomly, your workers might have different values. However, it will be somewhere within the 192.168.X.X/17 range)

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model.

## The Routing Table and routes on the workers

> (Note: I eventually found a few obscure references to the fact that linode has packet filtering that just drops packets without src's that are inside their default private network 192.168.128.0/17, and I suspect this is why this tutorial falls flat in a region like eu-west, but works in a region with VLANs, like ca-central)

Since Linode (similar to Digitalocean) doesn't have a nice network routing abstraction from the CLI like AWS/GCP, we have to do this a bit manually, but it has the same effect.

Unfortunately, the previously generated `private_ip_mappings` file won't help us here, since it has the private IP addresses for the controller instances, but we can grab the same values for the worker instances and just update the workers via ssh.

Run the following commands to set all the necessary values in your shell:

```
# private IP addresses for setting pod network gateways

worker_0_instance_id=$(linode-cli linodes list --label worker-0 --json \
   | jq -r '.[].id')
worker_0_private_ip=$(linode-cli linodes ips-list $worker_0_instance_id \
   --json | jq -r '.[].ipv4.private | .[].address')

worker_1_instance_id=$(linode-cli linodes list --label worker-1 --json \
   | jq -r '.[].id')
worker_1_private_ip=$(linode-cli linodes ips-list $worker_1_instance_id \
   --json | jq -r '.[].ipv4.private | .[].address')

worker_2_instance_id=$(linode-cli linodes list --label worker-2 --json \
   | jq -r '.[].id')
worker_2_private_ip=$(linode-cli linodes ips-list $worker_2_instance_id \
   --json | jq -r '.[].ipv4.private | .[].address')

# public IP addresses for running commands via ssh

worker_0_instance_id=$(linode-cli linodes list --label worker-0 --json \
   | jq -r '.[].id')
worker_0_public_ip=$(linode-cli linodes ips-list $worker_0_instance_id \
   --json | jq -r '.[].ipv4.public | .[].address')
worker_1_instance_id=$(linode-cli linodes list --label worker-1 --json \
   | jq -r '.[].id')
worker_1_public_ip=$(linode-cli linodes ips-list $worker_1_instance_id \
   --json | jq -r '.[].ipv4.public | .[].address')
worker_2_instance_id=$(linode-cli linodes list --label worker-2 --json \
   | jq -r '.[].id')
worker_2_public_ip=$(linode-cli linodes ips-list $worker_2_instance_id \
   --json | jq -r '.[].ipv4.public | .[].address')
```

run the following commands for each of the worker nodes:

- worker-0

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_0_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"
```

- worker-1

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_1_public_ip -C "ip route add 10.200.0.0/24 via $worker_0_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"
```

- worker-2

```sh
ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_2_public_ip -C "ip route add 10.200.0.0/24 via $worker_0_private_ip;ip route add 10.200.1.0/24 via $worker_1_private_ip"
```

## DNS resolution on the controllers

We also need the controllers to be able to resolve the DNS for `worker-0` to its IP address (eg, `192.168.177.151`). So we need to run the following on each controller:

> Note: substitute whatever values your workers have for private IP addresses. The values given below are examples and yours are likely to be different.

```
cat <<EOF | sudo tee -a /etc/hosts
192.168.177.151 worker-0
192.168.138.48 worker-1
192.168.138.236 worker-2
EOF
```

Next: [Deploying the DNS Cluster Add-on](12-dns-addon.md)
