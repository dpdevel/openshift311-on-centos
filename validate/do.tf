resource "digitalocean_ssh_key" "openshift" {
  name       = "openshift"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "digitalocean_droplet" "openshift" {
  image  = "centos-7-x64"
  name   = "openshift"
  region = "ams3"
  size   = "s-6vcpu-16gb"
  ssh_keys = ["${digitalocean_ssh_key.openshift.fingerprint}"]
  monitoring = true

  provisioner "file" {
    source      = "validate.sh"
    destination = "/root/validate.sh"
  }

  provisioner "file" {
    source      = "run.sh"
    destination = "/root/run.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /root/validate.sh",
      "/root/validate.sh",
    ]
  }

  provisioner "local-exec" {
    command = "echo ${digitalocean_droplet.openshift.ipv4_address} > ip.tmp"
  }

}