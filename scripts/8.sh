# this runs a local script on the remote controllers to bootstrap the control plane
for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label ${instance} \
    --json | jq -cr '.[].id')
  external_ip=$(linode-cli linodes ips-list ${instance_id} --json \
    | jq -r '.[].ipv4.public | .[].address')

  ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip < ./scripts/bootstrap_control_plane.sh
done

echo "waiting 30 seconds for etcd to be fully initialized..."
sleep 30

for instance in controller-0; do
  instance_id=$(linode-cli linodes list --label ${instance} \
    --json | jq -cr '.[].id')
  external_ip=$(linode-cli linodes ips-list ${instance_id} --json \
    | jq -r '.[].ipv4.public | .[].address')

  ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip "kubectl get componentstatus"
done

echo "setting up RBAC from controller-0"

instance_id=$(linode-cli linodes list --label controller-0 \
  --json | jq -cr '.[].id')
external_ip=$(linode-cli linodes ips-list ${instance_id} --json \
  | jq -r '.[].ipv4.public | .[].address')

ssh -i kubernetes.ed25519 \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
root@$external_ip < ./scripts/set_up_rbac.sh

KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list --label kubernetes-nodebalancer --json | jq -r '.[].ipv4')

curl -k --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}/version

