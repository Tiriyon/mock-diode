set shell := ["bash", "-cu"]

# Initialize Terraform and pull images
init:
	terraform init

# Apply Terraform and deploy the environment
deploy:
	terraform apply -auto-approve

# Simulate the data diode by dropping output from server to agent
simulate-diode:
	sudo iptables -A DOCKER-USER -s 172.28.0.2 -d 172.28.0.5 -j DROP

# Tail logs of Zabbix agent
logs-agent:
	docker logs -f site-b-agent
# Tail logs of Zabbix server
logs-server:
	docker logs -f site-a-zabbix-server


# Tear down everything
destroy:
	terraform destroy -auto-approve


# Generate key and identity for PSK
generate-psk:
	mkdir -p tls
	openssl rand -hex 32 > tls/zabbix_agent.psk
	echo "PSK001" > tls/zabbix_agent.psk_id

# Set Autoregistration of agents
autoregister:
    bash ./scripts/autoregister.sh

# Sample connection 
sample-agent:
	sudo tcpdump -i any host 172.28.2.10 and port 10051 -nn -X

# Sample Server connection to agent
sample-server:
	docker exec site-a-zabbix-server nc -zv -w 5 172.28.2.5 10050 || echo "BLOCKED ✅"
