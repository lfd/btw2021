#! /bin/bash

if [[ $# -ne 6 ]]; then
    echo "Usage: $0 stress taskset_load taskset_measure scenario label"
    exit 2
fi

duration=$1      ## Duration of the measurement
stress=$2        ## Run stress tests (0=no, 1=yes)
taskset_load=$3  ## Taskset for load cores
taskset_meas=$4  ## Taskset for measurement (i.e., payload) cores
scenario=$5      ## Scenario identifier (e.g., linuxrt)
label=$6         ## Identification label
LOGCOUNT=10

##no_stressors=$(cat stressors | grep "^[^#;]" | wc -l)
##stressor_timeout=$(($duration / $no_stressors))

##stressjob=`mktemp`

##echo "run sequential" > ${stressjob}
##echo "timeout ${stressor_timeout}" >> ${stressjob}
##echo >> ${stressjob}
##cat stressors | grep "^[^#;]" | sed -e "s/\$/ $threads/" >> $stressjob

OUTDIR="res_duration-${duration}_stress-${stress}_scenario-${scenario}_${label}/"
rm -rf ${OUTDIR}

#for i in {1..4} {6..14} {16..22}; do
for i in 1 6 12; do
        echo -n "Executing TPCH test ${i} (`date "+%H:%M:%S"`): ";
        mkdir -p ${OUTDIR}/${i};

	case "${scenario}" in
	    fifo)
		tsm="taskset --cpu-list ${taskset_meas}";
		execstr="sudo chrt -f 99 linux/measure${i} --log-count=${LOGCOUNT} >> ${OUTDIR}/${i}/latencies.txt";
	    ;;
	    shield)
		sudo cset shield --cpu ${taskset_meas} --kthread=on;
		tsm="";
		execstr="sudo cset shield --exec -- linux/measure${i} --log-count=${LOGCOUNT} | grep -v cset >> ${OUTDIR}/${i}/latencies.txt";
	    ;;
	    default)
		tsm="taskset --cpu-list ${taskset_meas}"
		execstr="linux/measure${i} --log-count=${LOGCOUNT} >> ${OUTDIR}/${i}/latencies.txt";
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
	eval "timeout --signal=INT ${duration} ${cmd}";
        echo -n "finished (`date "+%H:%M:%S"`). Stressors: ";
	if (( ${stress} > 0 )); then
	    kill -s SIGINT ${PID}
	    wait ${PID};
	fi;
	echo "finished.";

	case ${scenario} in
	    shield)
		sudo cset shield -r
	    ;;
	    *)
	    ;;
	esac
done

rm -rf ${stressjob}
