variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "project_tags" {
  description = "Project tags to be used to track costs."
  type        = map(string)
  default = {
    Name       = "RTMP-Restreamer"
    Owner      = "Will Hall Online"
    Purpose    = "Live streaming"
  }
}

variable "key_name" {
  type    = string
  default = "keyname"
}

variable "nginx_version" {
  description = "Version of nginx for installation (nginx-*)."
  type = string
  default = "nginx-1.18.0"
}

variable "nginx_rtmp_version" {
  description = "RTMP Module for nginx installation version https://github.com/arut/nginx-rtmp-module"
  type = string
  default = "1.2.1"
}

variable "youtube_key" {
  description = "YouTube RTMP Stream Key"
  type = string
}

variable "facebook_key" {
  description = "Facebook RTMP Stream Key"
  type = string
}
