#Replace with default vpc ID
variable "vpc_id" {
  default= "vpc-xxxxxxx"
}


#Replace with default aws region
variable "regions" {
  default = "us-east-1"
}


#Replace this with public subnet id from default vpc
variable "subnet_id" {
  default = "subnet-xxxxxxxx"
}
