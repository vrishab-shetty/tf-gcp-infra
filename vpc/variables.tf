#VPC
variable "region" {
  type = string
}

variable "name" {
  type = string
}

variable "webapp_ip_cidr" {
  type = string
}

variable "db_ip_cidr" {
  type = string
}

variable "routing_mode" {
  type = string
}
