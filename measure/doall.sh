#! /bin/bash

## Times for calibration and measurement proper
CALIB_T=20
RUN_T=60

## TPCH sizes for calibration and measurement proper
CALIB_S=2.0
RUN_S=8.0

##########################################################
## Perfom a complete measurement sequence including calibration
rm -f arguments.sh
(cd data && rm -f tpch && ln -s tpch_${CALIB_S} tpch)
echo "Dispatching calibration measurement"
./dispatch.sh ${CALIB_T} 0 0-11 11 default calibrate

echo "Generating measurement parameters"
./gen_arguments.r ${CALIB_T} > arguments.sh

echo "Dispatching measurements proper"
(cd data && rm -f tpch && ln -s tpch_${RUN_S} tpch)
./dispatch.sh ${RUN_T} 0 0-11 11 default measure
./dispatch.sh ${RUN_T} 1 0-11 11 default measure
./dispatch.sh ${RUN_T} 1 0-11 11 fifo    measure
./dispatch.sh ${RUN_T} 1 0-10 11 shield  measure
