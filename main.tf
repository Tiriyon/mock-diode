
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

# -----------------------------------------------------------------------
# Docker Network
# -----------------------------------------------------------------------

resource "docker_network" "diode_net" {
  name = "zabbix-diode-net"
  ipam_config {
    subnet = "172.28.0.0/16"
  }
}

# -----------------------------------------------------------------------
# Images
# -----------------------------------------------------------------------

resource "docker_image" "zabbix_server" {
  name = "zabbix/zabbix-server-pgsql:alpine-latest"
}

resource "docker_image" "zabbix_agent" {
  name = "zabbix/zabbix-agent2:alpine-latest"
}

resource "docker_image" "postgres" {
  name = "postgres:15-alpine"
}

# -----------------------------------------------------------------------
# Containers
# -----------------------------------------------------------------------

resource "docker_container" "postgres" {
  name  = "zabbix-postgres"
  image = docker_image.postgres.name
  networks_advanced {
    name         = docker_network.diode_net.name
    ipv4_address = "172.28.0.3"
  }
  env = [
    "POSTGRES_USER=zabbix",
    "POSTGRES_PASSWORD=zabbixpass",
    "POSTGRES_DB=zabbix"
  ]
}

resource "docker_container" "zabbix_server" {
  name       = "site-a-zabbix-server"
  image      = docker_image.zabbix_server.name
  depends_on = [docker_container.postgres]
  networks_advanced {
    name         = docker_network.diode_net.name
    ipv4_address = "172.28.0.2"
  }

  env = [
    "DB_SERVER_HOST=zabbix-postgres",
    "POSTGRES_USER=zabbix",
    "POSTGRES_PASSWORD=zabbixpass",
    "TLS_PSK_FILE=/etc/zabbix/psk/zabbix_agent.psk",
    "TLS_PSK_ID=PSK001"
  ]

  mounts {
    target    = "/etc/zabbix/psk"
    source    = abspath("${path.module}/tls")
    type      = "bind"
    read_only = true
  }
}

resource "docker_container" "zabbix_agent" {
  name  = "site-b-agent"
  image = docker_image.zabbix_agent.name
  networks_advanced {
    name         = docker_network.diode_net.name
    ipv4_address = "172.28.0.5"
  }

  env = [
    "ZBX_SERVER_HOST=172.28.0.2",
    "ZBX_ACTIVE_CHECKS=1",
    "ZBX_HOSTNAME=Site-B-Host",
    "TLSConnect=psk",
    "TLSAccept=psk",
    "TLS_PSK_FILE=/etc/zabbix/psk/zabbix_agent.psk",
    "TLS_PSK_ID=PSK001"
  ]

  mounts {
    target    = "/etc/zabbix/psk"
    source    = abspath("${path.module}/tls")
    type      = "bind"
    read_only = true
  }
}
