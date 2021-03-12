source("base.r")
set.seed(19101978)

## Finance/x86/tsc
#query.list <- c("axfinder", "pricespread", "countone", "countone_nostream")
query.list <- c("axfinder", "pricespread", "countone_nostream")
scenario <- "finance"
cpu <- "x86"
os <- "linux"
meas <- "tsc"
DATADIR <- str_c(MEASDIR, "finance/x86_tsc/")
baseline  <- "res_duration-20_stress-1_scenario-shield+fifo_measure"
OUTDIR <- str_c(PLOTDIR, "finance/x86_tsc/")
exp.list  <- c("res_duration-20_stress-0_scenario-default_measure",
               "res_duration-20_stress-1_scenario-default_measure",
               "res_duration-20_stress-1_scenario-fifo_measure",
               "res_duration-20_stress-1_scenario-shield_measure",
               "res_duration-20_stress-1_scenario-shield+fifo_measure")
map.exp  <- c("res_duration-20_stress-0_scenario-default_measure"="No Load",
              "res_duration-20_stress-1_scenario-default_measure"="Load",
              "res_duration-20_stress-1_scenario-fifo_measure"="Load/FIFO",
              "res_duration-20_stress-1_scenario-shield+fifo_measure"="L/S/FIFO",
              "res_duration-20_stress-1_scenario-shield_measure"="Load/Shield")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query  <- order.finance.query(dat$query)

## Remove, for now, outliers that are known to be mendable by changing the measurement basis
## The specific cutoff is based on visual inspection
if (scenario=="finance" && cpu=="x86" && meas=="tsc") {
    dat.pruned  <- rbindlist(list(dat[experiment=="res_duration-60_stress-1_scenario-default_measure"],
                                  dat[experiment!="res_duration-60_stress-1_scenario-default_measure" & latency < 45000,]))
}
dat.pruned[dat.pruned$query=="countone_nostream",]$query  <- "countone"

#g <- gen.latency.plot.by.experiment(dat.pruned[idx>10000], sample=TRUE, max.idx=5*10**5, divisor.x=10**5, divisor.y=1000) +
#    scale_x_continuous("100k Tuples Processed", breaks=c(0,1,2,3,4,5)) + ylab("Latency [k TSC Cycles]")

## Ignore first cache-warm-up operations
g <- gen.latency.plot.by.experiment(dat.pruned[dat.pruned$idx > 5,], sample=TRUE, max.idx=5*10**5, divisor.x=10**5, divisor.y=1000, scales.fixed=FALSE, label.max=TRUE) +
    scale_x_continuous("100k Tuples Processed", breaks=c(0,1,2,3,4,5)) + ylab("Latency [k TSC Cycles]")
#ggsave(str_c(OUTDIR, "latencies_finance_x86_tsc.png"), g, width=WIDTH.PAPER, height=0.75*WIDTH.PAPER, dpi=720, units="cm")
tikz(file=str_c(OUTDIR, "latencies_finance_x86_tsc.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.75*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

#g <- compute.span(dat.pruned[idx > 150000 & idx < 450000])
#ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.PAPER, height=0.5*WIDTH.PAPER, units="cm")

q("no")

###############################################################################################################################

## Finance/x86/clock
query.list <- c("axfinder", "pricespread", "countone")
scenario <- "finance"
cpu <- "x86"
os <- "linux"
meas <- "clock"
DATADIR <- str_c(MEASDIR, "finance/x86_clock/")
baseline  <- "res_duration-20_stress-1_scenario-shield+fifo_measure"
OUTDIR <- str_c(PLOTDIR, "finance/x86_clock/")
exp.list  <- c("res_duration-20_stress-0_scenario-default_measure",
               "res_duration-20_stress-1_scenario-default_measure",
               "res_duration-20_stress-1_scenario-fifo_measure",
               "res_duration-20_stress-1_scenario-shield_measure",
               "res_duration-20_stress-1_scenario-shield+fifo_measure")
map.exp  <- c("res_duration-20_stress-0_scenario-default_measure"="No Load",
              "res_duration-20_stress-1_scenario-default_measure"="Load",
              "res_duration-20_stress-1_scenario-fifo_measure"="Load/FIFO",
              "res_duration-20_stress-1_scenario-shield+fifo_measure"="L/S/FIFO",
              "res_duration-20_stress-1_scenario-shield_measure"="Load/Shield")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query  <- order.finance.query(dat$query)

## Remove, for now, outliers that are known to be mendable by changing the measurement basis
## The specific cutoff is based on visual inspection
if (scenario=="finance" && cpu=="x86" && meas=="clock") {
    dat.pruned  <- rbindlist(list(dat[experiment=="res_duration-60_stress-1_scenario-default_measure"],
                                  dat[experiment!="res_duration-60_stress-1_scenario-default_measure" & latency < 50000,]))
}

#g <- gen.latency.plot.by.experiment(dat.pruned[idx>10000], sample=TRUE, max.idx=5*10**5, divisor.x=10**5, divisor.y=1000) +
#    scale_x_continuous("100k Tuples Processed", breaks=c(0,1,2,3,4,5)) + ylab(expression(paste("Latency [", mu, "s]")))
#ggsave(str_c(OUTDIR, "latencies.png"), g, width=WIDTH.PAPER, height=0.75*WIDTH.PAPER, dpi=360, units="cm")

#g <- compute.span(dat.pruned[idx > 150000 & idx < 450000])
#ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.PAPER, height=0.5*WIDTH.PAPER, units="cm")

q("no")
