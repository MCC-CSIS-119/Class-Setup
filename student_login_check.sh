#!/bin/bash

awk -F: '/:x:10[0-9][0-9]/ && $1 !~ /dlloyd|ec2-user|bastion/ {print $1}' /etc/passwd | \
    while IFS= read -r student
    do
        if [[ -f "/home/${student}/.bash_history" ]]
        then
            echo "${student}: PASS"
        else
            echo "${student}: FAIL"
        fi
    done
