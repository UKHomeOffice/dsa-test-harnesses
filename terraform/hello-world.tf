resource "null_resource" "example1" {
  provisioner "local-exec" {
    command = "echo 'hello world'"
  }
}
