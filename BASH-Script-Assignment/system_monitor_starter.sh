#!/usr/bin/env bash
# system_monitor.sh
# Student Starter Template
# This script should display system information multiple times.
# Each report should include date, user, host, uptime, disk usage,
# memory usage, and top 5 processes.

# TODO: Prompt the user for how many times to run the report
# The prompt should be: "How many times would you like to run the report? "


# TODO: Initialize counter variable named COUNT to 1


# Start the loop
# TODO: Fix the comparison operator in the while loop below
while [ "$COUNT" -gt "$RUNS" ]
do
    # TODO: Clear the screen at the start of each iteration


    # TODO: Capture current user name use the appropriate environment variable
    # USER_NAME=

    # TODO: Capture the Linux server's hostname using the appropriate Linux command
    # HOST_NAME=$()

    # TODO: Capture the current date using the appropriate Linux command
    # CURRENT_DATE=$()

    # TODO: Capture the Linux server's up time using the appropriate Linux command
    # UPTIME_INFO=$()

    # Display a nicely formatted header section using echo
    echo "==================================="
    echo "     SYSTEM INFORMATION REPORT"
    echo "==================================="
    echo "Run #:          $COUNT of $RUNS"
    echo "Timestamp:      $CURRENT_DATE"
    echo "User:           $USER_NAME"
    echo "Host:           $HOST_NAME"
    echo "Uptime:         $UPTIME_INFO"
    echo

    # TODO: Display Disk Usage section using


    echo # Spacer: Do not remove
    
    # TODO: Display Memory Usage
    

    echo # Spacer: Do not remove
    
    # TODO: Display Top Processes
    

    # If this isn’t the last run, print a waiting message and sleep for 5 seconds
    if [ "$COUNT" -lt "$RUNS" ]
    then
        echo "Waiting 5 seconds before next run..."
        # TODO: Add command to sleep for five seconds
    fi

    # Increment counter
    COUNT=$((COUNT + 1))
done

# Print a completion message
echo "Monitoring complete after $RUNS iterations."
