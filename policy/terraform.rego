package terraform.security

# local-exec / remote-exec provisioner は CI/CD上でのコード実行リスクがあるため禁止
deny[msg] {
  resource := input.configuration.root_module.resources[_]
  provisioner := resource.provisioners[_]
  provisioner.type == "local-exec"
  msg := sprintf("local-exec provisioner は使用禁止です: %s", [resource.address])
}

deny[msg] {
  resource := input.configuration.root_module.resources[_]
  provisioner := resource.provisioners[_]
  provisioner.type == "remote-exec"
  msg := sprintf("remote-exec provisioner は使用禁止です: %s", [resource.address])
}
