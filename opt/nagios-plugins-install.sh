#!/usr/bin/env bash

# Install nagios plugin
cd /opt
for i in *.script ; do

 scriptname=`echo $i|awk -F".script" '{print $1}'`
 check_script=/usr/lib64/nagios/plugins/"$scriptname"
 if [[ ! -x "$check_script" ]]
 then
    cp "$i" "$check_script"
    chown nagios: "$check_script"
    chmod +x "$check_script"
 elif  [[ ! `cmp $check_script $i >/dev/null 2>&1` ]]
 then
    cp "$i" "$check_script"
    chown nagios: "$check_script"
    chmod +x "$check_script"
# debug
#    success=`ls -Fla "$check_script"`
#    echo $success >> /opt/pluginok.out
 fi
done
