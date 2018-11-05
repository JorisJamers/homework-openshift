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

# Now we log in to the cluster

oc login -u system:admin

# In the following commands we will create the PVS for the users

mkdir -p /srv/nfs/user-vols/pv{1..200}

echo "Create directories at the NFS server to be used as PVs in the OpenShift cluster.."

for pvnum in {1..50} ; do
  echo '/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)' >> /etc/exports.d/openshift-uservols.exports
  chown -R nfsnobody.nfsnobody /srv/nfs
  chmod -R 777 /srv/nfs
done

# Afterwards we will restart the nfs-server

systemctl restart nfs-server

# Create 25 definition files for 5G PVs

export GUID=`hostname|awk -F. '{print $2}'`

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

# Create 25 definition files for 10G pvs

export GUID=`hostname|awk -F. '{print $2}'`

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

# Create all the PVs from the definition files

cat /root/pvs/* | oc create -f -



# We are going to create a new project for the jenkins pod.
oc new-project cicd-dev
