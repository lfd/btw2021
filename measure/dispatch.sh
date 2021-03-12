#! /bin/bash

if [[ $# -ne 7 ]]; then
    echo "Usage: $0 duration stress taskset_load taskset_measure dataset scenario label"
    exit 2
fi

duration=$1      ## Duration of the measurement
stress=$2        ## Run stress tests (0=no, 1=yes)
taskset_load=$3  ## Taskset for load cores
taskset_meas=$4  ## Taskset for measurement (i.e., payload) cores
dataset=$5;      ## Dataset
scenario=$6      ## Scenario identifier (e.g., linuxrt)
label=$7         ## Identification label
LOGCOUNT=1

##no_stressors=$(cat stressors | grep "^[^#;]" | wc -l)
##stressor_timeout=$(($duration / $no_stressors))

##stressjob=`mktemp`

##echo "run sequential" > ${stressjob}
##echo "timeout ${stressor_timeout}" >> ${stressjob}
##echo >> ${stressjob}
##cat stressors | grep "^[^#;]" | sed -e "s/\$/ $threads/" >> $stressjob

OUTDIR="res_duration-${duration}_stress-${stress}_scenario-${scenario}_${label}/"

if [ -f "arguments.sh" ]; then
    . arguments.sh
else
    declare -A arguments=()
fi

case "${dataset}" in
    tpch)
	queries="1 2 6 12 14 11a 18a"
    ;;
    finance)
	queries="vwap axfinder pricespread brokerspread missedtrades"
    ;;
    *)
	echo "Unknown measurement ${MEASURE} specified!"
	exit
esac;


for i in ${queries}; do
    echo -n "Executing query ${dataset}${i} (`date "+%H:%M:%S"`): ";
    rm -rf ${OUTDIR}/${i};
    mkdir -p ${OUTDIR}/${i};
    dbt="linux/${dataset}${i} --log-count=${LOGCOUNT} --no-output --timeout=${duration} ${arguments['${i}']}"
	
    if [[ "${dataset}" == "finance" ]]; then
	dbt="${dbt} --iterations=50"
    fi;
	
    case "${scenario}" in
	fifo)
	    tsm="taskset --cpu-list ${taskset_meas}";
	    execstr="sudo chrt -f 98 ${dbt} > ${OUTDIR}/${i}/latencies.txt";
	    ;;
	shield)
	    sudo cset shield --cpu ${taskset_meas} --kthread=on;
	    tsm="";
	    execstr="sudo cset shield --exec -- ${dbt} 2>&1 | grep -v cset > ${OUTDIR}/${i}/latencies.txt";
	    ;;
	shield+fifo)
	    sudo cset shield --cpu ${taskset_meas} --kthread=on;
	    tsm="";
	    execstr="sudo cset shield --exec -- sudo chrt -f 98 ${dbt} 2>&1 | grep -v cset > ${OUTDIR}/${i}/latencies.txt";
	    ;;
	default)
	    tsm="taskset --cpu-list ${taskset_meas}"
	    execstr="${dbt} > ${OUTDIR}/${i}/latencies.txt";
	    ;;
	*)
	    echo "Scenario ${scenario} is not known!"
	    exit
	    ;;
    esac

    cmd="${tsm} ${execstr}"
	
    echo "Measurement summary" > ${OUTDIR}/${i}/info.txt
    ##	echo "# stressors: ${no_stressors}" > ${OUTDIR}/${i}/info.txt
    ##	echo "Time per stressor: ${stressor_timeout} [s]" >> ${OUTDIR}/${i}/info.txt
    echo "Taskset (load): ${taskset_load}" >> ${OUTDIR}/${i}/info.txt
    echo "Taskset (measurement): ${taskset_meas}" >> ${OUTDIR}/${i}/info.txt	
    echo "Kernel: `uname -a`" >> ${OUTDIR}/${i}/info.txt
    echo "Command: ${cmd}" >> ${OUTDIR}/${i}/info.txt
	
    if (( ${stress} > 0 )); then
	stress-ng --bsearch 0 --matrix 0 --zlib 0 --cache 0 --iomix 0 --timer 0  --metrics-brief --taskset ${taskset_load} -t ${duration} > ${OUTDIR}/${i}/stress-ng.log 2>&1 &
        PID=$!;
    fi;

  ##      timeout ${duration} bash -c "while true; do eval \"${cmd}\"; done";
    eval "${cmd}";
    echo -n "finished (`date "+%H:%M:%S"`). Stressors: ";
    if (( ${stress} > 0 )); then
	sudo kill -s SIGINT ${PID} > /dev/null 2>&1 # We need to send the signal as root because chrt and cset tasks run with root privileges
	wait ${PID};
    fi;
    echo "finished.";
    
    case ${scenario} in
	shield|shield+fifo)
	    sudo cset shield -r
	    ;;
	*)
	    ;;
    esac
done

rm -rf ${stressjob}
