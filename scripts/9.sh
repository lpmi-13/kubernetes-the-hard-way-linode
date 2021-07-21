for instance in worker-0 worker-1 worker-2; do
  instance_id=$(linode-cli linodes list --label ${instance} --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list ${instance_id} \
    --json | jq -r '.[].ipv4.public | .[].address')

  ssh -i kubernetes.id_rsa \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip "hostnamectl set-hostname $instance"

  ssh -i kubernetes.id_rsa \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip < ./scripts/bootstrap_workers.sh
done

echo "waiting 60 seconds before checking worker status"
sleep 60

instance_id=$(linode-cli linodes list --label controller-0 --json | jq -r '.[].id')
external_ip=$(linode-cli linodes ips-list ${instance_id} \
    --json | jq -r '.[].ipv4.public | .[].address')

ssh -i kubernetes.id_rsa \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
root@$external_ip "kubectl get nodes --kubeconfig admin.kubeconfig"

