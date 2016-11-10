provider "aws" {
  region = "${var.region}"
  alias  = "${var.region}"
}

resource "aws_instance" "nomad_server" {
  provider      = "aws.${var.region}"
  ami           = "${lookup(var.ami, join("-",list( var.region, var.platform)))}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index % length(split(",", var.subnet_ids)))}"
  count         = "${var.servers}"

  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.nomad.id}"]

  connection {
    user = "${lookup(var.user, var.platform)}"
    private_key = "${file(var.private_key)}"
  }

  #Instance tags
  tags {
    Name = "${var.name}-${element(split(",", var.zones), count.index % length(split(",", var.zones)))}-${count.index + 1}"
    Type    = "${var.name}"
    Zone    = "${element(split(",", var.zones), count.index % length(split(",", var.zones)))}"
    Machine = "${var.instance_type}"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.disk_size}"
  }

  provisioner "file" {
    source = "${path.module}/../shared/scripts/${lookup(var.service_conf, var.platform)}"
    destination = "/tmp/${lookup(var.service_conf_dest, var.platform)}"
  }

  provisioner "file" {
    source = "${path.module}/../shared/scripts/${lookup(var.consul_service_conf, var.platform)}"
    destination = "/tmp/${lookup(var.consul_service_conf_dest, var.platform)}"
  }

  provisioner "file" {
    source = "${path.module}/../shared/scripts/nomad-plan.sh"
    destination = "/tmp/nomad-plan.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ${element(split(",", var.consul_ips), 0)} > /tmp/consul-server-addr",
      "echo ${var.servers} > /tmp/nomad-server-count",
      "sudo mkdir -p /opt/nomad/bin",
      "sudo mv /tmp/nomad-plan.sh /opt/nomad/bin",
      "sudo chmod +x /opt/nomad/bin/nomad-plan.sh"
    ]
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/../shared/scripts/dependencies.sh",
      "${path.module}/../shared/scripts/install_consul.sh",
      "${path.module}/../shared/scripts/install.sh",
      "${path.module}/../shared/scripts/service.sh",
      "${path.module}/../shared/scripts/ip_tables.sh",
    ]
  }
}

resource "aws_security_group" "nomad" {
  provider    = "aws.${var.region}"
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Nomad internal traffic + maintenance."


  tags { Name = "${var.name}" }

  // These are for internal traffic
  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    self = true
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "udp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  // These are for maintenance
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // This is for outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "nomad_jobs" {
  depends_on = ["aws_instance.nomad_server"]
  count      = "${var.servers}"

  triggers {
    private_ips = "${join(",", aws_instance.nomad_server.*.private_ip)}"
    data        = "${var.nomad_jobs}"
  }

  connection {
    user = "${lookup(var.user, var.platform)}"
    private_key = "${file(var.private_key)}"
    host        = "${element(aws_instance.nomad_server.*.public_ip, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/nomad/jobs",
      "sudo chown -R ${lookup(var.user, var.platform)} /opt/nomad/jobs",
      "${var.nomad_jobs}"
    ]
  }
}