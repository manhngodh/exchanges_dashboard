# main.tf

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {}
variable "region" {
  default = "asia-east1"
}
variable "zone" {
  default = "asia-east1-a"
}

resource "google_secret_manager_secret" "api_key" {
  secret_id = "binance_readonly_api_key"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "api_secret" {
  secret_id = "binance_readonly_api_secret"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "api_key_version" {
  secret = google_secret_manager_secret.api_key.id
  secret_data = var.api_key
}

resource "google_secret_manager_secret_version" "api_secret_version" {
  secret = google_secret_manager_secret.api_secret.id
  secret_data = var.api_secret
}

data "google_secret_manager_secret_version" "api_key" {
  secret = google_secret_manager_secret.api_key.id
  version = "latest"
}

data "google_secret_manager_secret_version" "api_secret" {
  secret = google_secret_manager_secret.api_secret.id
  version = "latest"
}

resource "google_compute_instance" "default" {
  name         = "exchanges-dashboard-instance"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    # Update and install required packages
    apt-get update
    apt-get install -y git docker.io
    # Clone the repository
    git clone https://github.com/HawkeyeBot/exchanges_dashboard.git /home/exchanges_dashboard
    # Install gcloud SDK and authenticate
    apt-get install -y google-cloud-sdk
    gcloud auth application-default login
    # Retrieve secrets
    API_KEY=$(gcloud secrets versions access latest --secret=exchanges_dashboard_api_key)
    API_SECRET=$(gcloud secrets versions access latest --secret=exchanges_dashboard_api_secret)
    # Create config.json
    cat <<EOT > /home/exchanges_dashboard/config.json
    {
      "api_key": "$${API_KEY}",
      "api_secret": "$${API_SECRET}"
    }
    EOT
    # Change directory
    cd /home/exchanges_dashboard
    # Start your application
    docker-compose up -d
  EOF
}

output "instance_ip" {
  value = google_compute_instance.default.network_interface[0].access_config[0].nat_ip
}