locals { 
    name        = "Ubuntu-20-Generic-${local.timestamp}"
    description = "Generic Production Ubuntu"
    timestamp   = regex_replace(timestamp(), "[- TZ:]", "") 
    app         = "generic"
}

variable "build_subnet" {
  type =  string
}

variable "build_region" {
  type =  string
}

variable "ubuntu_ami" {
  type =  string
}


source "amazon-ebs" "ubuntu" {
  ami_name      = local.name
  source_ami    = var.ubuntu_ami
  encrypt_boot  = true
  region        = var.build_region
  subnet_id     = var.build_subnet
  instance_type = "m5.2xlarge"
  ssh_username  = "ubuntu"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
  }
  run_tags = {
    Name        = local.name
    Description = local.description
    App         = local.app
  }
  tags = {
    Name         = local.name
    Description = local.description
    App          = local.app
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]
  
  ########################
  # Install O/S packages #
  ########################

  provisioner "shell" {
    inline = ["sudo add-apt-repository universe" ]
    pause_after  = "60s"
  }
  
  provisioner "shell" {
    inline = ["sudo apt -y update" ]
    pause_after  = "60s"
  }
  
  
  provisioner "shell" {
    inline = ["sudo apt -y install ansible", 
              "sudo apt -y install unzip", 
              "sudo apt -y install chrony",
              "sudo apt -y install acl",
              "sudo apt -y install atop",
              "sudo apt -y install python3-pip",
              "sudo apt -y install sysstat",
              "sudo apt -y install conntrack",
              "sudo apt -y install jq",
              "sudo pip3 install ec2-metadata" ]
  }
  
  #######################
  # Create the ssm-user #
  #######################
  provisioner "shell" {
    inline = ["sudo useradd --uid 1001 ssm-user",
              "echo 'ssm-user ALL=(ALL) NOPASSWD:ALL' |sudo tee /etc/sudoers.d/ssm-agent-users"]
  }


  #################
  # Configure VIM #
  #################

  provisioner "file" {
      destination = "/tmp/.vimrc"
      source = "./files/.vimrc"
  }

  provisioner "shell" {
    inline = [ "sudo mv /tmp/.vimrc /root/.vimrc",
               "sudo chown root:root /root/.vimrc"]
  }

  ##############################
  # Install awscli environment #
  ##############################
  
  provisioner "shell" {
    inline = ["cd /tmp",
              "sudo curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip",
              "sudo unzip awscliv2.zip",
              "sudo ./aws/install" ]
              
  }

  ###################
  # Do ansible setup #
  ####################

  provisioner "shell" {
    inline = [  "sudo mkdir /scripts",
                "sudo chmod -R 777 /scripts",
                "sudo mkdir -p /opt/build-state",
                "sudo chmod 0700 /opt/build-state" ]
  }

  provisioner "file" {
    destination = "/scripts"
    source      = "scripts/"       
  }

  provisioner "shell" {
    inline = [ 
               "sudo mv /scripts/boot-build.service /usr/lib/systemd/system/boot-build.service",
               "sudo chown root:root /usr/lib/systemd/system/boot-build.service",
               "sudo systemctl daemon-reload",
               "sudo systemctl enable boot-build.service",
               "sudo mv /scripts/boot-build.sh /bin/boot-build.sh",
               "sudo chmod 700 /bin/boot-build.sh",
               "sudo chown root:root /bin/boot-build.sh",
               "sudo chmod 0700 /scripts", 
               "sudo systemctl disable unattended-upgrades",
               "sudo apt-get remove unattended-upgrades -y"
              ]
  }
} 
