provider "null" {}

resource "null_resource" "copy_installers" {
  connection {
    type = "ssh"
    host = var.vps_ip
    user = var.ssh_user
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    source = "resources"
    destination = "/tmp/resources"
  }
}

resource "null_resource" "install" {
  depends_on = [ null_resource.copy_installers ]

  connection {
    type = "ssh"
    host = var.vps_ip
    user = var.ssh_user
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [ 
      "sudo chmod -R +x /tmp/resources",
      "cd /tmp/resources",
      "sudo ./install_docker.sh",
      "sudo mv ./nginx/* /etc/nginx",
      "docker-compose up -d"
     ]
    
  }
}