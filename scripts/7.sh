controller_0_instance_id=$(linode-cli linodes list --label controller-0 --json     | jq -r '.[].id')
controller_0_private_ip=$(linode-cli linodes ips-list $controller_0_instance_id     --json | jq -r '.[].ipv4.private | .[].address')
controller_1_instance_id=$(linode-cli linodes list --label controller-1 --json     | jq -r '.[].id')
controller_1_private_ip=$(linode-cli linodes ips-list $controller_1_instance_id     --json | jq -r '.[].ipv4.private | .[].address')
controller_2_instance_id=$(linode-cli linodes list --label controller-2 --json     | jq -r '.[].id')
controller_2_private_ip=$(linode-cli linodes ips-list $controller_2_instance_id     --json | jq -r '.[].ipv4.private | .[].address')

tee private_ip_mappings <<EOF
  controller_0 $controller_0_private_ip
  controller_1 $controller_1_private_ip
  controller_2 $controller_2_private_ip
EOF

for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label "$instance" --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" \
  --json | jq -r '.[].ipv4.public | .[].address')

   scp -i kubernetes.id_rsa \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     private_ip_mappings root@${external_ip}:~/

   ssh -i kubernetes.id_rsa \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     root@$external_ip "hostnamectl set-hostname $instance"

   ssh -i kubernetes.id_rsa \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     root@$external_ip < ./scripts/bootstrap_etcd_on_controllers.sh
done

