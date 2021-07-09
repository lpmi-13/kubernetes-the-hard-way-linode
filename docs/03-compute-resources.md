# Provisioning Compute Resources

to set the correct region in this shell, first run:

```
source scripts/set_env.sh
```

which should set your `$REGION` to `eu-west`, but feel free to update the region in that file if you'd prefer a different one.

## Networking

### VPC (Linode doesn't have the concept of VPCs yet, so we'll try to just use private networking for what we need)

### Kubernetes Public Access - Create a Network Load Balancer

(still working out what the analog for the forwarding and health checks are in linode-land
```sh
LOAD_BALANCER_ID=$(linode-cli nodebalancers create \
  --label kubernetes-lb \
  --region ${REGION} \
  #--forwarding-rules entry_protocol:https,entry_port:443,target_protocol:https,target_port:6443,certificate_id:,tls_passthrough:true \
  #--health-check protocol:https,port:6443,path:/healthz,check_interval_seconds:10,response_timeout_seconds:5,healthy_threshold:5,unhealthy_threshold:3 \
  --json | jq -r '.[].id')
```

> the load balancer takes about a minute or so to be created, so if the ip address doesn't resolve with the following command, try again a bit later.

```sh
KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list \
  --json | jq -r '.[].ipv4')
```

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
    --tags kubernetes,controller \
    --private_ip true
done
```

### Kubernetes Workers

```sh
for i in 0 1 2; do
  linode-cli linodes create \
    --type g6-nanode-1
    --region ${REGION} \
    --image linode/ubuntu18.04 \
    --root_pass "CHANGE_ME" \
    --authorized_keys "$AUTHORIZED_KEY" \
    --label worker-${i} \
    --tags kubernetes,worker \
    --private_ip true
done
```

### Add the Controller nodes to the load balancer

We have to wait for all the instances to be created before we can add them (obviously), so now we're ready to continue configuring the load balancer.

First, we need to set a specific config for the load balancer, and then we can attach the controllers to that config.

```sh
CONFIG_ID=$(linode-cli nodebalancers config-create \
  --port 443 \
  --protocol http \
  --check connection \
  --check_interval 30 \
  --check_timeout 3 \
  --check_attempts 2 \
  "$LOAD_BALANCER_ID" | jq -r '.[].id')
```

Now we need to iterate through the nodes and grab their private IP addresses so we can attach them using both the nodebalancer ID and the config ID.

```sh
for i in 0 1 2; do
  instance_id=$(linode-cli linodes list --label controller-${i} --json | jq -r '.[].id')
  private_ip=$linode-cli linodes ips-list $instance_id --json | jq -r '.[].ipv4.private | .[].address')
  linode-cli nodebalancers node-create \
    --address "$private_ip" \
    --label controller-${i} \
    "$LOAD_BALANCER_ID" \
    "$CONFIG_ID"
  echo added controller-${i} to load balancer
done
```

### Firewall Rules

...the sytax for the rules is...verbose, so it's easier to just pipe from a file

RULES=$(jq < firewall_rules.json)

...I also currently can't figure out how to get the CLI to create multiple firewall rules in one command, and the example command shown in the API docs errors, so I'm just going to resort to using the REST API for now. Dissapoint.

```
FIREWALL_ID=$(curl -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -X POST -d "$RULES" \
    https://api.linode.com/v4/networking/firewalls \
    | jq -r '.id')
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