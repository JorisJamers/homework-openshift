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

# Now we log in to the cluster.
oc login -u system:admin

# In the following commands we will create the PVS for the users.
ansible-playbook -i ~/homework-openshift/inventory ~/homework-openshift/yaml-files/create-pvs.yaml

# Afterwards we will restart the nfs-server.
systemctl restart nfs-server

# Create 25 definition files for 5G PVs.
echo "Creating the template for 5G PVs"
export volsize="5Gi"
mkdir /root/pvs
for volume in pv{1..25} ; do
cat << EOF > /root/pvs/${volume}
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "${volume}"
  },
  "spec": {
    "capacity": {
        "storage": "${volsize}"
    },
    "accessModes": [ "ReadWriteOnce" ],
    "nfs": {
        "path": "/srv/nfs/user-vols/${volume}",
        "server": "support1.${GUID}.internal"
    },
    "persistentVolumeReclaimPolicy": "Recycle"
  }
}
EOF
echo "Created def file for ${volume}";
done;

# Create 25 definition files for 10G pvs.
echo "Creating the template for 10G PVs"
export volsize="10Gi"
for volume in pv{26..50} ; do
cat << EOF > /root/pvs/${volume}
{
  "apiVersion": "v1",
  "kind": "PersistentVolume",
  "metadata": {
    "name": "${volume}"
  },
  "spec": {
    "capacity": {
        "storage": "${volsize}"
    },
    "accessModes": [ "ReadWriteMany" ],
    "nfs": {
        "path": "/srv/nfs/user-vols/${volume}",
        "server": "support1.${GUID}.internal"
    },
    "persistentVolumeReclaimPolicy": "Retain"
  }
}
EOF
echo "Created def file for ${volume}";
done;

# Create all the PVs from the definition files.
echo "Creating the PVs for the users"
cat /root/pvs/* | oc create -f -

#Fix NFS persistent volume recycling.
oc project default
echo "Applying the new project template"
oc apply -f ~/homework-openshift/yaml-files/project-template.yaml

# Now we need to restart the master-api and the master-controllers.
echo "Restarting atomic-openshift-master-api"
ansible masters -a "systemctl restart atomic-openshift-master-api"
echo "Restarting atomic-openshift-master-controllers"
ansible masters -a "systemctl restart atomic-openshift-master-controllers"

# We will create the project for the nodejs-mongo-persistent.
echo "Creating the project for the nodejs-mongo-persistent application"
oc new-project smoke-test

# Now we are ready to deploy the application to test our PVs.
echo "Deploying the nodejs-mongo-persistent application"
oc new-app nodejs-mongo-persistent

# We need to create a new project for the jenkins pipeline.
echo "Creating the cicd-dev project"
oc new-project cicd-dev

# Now we are able to deploy the jenkins-persistent application.
echo "Deploying jenkins-persistent on the cicd-dev project"
oc new-app jenkins-persistent

# Afterwards we will create the 3 projects needed for the pipeline.
echo "Creating the tasks-dev project"
oc new-project tasks-dev
echo "Creating the tasks-test project"
oc new-project tasks-test
echo "Creating the tasks-prod project"
oc new-project tasks-prod

# At this time we can start to prepare and deploy the openshift tasks
