output "ip_address" {
  description = "External IP address for routing RTMP traffic"
  value = aws_eip.ip_address.public_ip
}