#!/bin/sh
# Author: Bulent Ozel bulent.ozel@gmail.com
# Sample code snippets on how to monitor running processes.
# It is written for personal use. If you like to use it and need more
# explanation email me.

run_a_process()
{
    IDLE=$1
    sleep $IDLE
}

run_a_process 1 &
PID=$!
wait $PID
EXIT_CODE=`echo $?`
echo "Process $PID is completed. The wait exit code is $EXIT_CODE."

run_a_process 3 &
PID=$!
wait $PID
EXIT_CODE=`echo $?`
if [ $EXIT_CODE -eq 0 ]
then
    echo "Process $PID is finished successfully."
fi

kill -0 $PID
EXIT_CODE=`echo $?`
if [ $EXIT_CODE -ne 0 ]
then
    echo "Process $PID was completed. The kill exit code is $EXIT_CODE"
fi

run_a_process 60 &
PID=$!
kill -0 $PID
EXIT_CODE=`echo $?`
if [ $EXIT_CODE -eq 0 ]
then
    echo "Process $PID is too slow. Exiting..."
    exit 1
fi