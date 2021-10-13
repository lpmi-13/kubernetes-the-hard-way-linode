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

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_0_public_ip -C "ip route add 10.200.1.0/24 via $worker_1_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_1_public_ip -C "ip route add 10.200.0.0/24 via $worker_0_private_ip;ip route add 10.200.2.0/24 via $worker_2_private_ip"

ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$worker_2_public_ip -C "ip route add 10.200.0.0/24 via $worker_0_private_ip;ip route add 10.200.1.0/24 via $worker_1_private_ip"


cat > scripts/update_dns.sh <<FIN
cat <<EOF | sudo tee -a /etc/hosts
$worker_0_private_ip worker-0
$worker_1_private_ip worker-1
$worker_2_private_ip worker-2
EOF
FIN

for instance in controller-0 controller-1 controller-2; do
instance_id=$(linode-cli linodes list --label ${instance} \
  --json | jq -cr '.[].id')
external_ip=$(linode-cli linodes ips-list ${instance_id} --json \
  | jq -r '.[].ipv4.public | .[].address')

  ssh -i kubernetes.ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  root@$external_ip < ./scripts/update_dns.sh
done

