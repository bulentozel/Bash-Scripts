#!/bin/bash
# Author: Bulent Ozel bulent.ozel@gmail.com
# Sample code snippets on how to manage running processes
# on a machine with multiple processors. This has been developed mainly to run
# Monte Carlo simulations on a linux cluster with 64 codes. Each simulation in
# this case is to EURACE Agent Based Model developed with FLAME.

run_a_process()
{
    IDLE=$(( RANDOM % 3 ))
    sleep $IDLE &
    PID=$!
    echo $PID
}


run_EURACE_model()
{
    JOBPATH=$1

    BASEDIR=$(dirname "${JOBPATH}")

    MODELEXE="./$(basename "${JOBPATH}")"

    cd $BASEDIR
    INITXML=$(find . -name *init.xml)
    INITXML="./$(basename "${INITXML}")"
 
    simfile="${BASEDIR}/log_seed_runtime.txt"


    FFLAG="-f"
    wine $MODELEXE $NITER $INITXML $FFLAG $XMLOUTF > $simfile &
    PID=$!
    echo $PID
}


# Load Balancer:
# In order to run a job either an external script
#
# Inputs:
# - $1 is a queue of jobs to be run
# - $2 is a queue of running job PIDs
# - $3 is the maximum number of jobs that can run at a time

# Algorithm:

# If $1 is empty return $2

# If the length of $2 is smaller than $3 then
#   add a new job to queue $2 from queue $1
#   self-recurse with updated queues

# Go through running queue $2
#   by doing a round-robbin traverse
#   when a finished job is found then
#       add a new job to queue $2 from queue $1
#       remove that job id from queue $1
#       self-recurse with updated queues

# Output:
# - $2 the queue of PIDs of possibly still running simulations.

run_sims()
{
    waitingQ=("${!1}")
    runningQ=("${!2}")
    MAX_RUN=$3


    # This case should not be observed under normal conditions.
    if [ $MAX_RUN -eq 0 ]; then
        echo ${runningQ[@]}
    fi

    # Get the length of the waiting job queue:
    nWQ=${#waitingQ[@]}
    # Get the number of running seeds:
    nRQ=${#runningQ[@]}
    echo "Queue: $nWQ - Running: $nRQ" >&2
    echo "Queue: $nWQ - Running: $nRQ" >> $LOGFILE
    echo "" >> $LOGFILE

    if [ $nWQ -eq 0 ]; then
        echo ${runningQ[@]}
    elif [ $nRQ -lt $MAX_RUN ]; then
        new_job=${waitingQ[0]}
        # The run_a_process part to be replaced with desired application.
        #PID=`run_a_process $new_job`
        PID=`run_EURACE_model $new_job`
        runningQ+=($PID)
        waitingQ=("${waitingQ[@]:1}")
        result=`run_sims waitingQ[@] runningQ[@] $MAX_RUN`
        echo ${result[@]}
    else
        i=0
        while :
        do
            ind=`expr $i % $MAX_RUN`
            PID=${runningQ[ind]}
            kill -0 $PID
            EXIT_CODE=`echo $?`
            if [ $EXIT_CODE -ne 0 ]; then
                unset runningQ[ind]
                runningQ=( "${runningQ[@]}" )
                result=`run_sims waitingQ[@] runningQ[@] $MAX_RUN`
                echo ${result[@]}
                break
            fi
            i=`expr $i + 1`
        done
    fi
}


echo
echo "Configuring EURACE experiment set-up ..."
echo
echo "Collecting experiment inputs ..."
echo

# $1: Root folder of the experiment:
if [ -z $1 ]; then
    ROOTFOLDER=/home/superuser/EURACE/simulation/exp2
else
    ROOTFOLDER=$1
fi

# $2: Number of parallel runs
if [ -z $2 ]; then
    MAXRUN=64
else
    MAXRUN=$2
fi

# $3: Number of iterations at each run.
if [ -z $3 ]; then
    NITER=2400
else
    NITER=$3
fi


# $4: Output frequency of XMLs
if [ -z $4 ]; then
    XMLOUTF=`expr $NITER + 1`
else
    XMLOUTF=$4
fi

LOGFILE="$ROOTFOLDER/log_experiment_runtime.txt"
LOGFILE_EXE="$ROOTFOLDER/log_seeds_list.txt"


echo "The list of jobs/executables found:" > $LOGFILE
echo "" >> $LOGFILE

find  $ROOTFOLDER -name *.exe >> $LOGFILE
find  $ROOTFOLDER -name *.exe > $LOGFILE_EXE

WAITING=()
echo "The location of seeds are:"
echo
for path in `cat $LOGFILE_EXE`
do
    WAITING+=($path)
    echo $path
done
RUNNING=()



NPROCS=`getconf _NPROCESSORS_ONLN`
echo
echo "This host machine has $NPROCS processors."
echo "The given number of seeds is ${#WAITING[@]}."
echo "The given number of parallel runs is $MAXRUN."
echo


echo "Enter a new number if you want to change the number of parallel runs (or RETURN to skip)"
read X
if [ -n "$X" ]; then
    MAXRUN=$X
    echo
    echo "The number of parallel runs is changed to $MAXRUN."
fi



echo
echo "Running Monte Carlo experiments with EURACE Model ..."
echo


SECONDS=0
RESULT=`run_sims WAITING[@] RUNNING[@] $MAXRUN`
# RESULT is a string. Converting it into an array.
IFS=' ' read -r -a RUNNING <<< "$RESULT"

echo
echo "The PIDs of running simulations:"
# Checking both index and element.
for ind in "${!RUNNING[@]}"
do
    echo "$ind ${RUNNING[ind]}"
done

echo
echo "Waiting for the remaining simulations to be completed:"


nLeft=${#RUNNING[@]}
i=0
while [ $nLeft -gt 0 ]
do
    j=`expr $i % $nLeft`
    pid=${RUNNING[j]}
    kill -0 $pid
    EXIT_CODE=`echo $?`
    if [ $EXIT_CODE -ne 0 ]; then
        echo "$pid is completed."
        unset RUNNING[j]
        RUNNING=( "${RUNNING[@]}" )
        nLeft=${#RUNNING[@]}
        echo "Running: $nLeft"
        i=0
    fi
    i=`expr $i + 1`
done


echo
echo "The experiment is finished successfully in $SECONDS seconds. Enjoy analyzing your results!."
echo

echo "" >> $LOGFILE
echo "Total Simulation Time in Seconds: $SECONDS" >> $LOGFILE
echo "" >> $LOGFILE




