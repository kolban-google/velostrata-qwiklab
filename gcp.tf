provider "google" {
}

// Create the GCP public IP address for the VPN at GCP.
resource "google_compute_address" "gcp-vpn-ip" {
	name   = "qwiklab"
	region = "us-central1"
}


resource "google_compute_vpn_gateway" "gcp-vpn-gw" {
  name    = "qwiklab"
  network = "default"
  region  = "us-central1"
}

resource "google_compute_forwarding_rule" "vpn_esp" {
  name        = "vpn-esp"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.gcp-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.gcp-vpn-gw.self_link}"
  region = "us-central1"
}

resource "google_compute_forwarding_rule" "vpn_udp500" {
  name        = "${google_compute_vpn_gateway.gcp-vpn-gw.name}-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = "${google_compute_address.gcp-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.gcp-vpn-gw.self_link}"
  region = "us-central1"
}

resource "google_compute_forwarding_rule" "vpn_udp4500" {
  name        = "${google_compute_vpn_gateway.gcp-vpn-gw.name}-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = "${google_compute_address.gcp-vpn-ip.address}"
  target      = "${google_compute_vpn_gateway.gcp-vpn-gw.self_link}"
  region = "us-central1"
}

resource "google_compute_vpn_tunnel" "gcp-tunnel1" {
  name          = "qwiklab"
  peer_ip       = "${aws_vpn_connection.aws-vpn-connection1.tunnel1_address}"
  shared_secret = var.preshared_key
  ike_version   = 1

  target_vpn_gateway = "${google_compute_vpn_gateway.gcp-vpn-gw.self_link}"
  remote_traffic_selector = ["10.0.0.0/16"]

    depends_on = [
    google_compute_forwarding_rule.vpn_esp,
    google_compute_forwarding_rule.vpn_udp500,
    google_compute_forwarding_rule.vpn_udp4500,
  ]
}

resource "google_compute_route" "qwiklab" {
	name = "qwiklab"
	network = "default"
	dest_range = "10.0.0.0/16"
	priority = 1000
	next_hop_vpn_tunnel = "${google_compute_vpn_tunnel.gcp-tunnel1.self_link}"
}

/*
 * Create the firewall rules.
 */
resource "google_compute_firewall" "https" {
  name    = "https"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "AWS" {
  name    = "aws"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }
  direction = "INGRESS"
  source_ranges = ["10.0.0.0/16"]
}
