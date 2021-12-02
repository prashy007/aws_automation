
#Created private subnet in default VPC. Also created NAT and associated it with private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = var.vpc_id
  cidr_block = "172.31.112.0/20"   #This is test CIDR used for testing. Kindly replace it as per VPC CIDR
  tags = {
    Name = "Private subnet"
  }
}
resource "aws_eip" "nat-ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = var.subnet_id
}

resource "aws_route_table" "private_rtb" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rtb.id
}

#Creating Security group

resource "aws_security_group" "prod-web-servers-sg" {
  name        = "prod-web-servers-sg"
  description = "Allow HTTP and HTTPS"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 443
    protocol         = "HTTPS"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    from_port        = 0
    to_port          = 80
    protocol         = "HTTP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#Dynamically fetching latest AMI
data "aws_ami" "amazon_linux_2" {
 most_recent = true

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }

 filter {
   name = "architecture"
   values = ["x86_64"]
 }
owners = ["137112412989"] #Amazon
}

#Creating both Ec2 instances
resource "aws_instance" "prod-web-server-1" {
    ami           = data.aws_ami.amazon_linux_2.id
    instance_type = "t3.large" 
    vpc_security_group_ids = [aws_security_group.prod-web-servers-sg.id]
    subnet_id              = aws_subnet.private_subnet.id
    tags = {
        Name = "prod-web-server-1"
    }
}

resource "aws_instance" "prod-web-server-2" {
    ami           = data.aws_ami.amazon_linux_2.id
    instance_type = "t3.large" 
    vpc_security_group_ids = [aws_security_group.prod-web-servers-sg.id]
    subnet_id              = aws_subnet.private_subnet.id
    tags = {
        Name = "prod-web-server-2"
    }
}

#Creating NLB
resource "aws_lb" "nlb" {
  name               = "web-load-balancer"
  internal           = false
  load_balancer_type = "network"
  subnets            = [var.subnet_id]
  tags = {
    Environment = "production"
  }
}

#Creating target group and attaching both ec2
resource "aws_lb_target_group" "nlb_target" {
  name     = "nlb-targetgroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.nlb_target.arn
  target_id        = aws_instance.prod-web-server-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.nlb_target.arn
  target_id        = aws_instance.prod-web-server-2.id
  port             = 80
}

#creating NLB listener for port 443 and 80. Also making redirect for port 80
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TLS"
  certificate_arn   = "arn:aws:iam::xxxxxxxx:server-certificate/test_cert_xxxxxxxxxx"
  alpn_policy       = "HTTP2Preferred"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target.arn
  }
}

resource "aws_lb_listener" "front_end_http" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}