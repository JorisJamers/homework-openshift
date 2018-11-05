#!/bin/bash

################################################################################################
# Openshift deploy script, running this script wil deploy a fully configured Openshift cluster.#
################################################################################################

# Cloning the repo into a folder on the bastion host. With this repo we will be able to configure openshift and deploy it.
echo "Cloning the git repo on the bastion host"
git clone https://github.com/JorisJamers/homework-openshift.git

source get-env-var.sh

# We will be able to run the ansible-playbook by now. We start with the prerequisites. This is needed to pre-configure the nodes of the cluster.
echo "Running the prerequisites"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml

# After we ran the prerequisites we are able to start the deployment of the cluster.
echo "Running the deploy_cluster playbook"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
