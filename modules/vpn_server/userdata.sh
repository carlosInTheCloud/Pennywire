#!/bin/bash
set -ex

# Wait for network
sleep 15

# Update and install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wireguard awscli iptables jq wget curl

# Download and install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent to stream syslog
cat <<'EOF' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 300
  },
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "InstanceId": "$${aws:InstanceId}"
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/vpn-server/syslog",
            "log_stream_name": "{instance_id}-syslog"
          }
        ]
      }
    }
  }
}
EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

# Fetch Instance Metadata (IMDSv2)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

# Reassociate Elastic IP
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${EIP_ALLOCATION_ID} --region ${REGION} --allow-reassociation

# Configure WireGuard
mkdir -p /etc/wireguard
cd /etc/wireguard

# Fetch Private Key from SSM
SERVER_PRIV_KEY=$(aws ssm get-parameter --name "/vpn-server/${REGION}/wireguard-private-key" --with-decryption --region ${REGION} --query "Parameter.Value" --output text)

# Get primary network interface for iptables rules
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

cat <<EOF > /etc/wireguard/wg0.conf.base
[Interface]
Address = 10.8.0.1/24
ListenPort = ${WG_PORT}
PrivateKey = $SERVER_PRIV_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
EOF

# Append Terraform Static Clients to Base Config
IFS=',' read -ra ADDR <<< "${CLIENT_PUB_KEYS}"
CLIENT_IP=2
for PUB_KEY in "$${ADDR[@]}"; do
  if [ -n "$PUB_KEY" ]; then
    cat <<EOF >> /etc/wireguard/wg0.conf.base

[Peer]
PublicKey = $PUB_KEY
AllowedIPs = 10.8.0.$CLIENT_IP/32
EOF
    CLIENT_IP=$((CLIENT_IP+1))
  fi
done

# Initial config copy
cp /etc/wireguard/wg0.conf.base /etc/wireguard/wg0.conf

# Enable and start WireGuard
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service

# Publish Server Info to DynamoDB for the Web App
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)
EIP=$(curl -H "X-aws-ec2-metadata-token: $(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)" -s http://169.254.169.254/latest/meta-data/public-ipv4)
aws dynamodb put-item --table-name "vpn-clients-${REGION}" --region "${REGION}" \
  --item '{"PublicKey": {"S": "SERVER_INFO"}, "ServerPubKey": {"S": "'"$SERVER_PUB_KEY"'"}, "ServerIp": {"S": "'"$EIP"'"}}'

# Create DynamoDB Sync Script
cat <<'EOF' > /usr/local/bin/wg-sync.sh
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
TABLE_NAME="vpn-clients-${REGION}"

KEYS_AND_IPS=$(aws dynamodb scan --table-name $TABLE_NAME --projection-expression "PublicKey, ClientIp" --region $REGION --output text --query 'Items[*].[PublicKey.S, ClientIp.S]' | tr '\t' ',')

PEERS_FILE=$(mktemp)
for ROW in $KEYS_AND_IPS; do
  if [[ "$ROW" == *","* ]]; then
    KEY=$(echo $ROW | cut -d',' -f1)
    IP=$(echo $ROW | cut -d',' -f2)
    if [ "$KEY" != "None" ] && [ "$KEY" != "SERVER_INFO" ] && [ -n "$KEY" ]; then
      echo "[Peer]" >> $PEERS_FILE
      echo "PublicKey = $KEY" >> $PEERS_FILE
      echo "AllowedIPs = $IP/32" >> $PEERS_FILE
      echo "" >> $PEERS_FILE
    fi
  fi
done

cat /etc/wireguard/wg0.conf.base $PEERS_FILE > /etc/wireguard/wg0.conf
rm $PEERS_FILE

wg syncconf wg0 <(wg-quick strip wg0)
EOF
chmod +x /usr/local/bin/wg-sync.sh

# Add sync script to cron (runs every 10 minutes)
echo "*/10 * * * * root /usr/local/bin/wg-sync.sh >> /var/log/syslog 2>&1" > /etc/cron.d/wg-sync

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
