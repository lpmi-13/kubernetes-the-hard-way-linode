source scripts/set_env.sh

NODE_BALANCER_ID=$(linode-cli nodebalancers create \
  --label kubernetes-nodebalancer \
  --region ${REGION} \
  --json | jq -r '.[].id')

KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list --label kubernetes-nodebalancer --json \
  | jq -cr '.[].ipv4')

ssh-keygen -t ed25519 -o -a 100 -f kubernetes.ed25519 -N ""

AUTHORIZED_KEY=$(cat kubernetes.ed25519.pub)

for i in 0 1 2; do
  linode-cli linodes create \
    --type g6-standard-1 \
    --region ${REGION} \
    --image linode/ubuntu18.04 \
    --root_pass "CHANGE_ME" \
    --authorized_keys "$AUTHORIZED_KEY" \
    --label controller-${i} \
    --tags controller \
    --private_ip true
done

for i in 0 1 2; do
  linode-cli linodes create \
    --type g6-standard-1 \
    --region ${REGION} \
    --image linode/ubuntu18.04 \
    --root_pass "CHANGE_ME" \
    --authorized_keys "$AUTHORIZED_KEY" \
    --label worker-${i} \
    --tags worker \
    --private_ip true
done

# because VM provisioning isn't super fast, and we want port 22 to be up and listening by the time we start copying over things
echo waiting 30 seconds for nodes to come up...
sleep 30

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

INBOUND_RULES=$(jq < config/inbound_rules.json)
OUTBOUND_RULES=$(jq < config/outbound_rules.json)

FIREWALL_ID=$(linode-cli firewalls create \
  --label kubernetes-firewall \
  --rules.outbound_policy DROP \
  --rules.inbound_policy DROP \
  --rules.inbound "$INBOUND_RULES" \
  --rules.outbound "$OUTBOUND_RULES" \
  --json \
  | jq -r '.[].id')

for i in worker-0 worker-1 worker-2 controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label ${i} --json | jq -r '.[].id')
  linode-cli firewalls device-create \
    --id "$instance_id" \
    --type linode \
    "$FIREWALL_ID"
done

