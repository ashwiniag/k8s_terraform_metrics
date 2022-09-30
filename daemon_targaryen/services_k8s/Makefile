host_infra := ashwiniag-dragon
kubeconfig_dir = /tmp/kubeconfig/${host_infra}
kubeconfig_path = ${kubeconfig_dir}/services

clean:
	for i in $$(find -L . -xtype l); do unlink $$i; done

links: clean
	ln -s ../../templates/remote_state.tf .
	ln -s ../../templates/provider.tf .
	ln -s ../../templates/k8s_provider.tf .
	ln -s ../../templates/vm_metrics.tf .
	ln -s ../../templates/AWSLoadBalancerControllerIAMPolicy.json .
	ln -s ../../templates/alb_ingress_controller.tf .

init: links
	terraform init -backend-config="key=terraform/${host_infra}/services/terraform.tfstate"

create_kubeconfig_dir:
	mkdir -p ${kubeconfig_dir}

kubeconfig: create_kubeconfig_dir
	rm -rf ${kubeconfig_path}; aws eks --region us-east-1 update-kubeconfig --name ashwiniag-dragon --kubeconfig ${kubeconfig_path}

plan: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform plan

apply: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform apply

destroy: init
	TF_VAR_kubeconfig_path=${kubeconfig_path} TF_VAR_host_infra=${host_infra} terraform destroy

