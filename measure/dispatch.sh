#! /bin/bash

if [[ $# -ne 6 ]]; then
    echo "Usage: $0 duration threads taskset_load taskset_measure scenario label"
    exit 2
fi

duration=$1      ## Measurement time per TPCH query in seconds
threads=$2       ## How many instances of each stressor (0 disables stress)
taskset_load=$3  ## Taskset for load cores
taskset_meas=$4  ## Taskset for measurement (i.e., payload) cores
scenario=$5      ## Scenario identifier (e.g., linuxrt)
label=$6         ## Identification label
LOGCOUNT=100

no_stressors=$(cat stressors | grep "^[^#;]" | wc -l)
stressor_timeout=$(($duration / $no_stressors))

stressjob=`mktemp`

echo "run sequential" > ${stressjob}
echo "timeout ${stressor_timeout}" >> ${stressjob}
echo >> ${stressjob}
cat stressors | grep "^[^#;]" | sed -e "s/\$/ $threads/" >> $stressjob

OUTDIR="res_duration-${duration}_threads-${threads}_scenario-${scenario}_${label}/"
rm -rf ${OUTDIR}

for i in {1..4} {6..14} {16..22}; do
        echo -n "Executing TPCH test ${i} (`date "+%H:%M:%S"`): ";
        mkdir -p ${OUTDIR}/${i};

	case ${scenario} in
	    fifo)
		tsm="taskset --cpu-list ${taskset_meas}"
		execstr="sudo chrt -f 99 linux/measure${i} --log-count=100 >> ${OUTDIR}/${i}/latencies.txt";
	    ;;
	    shield)
		sudo cset shield --cpu ${taskset_meas} --kthread=on
		tsm=""
		execstr="sudo cset shield --exec -- linux/measure${i} --log-count=100 | grep -v cset >> ${OUTDIR}/${i}/latencies.txt";
	    ;;
	    *)
		tsm="taskset --cpu-list ${taskset_meas}"
		execstr="linux/measure${i} --log-count=${LOGCOUNT} >> ${OUTDIR}/${i}/latencies.txt";
	    ;;
	esac

	cmd="${tsm} ${execstr}"
	
	echo "# stressors: ${no_stressors}" > ${OUTDIR}/${i}/info.txt
	echo "Time per stressor: ${stressor_timeout} [s]" >> ${OUTDIR}/${i}/info.txt
	echo "Taskset (load): ${taskset_load}" >> ${OUTDIR}/${i}/info.txt
	echo "Taskset (measurement): ${taskset_meas}" >> ${OUTDIR}/${i}/info.txt	
	echo "Kernel: `uname -a`" >> ${OUTDIR}/${i}/info.txt
	echo "Command: ${cmd}" >> ${OUTDIR}/${i}/info.txt
	
	if (( ${threads} > 0 )); then
	    	stress-ng --job ${stressjob} --taskset ${taskset_load} > ${OUTDIR}/${i}/stress-ng.log 2>&1 &
        	PID=$!;
        fi;

        timeout ${duration} bash -c "while true; do eval \"${cmd}\"; done";
        echo -n "finished (`date "+%H:%M:%S"`). Stressors: ";
	if (( ${threads} > 0 )); then wait ${PID}; fi;
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
