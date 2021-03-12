#! /bin/bash

## Dataset: tpch or finance
DATASET=tpch

## Calibrated run: 0 or 1
CALIBRATED=0

## Times for calibration and measurement proper
CALIB_T=20
RUN_T=60

## TPCH sizes for calibration and measurement proper
CALIB_S=2.0
RUN_S=8.0

##########################################################
rm -f arguments.sh
if [[ "${CALIBRATE}" -eq 1 ]]; then
    ## Perform a complete measurement sequence including calibration
    (cd data && rm -f tpch && ln -s tpch_${CALIB_S} tpch)
    echo "Dispatching calibration measurement"
    ./dispatch.sh ${CALIB_T} 0 0-11 11 ${DATASET} default calibrate

    echo "Generating measurement parameters"
    ./gen_arguments.r ${CALIB_T} > arguments.sh
fi

echo "Dispatching measurements proper"
## Replace tpch with finance to perform financial query measurements
(cd data && rm -f tpch && ln -s tpch_${RUN_S} tpch)
./dispatch.sh ${RUN_T} 0 0-11 11 ${DATASET} default measure
./dispatch.sh ${RUN_T} 1 0-11 11 ${DATASET} default measure
./dispatch.sh ${RUN_T} 1 0-11 11 ${DATASET} fifo    measure
./dispatch.sh ${RUN_T} 1 0-10 11 ${DATASET} shield  measure
./dispatch.sh ${RUN_T} 1 0-10 11 ${DATASET} shield+fifo  measure
