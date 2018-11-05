# Getting the GUID from the server, this is needed to use in the inventory.
echo "Getting the GUID"
export GUID=$(echo $(hostname | awk -F'.' '{ print $2 }'))

# As above, we do the same for the domain name. Afterwards we can use the domain name in the inventory. For this we will use cut because we need
# every column after the third one.
echo "Getting the domain name"
export DOMAIN=$(echo $(hostname | cut -d'.' -f 3-))""
