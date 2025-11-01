#!/bin/bash

awk -F: '/:x:10[0-9][0-9]/ && $1 !~ /ec2-user|bastion/ {print $1}' /etc/passwd | \
    while IFS= read -r student
    do
        if [[ -f "/home/${student}/.bash_history" ]]
        then
            echo "${student}: PASS"
        else
            echo "${student}: FAIL"
        fi

        if [[ ! -d "/home/${student}/my_scripts" ]]
        then
            mkdir "/home/${student}/my_scripts"
        fi

        if [[ ! -f "/home/${student}/my_scripts/hello.sh" ]]
        then
            touch "/home/${student}/my_scripts/hello.sh"
            echo "echo \"Hello world!\"" > "/home/${student}/my_scripts/hello.sh"
        fi
    done
