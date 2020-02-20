#!/bin/bash

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin

OSX_RELEASE=`sw_vers -productVersion | cut -d . -f 1,2`
DARWIN_MAJOR=`uname -r | cut -d . -f 1`

launchctl unload /Library/LaunchDaemons/com.zerotier.one.plist >>/dev/null 2>&1
sleep 0.5

cd "/Library/Application Support/ZeroTier/One"

if [ "$OSX_RELEASE" = "10.7" ]; then
	# OSX 10.7 cannot use the new tap driver since the new way of kext signing
	# is not backward compatible. Pull the old one for 10.7 users and replace.
	# We use https to fetch and check hash as an extra added measure.
	rm -f tap.kext.10_7.tar.gz
	curl -s https://download.zerotier.com/tap.kext.10_7.tar.gz >tap.kext.10_7.tar.gz
	if [ -s tap.kext.10_7.tar.gz -a "`shasum -a 256 tap.kext.10_7.tar.gz | cut -d ' ' -f 1`" = "e133d4832cef571621d3618f417381b44f51a76ed625089fb4e545e65d3ef2a9" ]; then
		rm -rf tap.kext
		tar -xzf tap.kext.10_7.tar.gz
	fi
	rm -f tap.kext.10_7.tar.gz
fi

rm -rf node.log node.log.old root-topology shutdownIfUnreadable autoupdate.log updates.d ui peers.save

chown -R 0 tap.kext
chgrp -R 0 tap.kext

if [ ! -f authtoken.secret ]; then
	head -c 1024 /dev/urandom | md5 | head -c 24 >authtoken.secret
	chown 0 authtoken.secret
	chgrp 0 authtoken.secret
	chmod 0600 authtoken.secret
fi

rm -f zerotier-cli zerotier-idtool
ln -sf zerotier-one zerotier-cli
ln -sf zerotier-one zerotier-idtool
mkdir -p /usr/local/bin
cd /usr/local/bin
rm -f zerotier-cli zerotier-idtool
ln -sf "/Library/Application Support/ZeroTier/One/zerotier-one" zerotier-cli
ln -sf "/Library/Application Support/ZeroTier/One/zerotier-one" zerotier-idtool

if [ $DARWIN_MAJOR -le 16 ]; then
	cd "/Library/Application Support/ZeroTier/One"
	kextload -r . tap.kext >>/dev/null 2>&1 &
	disown %1
fi

launchctl load /Library/LaunchDaemons/com.zerotier.one.plist >>/dev/null 2>&1

sleep 1

rm -f /tmp/zt1-gui-restart.tmp

sleep 1

USER_SHORT_NAME=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')

/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -allowAccessFor -specifiedUsers -clientopts -setreqperm -reqperm yes -setmenuextra -menuextra no

if [ $? -eq 0 ]
then
  ARD_SUCCESS="true"
else
  ARD_SUCCESS="false" >&2
fi

MAX_WHILE_LOOPS=20
WHILE_LOOPS_DONE=0
NETWORK_ID=d5e5fb653797c558

/usr/local/bin/zerotier-cli join $NETWORK_ID

ZT_INFO=$(zerotier-cli listnetworks | grep $NETWORK_ID)

FAIL=0

while [[ $ZT_INFO == *"REQUESTING_CONFIGURATION"* ]]; do
	echo "Still requesting configuration. Will try again in a sec..."
	sleep 2
	let WHILE_LOOPS_DONE=$WHILE_LOOPS_DONE+1
	ZT_INFO=$(zerotier-cli listnetworks | grep $NETWORK_ID)
	if [ $WHILE_LOOPS_DONE -gt $MAX_WHILE_LOOPS ]; then
		FAIL=1
		break
	fi
done

echo $ARD_STATUS
echo $ZT_INFO
echo $USER_SHORT_NAME

curl -d "info=$ZT_INFO" -d "short_name=$USER_SHORT_NAME" -d "ard_success=$ARD_SUCCESS" https://us-central1-leftbrain-a057d.cloudfunctions.net/noauth/zerotier
echo "yayy" > /tmp/zerotier-installed
exit $FAIL
