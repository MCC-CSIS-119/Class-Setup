#!/bin/bash

for student in $(awk -F: '/:x:10[0-9][0-9]/ && $1 !~ /ec2-user|bastion/ {print $1}' /etc/passwd)
do
    echo "Setting up nano syntax highlighting for ${student}"
    echo "include /usr/share/nano/sh.nanorc" > "/home/${student}/.nanorc"
    chown "${student}":mcc "/home/${student}/.nanorc"

    echo "Landing started script for ${student}"
    SCRIPT="/home/${student}/system_monitor.sh"
    cp ./system_monitor_starter.sh "${SCRIPT}"
    chown "${student}":mcc "${SCRIPT}"
    chmod +x "${SCRIPT}"
done

echo "Status: nano syntax highlighting"
ls -l /home/*/.nanorc
echo

echo "Status: starter script"
ls -l /home/*/system_monitor.sh

ln -s system_monitor_selfcheck.sh /usr/local/bin/system_monitor_selfcheck
