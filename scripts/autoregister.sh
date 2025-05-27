#!/usr/bin/env bash

set -euo pipefail

ZBX_API=http://localhost:8082/api_jsonrpc.php
ZBX_USER="Admin"
ZBX_PASS="zabbix"
PSK_ID=$(<./tls/zabbix_agent.psk_id)
PSK_KEY=$(<./tls/zabbix_agent.psk)

echo "Authenticating with Zabbix API..."

AUTH_TOKEN=$(curl -s -X POST "$ZBX_API" \
  -H "Content-Type: application/json-rpc" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"user.login\",
    \"params\": {
      \"username\": \"$ZBX_USER\",
      \"password\": \"$ZBX_PASS\"
    },
    \"id\": 1
  }" | jq -r .result)

if [[ "$AUTH_TOKEN" == "null" || -z "$AUTH_TOKEN" ]]; then
  echo "Failed to authenticate with Zabbix API"
  exit 1
fi

echo "Authenticated. Token: $AUTH_TOKEN"

echo " Creating autoregistration action..."

RESPONSE=$(curl -s -X POST "$ZBX_API" \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"action.create\",
    \"params\": {
      \"name\": \"Auto-Register Linux\",
      \"eventsource\": \"2\",
      \"status\": 0,
      \"filter\": {
        \"evaltype\": \"2\",
        \"conditions\": [
          {
            \"conditiontype\": \"22\",
            \"operator\": \"2\",
            \"value\": \"Site-B\"
          }
        ]
      },
      \"operations\": [
        {
          \"operationtype\": \"4\",
          \"opgroup\": [{ \"groupid\": \"2\" }]
        },
        {
          \"operationtype\": \"6\",
          \"optemplate\": [{ \"templateid\": \"10001\" }]
        }      ]
    },
    \"id\": 1
  }")
echo "$RESPONSE" | jq

ACTION_ID=$(echo "$RESPONSE" | jq -r .result.actionids[0])
echo "Created autoregistration action with ID: $ACTION_ID"

echo "Applying global TLS PSK policy for autoregistration..."

curl -s -X POST "$ZBX_API" \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"autoregistration.update\",
    \"params\": {
      \"tls_accept\": \"3\",
      \"tls_psk_identity\": \"$PSK_ID\",
      \"tls_psk\": \"$PSK_KEY\"
    },
    \"id\": 3
  }" | jq

echo "PSK-based TLS authentication configured for autoregistration."
