#!/usr/bin/env Rscript

library(stringr)
library(data.table)
source("lib.r")

DELTA <- 0.001
QUANTILE.LOWER <- DELTA
QUANTILE.UPPER <- (1-DELTA)

args = commandArgs(trailingOnly=TRUE)

if (length(args) != 1) {
   cat("Please specify length of calibration measurement")
   stop()
}

tpch.list <- c(1,2,6,"11a",12,14,"18a")

dat <- read.experiment(tpch.list, str_c("res_duration-", args[1], "_stress-0_scenario-default_calibrate"))

## Generate a bash hash table with measurement specific lower and upper latency bound arguments
gen.args.hash <- function(dat) {
  res <- dat[, .(lwr=quantile(latency, QUANTILE.LOWER), med=quantile(latency, 0.5), upr=quantile(latency, QUANTILE.UPPER),
                 min=min(latency), max=max(latency), .N), by=tpch]
  cmd <- str_c("declare -A arguments=(\n",
               paste(lapply(res$tpch, function(i) {
                  str_c("['", i, "']='--lower-lat=", res[tpch==i,]$lwr, " --upper-lat=", res[tpch==i,]$upr, "'")
               }), sep="", collapse="\n" ),
	       "\n)\n")
  return(cmd)
}

args.dat <- gen.args.hash(dat)
save(dat, file="dat.rdata")

cat(args.dat)
