terraform {
  backend "s3" {
    bucket         = "sbennett-infra"
    key            = "terraform.state"
    region         = "ap-southeast-2"
    dynamodb_table = "sbennett-infra-db"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_iam_instance_profile" "terraform_state" {
  name = "terraform_state_profile"
  role = aws_iam_role.terraform_state.name
}

resource "aws_iam_role" "terraform_state" {
  name = "terraform_state_role"
  description = "Role for CI machine to apply terraform state"
  path = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_state_attach" {
  role       = aws_iam_role.terraform_state.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = <<EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": { "Service": "vmie.amazonaws.com" },
              "Action": "sts:AssumeRole",
              "Condition": {
                  "StringEquals":{
                      "sts:Externalid": "vmimport"
                  }
              }
          }
      ]
  }
EOF
}

resource "aws_iam_role_policy" "vmimport_policy" {
  name   = "vmimport"
  role   = aws_iam_role.vmimport.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::sbennett-infra/amis",
        "arn:aws:s3:::sbennett-infra/amis/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetBucketAcl"
      ],
      "Resource": [
        "arn:aws:s3:::sbennett-infra/amis",
        "arn:aws:s3:::sbennett-infra/amis/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:ModifySnapshotAttribute",
        "ec2:CopySnapshot",
        "ec2:RegisterImage",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
    }
EOF
}

resource "aws_ebs_snapshot_import" "nixos_base_ami" {
  disk_container {
    format = "VHD"
    user_bucket {
      s3_bucket = "sbennett-infra"
      s3_key    = "amis/base.vhd"
    }
  }

  role_name = aws_iam_role.vmimport.name

  tags = {
    Name = "NixOS"
  }
}

resource "aws_ami" "nixos_base_ami" {
  name                = "nixos_base_ami"
  architecture        = "x86_64"
  virtualization_type = "hvm"
  root_device_name    = "/dev/xvda"
  ena_support         = true
  sriov_net_support   = "simple"

  ebs_block_device {
    device_name           = "/dev/xvda"
    snapshot_id           = aws_ebs_snapshot_import.nixos_base_ami.id
    volume_size           = 40
    delete_on_termination = true
    volume_type           = "gp3"
  }
}

resource "aws_instance" "server" {
  ami             = aws_ami.nixos_base_ami.id # Provisioned with our AMI
  instance_type   = "t3.nano"
  security_groups = ["default"]

  root_block_device {
    volume_size = 250 # GiB
  }

  tags = {
    Name = "Server"
  }
}

resource "aws_eip" "server" {
  instance = aws_instance.server.id
  vpc      = true
}

resource "aws_security_group_rule" "inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-e9d1cb9b" # default security group

  description = "Allow all incoming SSH traffic"
}

output "public_ip_server" {
  value = aws_eip.server.public_ip
}
