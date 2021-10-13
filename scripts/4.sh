cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

for i in 0 1 2; do
  instance="worker-${i}"
  instance_hostname="worker-${i}"
  cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance_hostname}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

  instance_id=$(linode-cli linodes list --label worker-${i} \
    --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" --json | jq -r '.[].ipv4.public | .[].address')
  internal_ip=$(linode-cli linodes ips-list "$instance_id" --json | jq -r '.[].ipv4.private | .[].address')

  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -hostname=${instance_hostname},${external_ip},${internal_ip} \
    -profile=kubernetes \
    worker-${i}-csr.json | cfssljson -bare worker-${i}
done

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

KUBERNETES_PUBLIC_ADDRESS=$(linode-cli nodebalancers list --label kubernetes-nodebalancer --json | jq -r '.[].ipv4')

controller_0_instance_id=$(linode-cli linodes list --label controller-0 --json | jq -r '.[].id')
controller_0_private_ip=$(linode-cli linodes ips-list "$controller_0_instance_id" --json | jq -r '.[].ipv4.private | .[].address')
controller_1_instance_id=$(linode-cli linodes list --label controller-1 --json | jq -r '.[].id')
controller_1_private_ip=$(linode-cli linodes ips-list "$controller_1_instance_id" --json | jq -r '.[].ipv4.private | .[].address')
controller_2_instance_id=$(linode-cli linodes list --label controller-2 --json | jq -r '.[].id')
controller_2_private_ip=$(linode-cli linodes ips-list "$controller_2_instance_id" --json | jq -r '.[].ipv4.private | .[].address')

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${controller_0_private_ip},${controller_1_private_ip},${controller_2_private_ip},${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes


cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

for instance in worker-0 worker-1 worker-2; do
  instance_id=$(linode-cli linodes list --label "$instance" --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" --json | jq -r '.[].ipv4.public | .[].address')

  scp -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ca.pem ${instance}-key.pem ${instance}.pem root@${external_ip}:~/
done

for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label "$instance" --json | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list "$instance_id" --json | jq -r '.[].ipv4.public | .[].address')

  scp -i kubernetes.ed25519 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem root@${external_ip}:~/
done

