#!/bin/bash

################################################################################################
# Openshift deploy script, running this script wil deploy a fully configured Openshift cluster.#
# Author: Joris Jamers                                                                         #
# Homework Assignment Red Hat Delivery Specialist                                              #
################################################################################################

# Cloning the repo into a folder on the bastion host. With this repo we will be able to configure openshift and deploy it.
echo "Cloning the git repo on the bastion host"
git clone https://github.com/JorisJamers/homework-openshift.git

# Getting the GUID from the server, this is needed to use in the inventory.
echo "Getting the GUID"
export GUID=$(echo $(hostname | awk -F'.' '{ print $2 }'))

# As above, we do the same for the domain name. Afterwards we can use the domain name in the inventory. For this we will use cut because we need
# every column after the third one.
echo "Getting the domain name"
export DOMAIN=$(echo $(hostname | cut -d'.' -f 3-))

# Here we will edit the inventory file with the GUID we got from the bastion host.
sed -i "s/\$GUID/${GUID}/g" ~/homework-openshift/inventory

# Here we will edit the inventory file with the GUID we got from the bastion host.
sed -i "s/\$DOMAIN/${DOMAIN}/g" ~/homework-openshift/inventory

# We will be able to run the ansible-playbook by now. We start with the prerequisites. This is needed to pre-configure the nodes of the cluster.
echo "Running the prerequisites"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml

# After we ran the prerequisites we are able to start the deployment of the cluster.
echo "Running the deploy_cluster playbook"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

# The following command is used to get access to the oc command on the bastion host.
echo "Getting the oc command for the bastion host"
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

# We are going to create a new project for the jenkins pod.
oc new-project cicd-dev

# Creating users : WIP
ansible masters -a "htpasswd -b /etc/origin/master/htpasswd joris joris"
