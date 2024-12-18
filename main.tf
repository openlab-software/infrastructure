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
    destination = "/tmp"
  }
}

resource "null_resource" "install" {
  depends_on = [ null_resource.copy_installers ]

  triggers = {
    host = var.vps_ip
    user = var.ssh_user
    private_key = file(var.ssh_private_key)
  }

  connection {
    type = "ssh"
    host = self.triggers.host
    user = self.triggers.user
    private_key = self.triggers.private_key
  }

  provisioner "remote-exec" {
    when = create
    inline = [ 
      "sudo chmod -R +x /tmp/resources",
      "sudo /tmp/resources/install_docker.sh",
      "sudo mkdir /usr/share/nginx",
      "sudo mkdir /etc/nginx",
      "sudo cp -R -f /tmp/resources/nginx/html /usr/share/nginx",
      "sudo cp -R -f /tmp/resources/nginx/* /etc/nginx",
      "cd /tmp/resources && docker-compose up -d"
     ]
  }

  provisioner "remote-exec" {
    when = destroy
    on_failure  = continue
    inline = [ 
      "sudo rm -rf /usr/share/nginx",
      "sudo rm -rf /etc/nginx",
      "cd /tmp/resources && docker-compose down"
     ]
  }
}