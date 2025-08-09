
#!/bin/bash

AMI_ID=$(./get-latest-ami.sh)
cd terraform/
sed -i "s/custom_ami_id = .*/custom_ami_id = \"$AMI_ID\"/" terraform.tfvars
sed -i "s/ami_type = .*/ami_type = \"CUSTOM\"/" terraform.tfvars
terraform init
terraform plan
terraform apply -auto-approve