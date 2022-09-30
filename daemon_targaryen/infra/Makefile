clean:
	for i in $$(find -L . -xtype l); do unlink $$i; done

links: clean
	ln -s ../../templates/provider.tf
	ln -s ../../templates/network.tf .
	ln -s ../../templates/az.tf .
	ln -s ../../templates/eks.tf .
	ln -s ../../templates/eks_node_and_ssm_policy.json .


init:
	terraform init -backend-config="key=terraform/ashwiniag-dragon/infra/terraform.tfstate"

plan: links init
	terraform plan

apply: links init
	terraform apply

destroy: links init
	terraform destroy

