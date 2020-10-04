#!/usr/bin/env Rscript

library(stringr)
library(data.table)
source("lib.r")

args = commandArgs(trailingOnly=TRUE)
#tpch.list <- c(1:4, 6:14, 16:22)
tpch.list <- c(1,2,6,"11a",12,14,"18a")

if (length(args) == 0) {
  cat("Please specify which result folder to collect into a data frame\n")
  stop()
}

dat.all <- rbindlist(lapply(args, function(experiment) {
  read.experiment(tpch.list, experiment, verbose=TRUE)
}))

save(dat.all, file="dat.all.rdata")

