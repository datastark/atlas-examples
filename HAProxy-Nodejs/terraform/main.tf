provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-east-1"
}

//
// ARTIFACTS
//
resource "atlas_artifact" "nodejs" {
  name = "${var.atlas_username}/nodejs"
  type = "amazon.ami"
}

resource "atlas_artifact" "haproxy" {
  name = "${var.atlas_username}/haproxy"
  type = "amazon.ami"
}

resource "atlas_artifact" "consul" {
  name = "${var.atlas_username}/consul"
  type = "amazon.ami"
}

//
// TEMPLATES
//
resource "template_file" "consul_upstart" {
  filename = "files/consul.sh"

  vars {
    atlas_user_token = "${var.atlas_user_token}"
    atlas_username = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    consul_server_count = "${var.consul_server_count}"
    }
}

//
// NETWORKING
//
module "vpc" {
  source = "./vpc"
}

resource "aws_security_group" "haproxy" {
  name = "haproxy"
  vpc_id = "${module.vpc.vpc_id}"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // allow traffic for SSH
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // connect to scada
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//
// INSTANCES
//
resource "aws_instance" "consul" {
  instance_type = "t2.micro"
  ami = "${atlas_artifact.consul.metadata_full.region-us-east-1}"
  user_data = "${template_file.consul_upstart.rendered}"
  key_name = "${var.key_name}"
  count = "${var.consul_server_count}"

  vpc_security_group_ids = ["${aws_security_group.haproxy.id}"]
  subnet_id = "${module.vpc.subnet_id}"

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_instance" "nodejs" {
  instance_type = "t2.micro"
  ami = "${atlas_artifact.nodejs.metadata_full.region-us-east-1}"
  user_data = "${template_file.consul_upstart.rendered}"
  key_name = "${var.key_name}"
  count = 2

  vpc_security_group_ids = ["${aws_security_group.haproxy.id}"]
  subnet_id = "${module.vpc.subnet_id}"

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_instance" "haproxy" {
  instance_type = "t2.micro"
  ami = "${atlas_artifact.haproxy.metadata_full.region-us-east-1}"
  user_data = "${template_file.consul_upstart.rendered}"
  key_name = "${var.key_name}"
  count = 1

  vpc_security_group_ids = ["${aws_security_group.haproxy.id}"]
  subnet_id = "${module.vpc.subnet_id}"

  lifecycle = {
    create_before_destroy = true
  }
}

output "haproxy_address" {
    value = "${aws_instance.haproxy.public_ip}"
}
