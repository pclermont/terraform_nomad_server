output "names" {
  value = "${join(",", aws_instance.nomad_server.*.id)}"
}

output "private_ips" {
  value = "${join(",", aws_instance.nomad_server.*.private_ip)}"
}

output "public_ips"  {
  value = "${join(",", aws_instance.nomad_server.*.public_ip)}"
}