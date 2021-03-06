/*
/-----------------------------------------\
| Terraform github actions demo           |
|-----------------------------------------|
| Author: Henk van Achterberg             |
| E-mail: henk.vanachterberg@broadcom.com |
\-----------------------------------------/
*/

// Variables

variable "region" {
  default = "eu-central-1"
}
variable "vpc_id" {
  default = "vpc-0f7d47b36beb4f382"
}
variable "subnet_id" {
  default = "subnet-07ffcb9652c58c186"
}
variable "ami_id" {
  default = "ami-0b418580298265d5c"
}
variable "ssh_key_name" {
  default = "Henk_vanAchterberg-SME-EMEA"
}
variable "tenant_domain" {
  default = "ikbeneenvliegtuig.luminatesec.com"
}
variable "luminate_user" {
  default = "ikbennietgek@ikbeneenvliegtuig.nl"
}

variable "luminate_group" {
  default = "Iedereen"
}

variable "git_repo" {
  default = ""
}
variable "git_branch" {
  default = ""
}

// Terraform init

terraform {
  required_version = ">=0.12.24"
  backend "s3" {
    bucket         = "td-hva-tfstate"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "td-hva-aws-locks"
    encrypt        = true
  }
}

// AWS Provider

provider "aws" {
  region = var.region
}
resource "aws_security_group" "only_allow_outbound" {
  name        = "only_allow_outbound"
  description = "Allow allow outbound traffic"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "vm" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = var.ssh_key_name
  user_data     = data.template_file.user-data.rendered
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [aws_security_group.only_allow_outbound.id]
}

data "template_file" "user-data" {
  template = file("tf-tpl/user-data.tpl")
  vars = {
    config_script_64   = base64encode(data.template_file.fixtures-config.rendered)
    config_script_path = "/tmp/node-config.sh"
  }
}

data "template_file" "fixtures-config" {
  template = file("tf-tpl/config-node.sh.tpl")
  vars = {
    connector_command = luminate_connector.connector.command
    git_repo = var.git_repo
    git_branch = var.git_branch
  }
}

// Secure Access Cloud (luminate) provider

provider "luminate" {
  api_endpoint = "api.${var.tenant_domain}"
}

resource "luminate_site" "site" {
  name = "demo-site"
}

resource "luminate_connector" "connector" {
  name    = "demo-site-connector"
  site_id = luminate_site.site.id
  type    = "linux"
}

resource "luminate_web_application" "nginx" {
  name             = "demo-nginx"
  site_id          = luminate_site.site.id
  internal_address = "http://127.0.0.1:8080"
}

resource "luminate_web_access_policy" "web-access-policy" {
  name                 = "web-access-policy"
  identity_provider_id = data.luminate_identity_provider.idp.identity_provider_id
  user_ids             = data.luminate_user.users.user_ids
  group_ids            = data.luminate_group.groups.group_ids
  applications         = [luminate_web_application.nginx.id]
}

data "luminate_identity_provider" "idp" {
  identity_provider_name = "AzureAD"
}

data "luminate_user" "users" {
  identity_provider_id = data.luminate_identity_provider.idp.identity_provider_id
  users                = [var.luminate_user]
}

data "luminate_group" "groups" {
  identity_provider_id = data.luminate_identity_provider.idp.identity_provider_id
  groups               = [var.luminate_group]
}

// Output variables

output "nginx-demo-url" {
  value = luminate_web_application.nginx.external_address
}
