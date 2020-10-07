read.experiment <- function(tpch.list, experiment, verbose=FALSE) {
  res <- do.call(rbind, lapply(tpch.list, function(i) {
    file <- str_c(experiment, "/", i, "/latencies.txt")
    if (verbose) {
       cat ("Processing ", file, "\n")
    }
    res <- fread(file, header=FALSE)
    dat <- data.table(idx=res$V1, time=res$V2, latency=res$V3,
                      query=i, experiment=experiment)

    return(dat)
  }))

  return(res)
}
