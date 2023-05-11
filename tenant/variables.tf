## VCD
variable "vcd_user" {}
variable "vcd_pass" {}
variable "vcd_url" {}

variable "vcd_allow_unverified_ssl" {
  default = true
}

variable "vcd_max_retry_timeout" {
  default = 60
}