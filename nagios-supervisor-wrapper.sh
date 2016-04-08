#!/usr/bin/env bash

if [[ "$1" = "status" ]]
then
    # We need to return 1 if nagios is not running
    status=$(supervisorctl status nagios)
    echo $status
    grep RUNNING > /dev/null <<< "$status"
elif [[ "$1" = "genpid" ]]
then
 NagiosRunFile=/var/run/nagios.pid

 while [[ ! -e $NagiosRunFile ]]
 do
 superstatus=$(supervisorctl status nagios)
  if echo $superstatus |grep -q RUNNING
    then
      superpid=$(supervisorctl pid nagios)
      echo $superpid > $NagiosRunFile
  fi
 done
else
    supervisorctl "$1" nagios
fi
