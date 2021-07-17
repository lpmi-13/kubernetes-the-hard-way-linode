# Provisioning Compute Resources

to set the correct region in this shell, first run:

```
source scripts/set_env.sh
```

which should set your `$REGION` to `eu-west`, but feel free to update the region in that file if you'd prefer a different one.

## Networking

### VPC (Linode doesn't have the concept of VPCs yet, so we'll try to just use private networking for what we need)

### Kubernetes Public Access - Create a Network Load Balancer

```sh
NODE_BALANCER_ID=$(linode-cli nodebalancers create \
  --label kubernetes-nodebalancer \
  --region ${REGION} \
  --json | jq -r '.[].id')
```

> the load balancer takes about a minute or so to be created, so if the ip address doesn't resolve with the following command, try again a bit later.

```sh
KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list --json \
  | jq -cr '.[] | select(.label == "kubernetes-nodebalancer") | .ipv4')
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

(this is still a bit dicey, since linode nodebalancers still don't natively allow https on nodebalancers, so still sorting out the best way to approach this).

(we're also gonna try to just use port 80 on this, since we don't need to mess around with SSL certs...which is bad...but will probably work)

(we also apparently don't have a return value from this config-create command, so we're gonna split out the creation and the assignment here into two different commands)

```sh
CONFIG_ID=$(linode-cli nodebalancers config-create \
  --port 80 \
  --protocol http \
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

...the sytax for the rules is...verbose, so it's easier to just pipe from a file

(might need to add an accept for port 80 to these...remains to be seen)

INBOUND_RULES=$(jq < config/inbound_rules.json)
OUTBOUND_RULES=$(jq < config/outbound_rules.json)


```
FIREWALL_ID=$(linode-cli firewalls create \
  --label kubernetes-firewall \
  --rules.outbound_policy ACCEPT \
  --rules.inbound_policy ACCEPT \
  --rules.inbound "$INBOUND_RULES" \
  --rules.outbound "$OUTBOUND_RULES" \
  --json \
  | jq -r '.[].id')

```

after the firewall is all set up, we need a separate API call to add the controller instances to it.

```
for i in 0 1 2; do
  instance_id=$(linode-cli linodes list --label controller-${i} --json | jq -r '.[].id')
  linode-cli firewalls device-create \
    --id "$instance_id" \
    --type linode \
    "$FIREWALL_ID"
done
```

Next: [Certificate Authority](04-certificate-authority.md)
