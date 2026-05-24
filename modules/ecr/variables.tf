variable "name_prefix" {
  type = string
}

variable "image_count_to_keep" {
  type    = number
  default = 10
}

variable "kms_key_arn" {
  type = string
}
