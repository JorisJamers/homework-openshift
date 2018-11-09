#!/bin/bash

mkdir -p /srv/nfs/user-vols/pv{1..50}

for pvnum in {1..50} ;
do
 echo "/srv/nfs/user-vols/pv${pvnum} *(rw,root_squash)" >> /etc/exports.d/openshift-uservols.exports
 chown -R nfsnobody.nfsnobody  /srv/nfs
 chmod -R 777 /srv/nfs
done
