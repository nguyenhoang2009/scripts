#!/usr/bin/env bash
set -ex
# only on debian atm
which apt

# set this to your own url
LOKI_URL="http://192.168.0.4:3100"

PROMTAIL_USER="promtail"
PROMTAIL_VERSION="1.6.1"
HOSTNAME=$(hostname)

create_user(){
 useradd --no-create-home --shell /bin/false ${PROMTAIL_USER}
}

if [ $(id -u ${PROMTAIL_USER} > /dev/null 2>&1 ; echo $?) = 0 ]
  then
    echo "${PROMTAIL_USER} user exists"
  else
    echo "${PROMTAIL_USER} user does not exist, creating.."
    create_user
fi

apt update && apt install unzip -y
wget https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
rm -rf promtail-linux-amd64.zip

mkdir -p /var/lib/promtail /etc/promtail
chown -R ${PROMTAIL_USER}:${PROMTAIL_USER} /var/lib/promtail /etc/promtail

cat > /etc/systemd/system/promtail.service << EOF
[Unit]
Description=Promtail
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail/promtail-config.yml

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/promtail/promtail-config.yml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
  - job_name: journal
    journal:
      max_age: 12h
      path: /var/log/journal
      labels:
        job: systemd-journal
        env: production
        host: $HOSTNAME
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
EOF

systemctl daemon-reload
systemctl start promtail
systemctl enable promtail
