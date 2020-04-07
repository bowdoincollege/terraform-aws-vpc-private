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

resource "aws_iam_instance_profile" "test" {
  name = "ec2-instance-profile"
  role = aws_iam_role.this.name
}

resource "aws_iam_role" "this" {
  name = "test_instance"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "ssm" {
  name   = "test-ssm-agent-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.ssm.json
}

data "aws_iam_policy_document" "ssm" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:GetManifest",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetEncryptionConfiguration",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstanceStatus",
    ]

    resources = ["*"]
  }
}
