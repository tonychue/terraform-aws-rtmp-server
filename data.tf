# Latest Ubuntu 18.04 ami instance for region
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = ["099720109477", "513442679011"] # Canonical
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data/user_data.sh")}"

  vars = {
    NGINX_VERSION               = var.nginx_version
    NGINX_RTMP_MODULE_VERSION= var.nginx_rtmp_version
    NGINX_CONF_PATH="/etc/nginx/nginx.conf"
    STUNNEL_CONF="/etc/stunnel/stunnel.conf"
    STUNNEL_DEBUG="7"
    STUNNEL_CLIENT="no"
    STUNNEL_CAFILE="/etc/ssl/certs/ca-certificates.crt"
    STUNNEL_VERIFY_CHAIN="no"
    STUNNEL_OPENSSL_CONF="/etc/stunnel/openssl.cnf"
    STUNNEL_KEY="/etc/stunnel/stunnel.key"
    STUNNEL_CRT="/etc/stunnel/stunnel.pem"
    STUNNEL_DELAY="no"
    YOUTUBE_KEY                = var.youtube_key
    FACEBOOK_KEY                = var.facebook_key
  }
}

data "cloudinit_config" "cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud_init.txt"
    content_type = "text/x-shellscript"
    content      = data.template_file.user_data.rendered
  }
}
