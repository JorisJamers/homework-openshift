#!/bin/bash

################################################################################################
# Openshift deploy script, running this script wil deploy a fully configured Openshift cluster.#
# Author: Joris Jamers                                                                         #
# Homework Assignment Red Hat Delivery Specialist                                              #
################################################################################################

################################################################################################
# Script variables                                                                             #
################################################################################################

ENVARRAY=(dev test prod build)
ADMIN_USER=joris
ADMIN_PASSWORD=joris

# Getting the GUID from the server, this is needed to use in the inventory.
echo "#######################"
echo "Getting the GUID"
echo "#######################"
export GUID=$(echo $(hostname | awk -F'.' '{ print $2 }'))

# As above, we do the same for the domain name. Afterwards we can use the domain name in the inventory. For this we will use cut because we need
# every column after the third one.
echo "#######################"
echo "Getting the domain name"
echo "#######################"
export DOMAIN=$(echo $(hostname | cut -d'.' -f 3-))

################################################################################################
# script                                                                                       #
################################################################################################

# Cloning the repo into a folder on the bastion host. With this repo we will be able to configure openshift and deploy it.
echo "#######################"
echo "Cloning the git repo on the bastion host"
echo "#######################"
git clone https://github.com/JorisJamers/homework-openshift.git

# Here we will edit the inventory file with the GUID we got from the bastion host.
sed -i "s/\$GUID/${GUID}/g" ~/homework-openshift/inventory

# Here we will edit the inventory file with the GUID we got from the bastion host.
sed -i "s/\$DOMAIN/${DOMAIN}/g" ~/homework-openshift/inventory

# We will be able to run the ansible-playbook by now. We start with the prerequisites. This is needed to pre-configure the nodes of the cluster.
echo "#######################"
echo "Running the prerequisites"
echo "#######################"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml

# After we ran the prerequisites we are able to start the deployment of the cluster.
echo "#######################"
echo "Running the deploy_cluster playbook"
echo "#######################"
ansible-playbook -i ~/homework-openshift/inventory /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

# The following command is used to get access to the oc command on the bastion host.
echo "#######################"
echo "Getting the oc command for the bastion host"
echo "#######################"
ansible masters[0] -b -m fetch -a "src=/root/.kube/config dest=/root/.kube/config flat=yes"

# Now we log in to the cluster.
oc login -u system:admin

# In the following commands we will create the nfs shares for the users. The NFS server is going to be restarted in the yaml.
# No need to do it again in this script.
ansible-playbook -i ~/homework-openshift/inventory ~/homework-openshift/yaml-files/create-nfs-shares.yaml

