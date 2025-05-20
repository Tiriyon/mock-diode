set shell := ["bash", "-cu"]

# Initialize Terraform and pull images
init:
	terraform init

# Apply Terraform and deploy the environment
deploy:
	terraform apply -auto-approve

# Simulate the data diode by dropping output from server to agent
simulate-diode:
	docker exec site-a-zabbix-server iptables -A OUTPUT -d 172.28.0.5 -j DROP

# Tail logs of Zabbix agent
logs-agent:
	docker logs -f site-b-agent

# Tear down everything
destroy:
	terraform destroy -auto-approve


generate-psk:
	mkdir -p tls
	openssl rand -hex 32 > tls/zabbix_agent.psk
	echo "PSK001" > tls/zabbix_agent.psk_id
