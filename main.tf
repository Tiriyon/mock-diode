terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

# -----------------------------
# Networks
# -----------------------------

resource "docker_network" "site_a_net" {
  name = "site-a-net"
  ipam_config {
    subnet = "172.28.1.0/24"
  }
}

resource "docker_network" "site_b_net" {
  name = "site-b-net"
  ipam_config {
    subnet = "172.28.2.0/24"
  }
}

# -----------------------------
# Images
# -----------------------------

resource "docker_image" "zabbix_server" {
  name = "zabbix/zabbix-server-pgsql:alpine-latest"
}

resource "docker_image" "zabbix_agent" {
  name = "zabbix/zabbix-agent2:alpine-latest"
}

resource "docker_image" "postgres" {
  name = "postgres:15-alpine"
}

resource "docker_image" "zabbix_web" {
  name = "zabbix/zabbix-web-nginx-pgsql:alpine-latest"
}

resource "docker_image" "socat" {
  name = "alpine/socat"
}

# -----------------------------
# Containers
# -----------------------------

resource "docker_container" "postgres" {
  name  = "zabbix-postgres"
  image = docker_image.postgres.name
  networks_advanced {
    name         = docker_network.site_a_net.name
    ipv4_address = "172.28.1.3"
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
    name         = docker_network.site_a_net.name
    ipv4_address = "172.28.1.2"
  }

  env = [
    "DB_SERVER_HOST=zabbix-postgres",
    "POSTGRES_USER=zabbix",
    "POSTGRES_PASSWORD=zabbixpass",
    "POSTGRES_DB=zabbix",
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

resource "docker_container" "zabbix_frontend" {
  name       = "site-a-frontend"
  image      = docker_image.zabbix_web.name
  depends_on = [docker_container.zabbix_server]
  networks_advanced {
    name         = docker_network.site_a_net.name
    ipv4_address = "172.28.1.4"
  }
  ports {
    internal = 8080
    external = 8082
  }
  env = [
    "ZBX_SERVER_HOST=site-a-zabbix-server",
    "DB_SERVER_HOST=zabbix-postgres",
    "DB_SERVER_PORT=5432",
    "DB_SERVER_DBNAME=zabbix",
    "POSTGRES_USER=zabbix",
    "POSTGRES_PASSWORD=zabbixpass",
    "PHP_TZ=UTC"
  ]
}

resource "docker_container" "socat_relay" {
  name       = "socat-relay"
  image      = docker_image.socat.name
  entrypoint = ["/bin/sh", "-c"]
  command = [
    "while true; do socat TCP-LISTEN:10051,fork,reuseaddr TCP:172.28.1.2:10051; done"
  ]
  networks_advanced {
    name         = docker_network.site_b_net.name
    ipv4_address = "172.28.2.10"
  }
  networks_advanced {
    name         = docker_network.site_a_net.name
    ipv4_address = "172.28.1.10"
  }
}

resource "docker_container" "zabbix_agent" {
  name  = "site-b-agent"
  image = docker_image.zabbix_agent.name
  networks_advanced {
    name         = docker_network.site_b_net.name
    ipv4_address = "172.28.2.5"
  }

  env = [
    "ZBX_SERVER_HOST=172.28.2.10",
    "ZBX_ACTIVE_CHECKS=1",
    "ZBX_HOSTNAME=Site-B-Host",
    "ZBX_HOST_METADATA=Site-B-Host",
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
