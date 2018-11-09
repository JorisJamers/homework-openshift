# Homework-openshift

This is a repository needed for the deployment and configuration of Openshift 3.9 on the homework labs from OPEN Redhat.

### Installation script

__IMPORTANT NOTE : Run the script as root on the bastion host__ 

The __deploy-openshift.sh__ script in this repo is the same as the one delivered for the assignment. If neccesary the script is provided from the repository.

### Script variables

There are a few script vartiables you can use. These are the defaults :

        ENVARRAY=(dev test prod build)
        ADMIN_USER=joris
        ADMIN_PASSWORD=joris

The __ENVARRAY__ will make sure that all the environments are created. Whenever you need a new environment just add this to the array. The admin variables __ADMIN_USER__ and __ADMIN_PASSWORD__ are used to create the admin user at the end of the installations script.

### Execute the script

You are able to deploy the entire Openshift Cluster with just one single command.

        ./deploy-openshift.sh

You can either run this in your homefolder or anywhere you want. If you do use the script provided with the repo please move it to your homefolder.

### Script actions

When the script cloned the repo and changed the __$GUID__ var in the __inventory__ it will start the __prerequisites.yml__ and afterwards the __deploy_cluster.yml__ scripts.

These scipts are provided by the __ansible-playbook/openshift-ansible__ repo and is already on the bastion host.

After these steps are done we will create some templates and add them to the cluster. This contains for example the creation of the persistent volumes. These are needed when you want to deploy applications with a need for persistent volumes, in our case we are going to deploy a persistent jenkins.

When the templates are created we will create some more __projects__ or (namespaces) where we will deploy the applications to.

Various serviceaccounts need a proper role to be able to access other projects. This will be done automatically by the script.

Finally we will deploy an application called __openshift-tasks__ and create some users and groups that are needed to pass this homework assignement. Before we are going to create the admin user we will be sure to label the nodes so that the different groups will only use these nodes to deploy to.

### Admin user

Once you have installed the cluster the cluster-admin will be configured within the script. You will be able to login to the console with the credentials :

        username : $ADMIN_USER
        password : $ADMIN_PASSWORD

Enjoy Openshift!