# Create 25 definition files for 5G PVs.
echo "#######################"
echo "Creating the template for 5G PVs"
echo "#######################"
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
echo "#######################"
echo "Creating the template for 10G PVs"
echo "#######################"
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
echo "#######################"
echo "Creating the PVs for the users"
echo "#######################"
cat /root/pvs/* | oc create -f -

#Fix NFS persistent volume recycling.
oc project default
echo "#######################"
echo "Applying the new project template"
echo "#######################"
oc apply -f ~/homework-openshift/yaml-files/project-template.yaml

# Now we need to restart the master-api and the master-controllers.
echo "#######################"
echo "Restarting atomic-openshift-master-api"
echo "#######################"
ansible masters -a "systemctl restart atomic-openshift-master-api"
echo "#######################"
echo "Restarting atomic-openshift-master-controllers"
echo "#######################"
ansible masters -a "systemctl restart atomic-openshift-master-controllers"

# We will create the project for the nodejs-mongo-persistent.
echo "#######################"
echo "Creating the project for the nodejs-mongo-persistent application"
echo "#######################"
oc new-project smoke-test

# Now we are ready to deploy the application to test our PVs.
echo "#######################"
echo "Deploying the nodejs-mongo-persistent application"
echo "#######################"
oc new-app nodejs-mongo-persistent

# We need to create a new project for the jenkins pipeline.
echo "#######################"
echo "Creating the cicd-dev project"
echo "#######################"
oc new-project cicd-dev

# Now we are able to deploy the jenkins-persistent application.
echo "#######################"
echo "Deploying jenkins-persistent on the cicd-dev project"
echo "#######################"
oc new-app jenkins-persistent

# We are going to check if jenkins is available. When the curl doesn't give us 302 we are going to sleep for 5 more seconds.
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' jenkins-cicd-dev.apps.$GUID.$DOMAIN)" != "302" ]]; do
  echo "I am waiting for jenkins to be deployed"
  sleep 5;
done

# Afterwards we will create the 3 projects needed for the pipeline.
for environment in ${ENVARRAY[@]}; do
  echo "#######################"
  echo "Creating the tasks-${environment} project"
  echo "#######################"
  oc new-project tasks-${environment}
done

# We are adding a policy to the jenkins role of cicd-dev to access the other projects.
# we have to make sure that the other projects can pull images from the cicd-dev project.
# This is all done in the forloop, using the bash var ENVARRAY. You can edit this array to get more environments.
for environment in ${ENVARRAY[@]}; do
  oc adm policy add-role-to-user edit system:serviceaccount:cicd-dev:jenkins -n tasks-${environment}
  oc adm policy add-role-to-group system:image-puller system:serviceaccounts:tasks-${environment} -n cicd-dev
done

# At this time we can start to prepare and deploy the openshift tasks.
# Import the openshift tasks template.
echo "#######################"
echo "Importing tasks"
echo "#######################"
oc project openshift
oc apply -f https://raw.githubusercontent.com/OpenShiftDemos/openshift-tasks/master/app-template.yaml

# Create the image streams.
echo "#######################"
echo "Creating the image streams"
echo "#######################"
oc project openshift
oc apply -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/eap/eap64-image-stream.json

# Install the openshift-tasks app.
echo "#######################"
echo "Install openshift-tasks"
echo "#######################"
oc project tasks-build
oc new-app openshift-tasks

# Setup the bc for tasks.
echo "#######################"
echo "Create the buildconfig for tasks"
echo "#######################"
oc project cicd-dev
oc apply -f ~/homework-openshift/yaml-files/jenkins-pipeline.yaml

# There is a script used for the multitenancy. We will now run this provided script.
sh ~/homework-openshift/scripts/multitenancy-script.sh

# Now we are going to label the nodes for the proper projects. Node1 will be the alpha node and Node2 will be the beta node.
# Node3 is going to be used by common.
echo "#######################"
echo " Login As cluster Admin"
echo "#######################"
oc login -u system:admin > /dev/null

# Labeling our nodes so the node-selector will select the proper node.
echo "#######################"
echo "Labeling for client alpha"
echo "#######################"
oc label node node1.$GUID.internal client=alpha

echo "#######################"
echo "Labeling for client beta"
echo "#######################"
oc label node node2.$GUID.internal client=beta

echo "#######################"
echo "Labeling for client common"
echo "#######################"
oc label node node3.$GUID.internal client=common

# Login with the system admin so we can give the admin user the proper role.
echo "#######################"
echo "Login As cluster Admin"
echo "#######################"
oc login -u system:admin > /dev/null

# Now we create a new user so we can give him the cluster-admin role.
echo "#######################"
echo "Creating admin user"
echo "#######################"
ansible masters -a "htpasswd -b /etc/origin/master/htpasswd ${ADMIN_USER} ${ADMIN_PASSWORD}"

# Let's give "joris" the cluster-admin role now, so we will be able to see all projects via this user.
echo "#######################"
echo "Giving '${ADMIN_USER}' the cluster-admin role"
echo "#######################"
oc adm policy add-cluster-role-to-user cluster-admin ${ADMIN_USER}

# Now we start the tasks-bc build.
echo "#######################"
echo "Starting the first build"
echo "#######################"
oc start-build tasks-bc -n cicd-dev

# Now we are going to check if the app is deployed on the production environment.
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' http://tasks-tasks-prod.apps.$GUID.$DOMAIN)" != "200" ]];
do
  echo "Waiting for the app to be deployed"
  sleep 5;
done

# Configure the minimum request of the tasks pods, this is needed for the autoscale to work. Does not work yet, we need to deploy automatically first.
echo "#######################"
echo "Setting the resources for the build, requesting minimal 100m"
echo "#######################"
oc set resources dc tasks --requests=cpu=100m -n tasks-prod

# As a last step we will deploy the HPA on the production environment. This is done by using the tasks-hpa yaml provided with this git repo.
echo "#######################"
echo "Creating the HPA for the tasks-prod environment"
echo "#######################"
oc apply -f ~/homework-openshift/yaml-files/tasks-hpa.yaml -n tasks-prod
