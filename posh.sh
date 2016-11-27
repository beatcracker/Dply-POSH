#!/bin/bash

export DEBIAN_FRONTEND=noninteractive;

#################################[ Functions ]##################################

wait_for_dpkg(){
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1
  do
    echo '-=:[ Waiting for other software managers to finish... ]:=-'
    sleep 5
  done
}

#################################[ Install JQ ]#################################
echo '-=:[ Installing JQ ]:=-'

wait_for_dpkg
apt-get install -y jq ||
echo "-=:[ Failed to install JQ! ]:=-"

#############################[ Install PowerShell ]#############################

URL=$(curl -s 'https://api.github.com/repos/PowerShell/PowerShell/releases' \
| jq --raw-output \
 '.[0].assets[]
| select(.content_type | contains("application/x-debian-package"))
| select (.browser_download_url | match("16\\..+_amd64"))
| .browser_download_url')

if [ ! -z "$URL" ]
then
  PACKAGE=$(basename "$URL")
  OUT_PATH='/tmp'
  
  echo "-=:[ Downloading POSH package: ]:=-"
  echo "-=:[  $URL -> $OUT_PATH/$PACKAGE  ]:=-"
  if curl -s -L -o "$OUT_PATH/$PACKAGE" "$URL"
  then
    echo '-=:[ Installing POSH package ]:=-'
    wait_for_dpkg
    dpkg -i "$OUT_PATH/$PACKAGE" &> /dev/null

    wait_for_dpkg
    apt-get install -f -y ||
    echo "-=:[ Failed to install POSH package!]"
  
    echo "-=:[ Removing downloaded POSH package: $OUT_PATH/$PACKAGE ]:=-"
    rm "$OUT_PATH/$PACKAGE"
  else
    echo "-=:[ Failed to download POSH package!]"
  fi
else
  echo "-=:[ Failed to get POSH package URL!]"
fi

#############################[ Install Butterfly ]##############################

echo '-=:[ Installing Python packages ]:=-'
wait_for_dpkg
apt-get install -y build-essential libssl-dev libffi-dev python-dev python-pip ||
echo "-=:[ Failed to install Python packages! ]:=-"

echo '-=:[ Installing Butterfly ]:=-'
yes | pip install butterfly libsass ||
echo '-=:[ Failed to install Butterfly! ]:=-'

echo '-=:[ Creating Butterfly service and socket ]:=-'
BFLY_PATH=$(which 'butterfly.server.py')
BFLY_SERVICE='butterfly.service'
BFLY_SOCKET='butterfly.socket'
BFLY_CONF='/etc/butterfly/butterfly.conf'
IP=$(curl -s 'http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address')
BFLY_PORT='80'
SERVICE_PATH='/etc/systemd/system'

cat <<EOF > "$SERVICE_PATH/$BFLY_SERVICE"
  [Unit]
  Description=Butterfly Terminal Server

  [Service]
  ExecStart=$BFLY_PATH --host=$IP --port=$BFLY_PORT --unsecure --login
EOF

cat <<EOF > "$SERVICE_PATH/$BFLY_SOCKET"
  [Socket]
  ListenStream=$BFLY_PORT

  [Install]
  WantedBy=sockets.target
EOF

echo '-=:[ Enabling socket ]:=-'
systemctl enable butterfly.socket ||
echo '-=:[ Failed to enable socket! ]:=-'

systemctl start butterfly.socket ||
echo '-=:[ Failed to start socket! ]:=-'

###########################[ Change root password ]#############################

HOSTNAME=$(curl -s 'http://169.254.169.254/metadata/v1/hostname')
echo "-=:[ Setting root password to hostname: $HOSTNAME ]:=-"
echo "root:$HOSTNAME" | chpasswd ||
echo "-=:[ Failed to set root password! ]:=-"

###################################[ Done! ]####################################

echo '-=:[ INITIAL SETUP IS COMPLETE! ]:=-'

################################################################################