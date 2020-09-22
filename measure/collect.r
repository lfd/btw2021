#!/usr/bin/env Rscript

library(stringr)

args = commandArgs(trailingOnly=TRUE)
tpch.list <- c(1:4, 6:14, 16:22)

if (length(args) == 0) {
  cat("Please specify which result folder to collect into a data frame\n")
  stop()
}

read.experiment <- function(tpch.list, experiment) {
  res <- do.call(rbind, lapply(tpch.list, function(i) {
    file <- str_c(experiment, "/", i, "/latencies.txt")
    dat <- data.frame(latency=read.table(file, header=FALSE)$V1,
                      tpch=i, experiment=experiment)
    return(dat)
  }))

  return(res)
}


dat.all <- do.call(rbind, lapply(args, function(experiment) {
  read.experiment(tpch.list, experiment)
}))

save(dat.all, file="dat.all.rdata")
