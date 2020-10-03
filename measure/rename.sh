#! /bin/bash

for file in *.tbl; do
	f=`basename $file`
	mv $file $f.csv
don
e