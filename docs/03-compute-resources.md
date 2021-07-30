# Provisioning Compute Resources

to set the correct region in this shell, first run:

```
source scripts/set_env.sh
```

which should set your `$REGION` to `ca-central`, but feel free to update the region in that file if you'd prefer a different one.

## Networking

### VPC (Linode doesn't have the concept of VPCs yet, so we'll try to just use private networking for what we need)

> They do technically have VLANs, but only in three regions (ca-central being one of them). For whatever magic reason, this walkthrough "just works" (:tm:) in Canada, but not London. I feel like it might be related to this region having the network architecture already set up for VLANs, but a win is a win.

### Kubernetes Public Access - Create a Network Load Balancer

```sh
NODE_BALANCER_ID=$(linode-cli nodebalancers create \
  --label kubernetes-nodebalancer \
  --region ${REGION} \
  --json | jq -r '.[].id')
```

> the load balancer takes about a minute or so to be created, so if the ip address doesn't resolve with the following command, try again a bit later.

```sh
KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list --label kubernetes-nodebalancer --json \
  | jq -cr '.[].ipv4')
```

...we also might want to set up the configuration first, since it looks like if we set up the compute, it triggers the nodebalancer to automatically select port 443, which then makes it difficult to create the right config.

## Compute Instances

### SSH Key

create a local ssh key just for this exercise

```
ssh-keygen -t rsa -b 4096 -f kubernetes.id_rsa
```

> linode wants the contents of the ssh key rather than a file reference, so we need to cat this out

```sh
AUTHORIZED_KEY=$(cat kubernetes.id_rsa.pub)
```

### Kubernetes Controllers

> Using `g6-nanode-1` instances, slightly smaller than the t3.micro instances used in the AWS version, but should get the job done

```sh
for i in 0 1 2; do
  linode-cli linodes create \
    --type g6-nanode-1 \
    --region ${REGION} \
    --image linode/ubuntu18.04 \
    --root_pass "CHANGE_ME" \
    --authorized_keys "$AUTHORIZED_KEY" \
    --label controller-${i} \
    --tags controller \
    --private_ip true
done
```

### Kubernetes Workers

```sh
for i in 0 1 2; do
  linode-cli linodes create \
    --type g6-nanode-1 \
    --region ${REGION} \
    --image linode/ubuntu18.04 \
    --root_pass "CHANGE_ME" \
    --authorized_keys "$AUTHORIZED_KEY" \
    --label worker-${i} \
    --tags worker \
    --private_ip true
done
```

### Add the Controller nodes to the load balancer

We have to wait for all the instances to be created before we can add them (obviously), so now we're ready to continue configuring the load balancer.

First, we need to set a specific config for the load balancer, and then we can attach the controllers to that config.

```sh
CONFIG_ID=$(linode-cli nodebalancers config-create \
  --port 443 \
  --protocol tcp \
  --check connection \
  --check_path /healthz \
  --check_interval 10 \
  --check_timeout 5 \
  --check_attempts 3 \
  "$NODE_BALANCER_ID" \
  --json | jq -r '.[].id')
```

Now we need to iterate through the nodes and grab their private IP addresses so we can attach them using both the nodebalancer ID and the config ID.

```sh
for i in 0 1 2; do
  instance_id=$(linode-cli linodes list --label controller-${i} --json | jq -r '.[].id')
  private_ip=$(linode-cli linodes ips-list $instance_id --json | jq -r '.[].ipv4.private | .[].address')
  linode-cli nodebalancers node-create \
    --address "${private_ip}:6443" \
    --label controller-${i} \
    "$NODE_BALANCER_ID" \
    "$CONFIG_ID"
  echo added controller-${i} to load balancer
done
```

### Firewall Rules

I actually thought we would need a firewall, but linode's firewall doesn't seem to actually do anything, so we can just skip it.

Next: [Certificate Authority](04-certificate-authority.md)
