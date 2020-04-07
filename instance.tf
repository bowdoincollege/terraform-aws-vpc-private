data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*x86_64-ebs"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    cidr_blocks = ["139.140.0.0/16"]
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
  }
}

resource "aws_iam_instance_profile" "test" {
  name = "ec2-instance-profile"
  role = "EC2SSM"
}

resource "aws_instance" "test" {
  ami                         = data.aws_ami.amazon_linux_2.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private["a"].id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  # tflint-ignore: aws_instance_invalid_key_name
  key_name             = "vpgtest1"
  iam_instance_profile = aws_iam_instance_profile.test.id
}
