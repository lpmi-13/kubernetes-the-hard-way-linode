ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for instance in controller-0 controller-1 controller-2; do
  instance_id=$(linode-cli linodes list --label ${instance} --json \
    | jq -r '.[].id')
  external_ip=$(linode-cli linodes ips-list ${instance_id} \
    --json | jq -r '.[].ipv4.public | .[].address')
  
  scp -i kubernetes.id_rsa \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  encryption-config.yaml root@${external_ip}:~/
done

