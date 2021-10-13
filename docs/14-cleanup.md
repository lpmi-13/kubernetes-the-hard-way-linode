# Cleaning Up

In this lab you will delete the compute resources created during this tutorial.

## Compute Instances

Delete the controller and worker instances:

```
for tag in controller worker; do
  for instance_id in $(linode-cli linodes list --tags $tag --json | jq -r '.[].id'); do
    echo "deleting ${tag}: ${instance_id}"
    linode-cli linodes delete ${instance_id}
  done
done
```

## Local SSH Keys

Delete the SSH keys we created just for this exercise.

```
LOCAL_PRIVATE_SSH_KEY=kubernetes.ed25519
if [ -f "$LOCAL_PRIVATE_SSH_KEY" ]; then
  echo "deleting local private ssh key previously generated"
  rm -rf kubernetes.ed25519
else
  echo "no local private key found"
fi

LOCAL_PUBLIC_SSH_KEY=kubernetes.ed25519.pub
if [ -f "$LOCAL_PUBLIC_SSH_KEY" ]; then
  echo "deleting local public ssh key previously generated"
  rm -rf kubernetes.ed25519.pub
else
  echo "no local public key found"
fi
```

# Node Balancer

Delete the node balancer (same as load balancer in the other tutorials):

```
NODE_BALANCER_ID=$(linode-cli nodebalancers list --label kubernetes-nodebalancer --json \
  | jq -cr '.[].id')
if [ -z ${NODE_BALANCER_ID} ]; then
  echo "no load balancer found"
else
  echo "deleting load balancer: ${NODE_BALANCER_ID}"
  linode-cli nodebalancers delete ${NODE_BALANCER_ID}
fi
```

## Firewall

Delete the firewall:

```
FIREWALL_ID=$(linode-cli firewalls list --label kubernetes-firewall --json | jq -cr '.[].id')
if [ -z ${FIREWALL_ID} ]; then
  echo "no firewall found"
else
  echo "deleting firewall: ${FIREWALL_ID}"
  linode-cli firewalls delete ${FIREWALL_ID}
fi
```

