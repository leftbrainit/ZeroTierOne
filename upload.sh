#!/bin/bash

GCSURL="gs://leftbrain-a057d.appspot.com/public/ZeroTierInstaller.pkg"
"gsutil" cp 'ZeroTier One.pkg' $GCSURL
"gsutil" acl ch -u AllUsers:R $GCSURL
"gsutil" setmeta -h "Cache-Control:private, max-age=0, no-transform" $GCSURL
exit 0