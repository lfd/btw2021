#! /bin/bash

# dbgen has a tendency to occasionally leave files unreadable
# to anyone, so fix permissions first
chmod a+rw *.tbl

for file in *.tbl; do
	f=`basename $file .tbl`
	mv ${file} ${f}.csv
done
