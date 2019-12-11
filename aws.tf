//
// Our goal here is to create the following:
// o AWS VPC
// o AWS Subnet
// o AWS Virtual Private Gateway
// o AWS Customer Gateway
//   - Needs GCP IP address of GCP VPN
// o AWS VPN Connection
//   - Needs the AWS Customer Gateway
//   - Needs the AWS Virtual Private Gateway
//   - Needs the pre-shared key variable
// o AWS Static route back to GCP
//   - Needs the AWS VPN Connection
// o AWS EC2 Instance
//
// See also:
// Automated Network Deployment: Building a VPN Between GCP and AWS - https://cloud.google.com/solutions/automated-network-deployment-multicloud
// IPsec VPN Between GCP and AWS - https://github.com/kaysal/terraform-multi-cloud/tree/master/gcp-aws-vpn

variable "preshared_key" {
	type = string
}

variable "key_pair_name" {
	type = string
}

provider "aws" {
	region = "us-east-1"
}

// Create an AWS VPC
resource "aws_vpc" "qwiklab" {
	cidr_block = "10.0.0.0/16"
	tags = {
		Name = "QwikLab"
	}
}

// Create an AWS Subnet
resource "aws_subnet" "qwiklab" {
	vpc_id = "${aws_vpc.qwiklab.id}"
	cidr_block = "10.0.0.0/24"
	tags = {
		Name = "QwikLab"
	}
}

resource "aws_internet_gateway" "qwiklab" {
	vpc_id = "${aws_vpc.qwiklab.id}"
	tags = {
		Name = "QwikLab"
	}
}

// Create the Virtual Private Gateway
resource "aws_vpn_gateway" "qwiklab" {
	vpc_id = "${aws_vpc.qwiklab.id}"
	tags = {
		Name = "QwikLab"
	}
}

// Create the Customer Gateway
resource "aws_customer_gateway" "aws-cgw" {
	bgp_asn    = 65000
	ip_address = "${google_compute_address.gcp-vpn-ip.address}"
	type       = "ipsec.1"
	tags = {
		Name = "QwikLab"
	}
}

// Create the VPN Connection
resource "aws_vpn_connection" "aws-vpn-connection1" {
	vpn_gateway_id      = "${aws_vpn_gateway.qwiklab.id}"
	customer_gateway_id = "${aws_customer_gateway.aws-cgw.id}"
	type                = "ipsec.1"
	static_routes_only  = true
	tunnel1_preshared_key = var.preshared_key
	tags = {
		Name = "QwikLab"
	}  
}

resource "aws_vpn_connection_route" "gcp_route" {
	destination_cidr_block = "10.128.0.0/20"
	vpn_connection_id = "${aws_vpn_connection.aws-vpn-connection1.id}"
}

resource "aws_instance" "sample-vm" {
	instance_type = "t2.micro"
	ami = "ami-07d0cf3af28718ef8"
	subnet_id = "${aws_subnet.qwiklab.id}"
	associate_public_ip_address = true
	key_name = var.key_pair_name
	tags = {
		Name = "sample-vm"
	}
}

resource "aws_route" "qwiklab_vpn" {
    route_table_id = "${aws_vpc.qwiklab.main_route_table_id}"
    destination_cidr_block = "10.128.0.0/20"
    gateway_id = "${aws_vpn_gateway.qwiklab.id}"
}

resource "aws_route" "qwiklab_internet" {
    route_table_id = "${aws_vpc.qwiklab.main_route_table_id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.qwiklab.id}"
}

/*
data "aws_security_group" "default" {
  name = "default"
}

resource "aws_security_group_rule" "allow_all" {
	type = "ingress"
	from_port = 0
	to_port = 65535
	cidr_blocks = "0.0.0.0/0"
	protocol = "all"
	security_group_id = "${aws_security_group.default.id}"
}
*/

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.qwiklab.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
	cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_group" "qwiklab" {
  name = "VelosMgrGroup"
  path = "/VelostrataMgr/"
}

resource "aws_iam_group_policy" "qwiklab" {
  name  = "VelosMgrGroupPolicy"
  group = "${aws_iam_group.qwiklab.id}"

  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement" : [
	{
	    "Resource" : "*",
    	"Action" : [
			"ec2:RunInstances",
			"ec2:StartInstances",
			"ec2:StopInstances",
			"ec2:RebootInstances",
			"ec2:AttachVolume",
			"ec2:DetachVolume",
			"ec2:Describe*",
			"ec2:CreateTags",
			"ec2:GetConsoleOutput",
			"ec2:ModifyInstanceAttribute"
		],
		"Effect" : "Allow"
	},
	{
		"Condition" : {
			"StringEquals" : {
				"ec2:ResourceTag/ManagedByVelostrata" : "Yes"
			}
		},
		"Resource" : "*",
		"Action" : "ec2:TerminateInstances",
		"Effect" : "Allow"
	}]
}
EOF
}

resource "aws_iam_user_group_membership" "qwiklab" {
  user = "awsstudent"

  groups = [
    "${aws_iam_group.qwiklab.name}"
  ]
}

/*
resource "aws_cloudformation_stack" "qwiklab" {
	name = "qwiklab"
	capabilities = ["CAPABILITY_IAM"]
	parameters = {
		VPC = "${aws_vpc.qwiklab.id}"
	}

	template_body = <<STACK
{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description" : "Velostrata v3 PoC CloudFormation template (VxCF-GA-V3-IAMONLY.rev1)",
  "Parameters" : {
    "VPC" : {
      "Type" : "AWS::EC2::VPC::Id",
      "Description" : "The VPC to use"
    }
  },
  "Resources" : {
    "VelosMgrGroup" : {
      "Type" : "AWS::IAM::Group",
      "Properties" : {
        "Path" : "/VelostrataMgr/"
      }
    },
    "VelosMgrGroupPolicy" : {
      "Type" : "AWS::IAM::Policy",
      "Properties" : {
        "PolicyName" : "VelosMgrPolicy",
        "PolicyDocument" : {
          "Statement" : [
            {
            "Resource" : "*",
            "Action" : [ "ec2:RunInstances",
						 "ec2:StartInstances",
						 "ec2:StopInstances",
						 "ec2:RebootInstances",
						 "ec2:AttachVolume",
						 "ec2:DetachVolume",
						 "ec2:Describe*",
						 "ec2:CreateTags",
						 "ec2:GetConsoleOutput",
						 "ec2:ModifyInstanceAttribute"],
            "Effect" : "Allow"
          }, {
            "Condition" : {
              "StringEquals" : {
                "ec2:ResourceTag/ManagedByVelostrata" : "Yes"
              }
            },
            "Resource" : "*",
            "Action" : "ec2:TerminateInstances",
            "Effect" : "Allow"
          }],
          "Version" : "2012-10-17"
        },
        "Groups" : [ {
          "Ref" : "VelosMgrGroup"
        } ]
      }
    }
  }
}

STACK
}
*/