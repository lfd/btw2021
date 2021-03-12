source("base.r")

query.list <- c("1", "6", "11a") ## "2"
scenario <- "tpch"
cpu <- "x86"
os <- "linux"
meas <- "tsc"
DATADIR <- str_c(MEASDIR, "tpch/x86_tsc/")
baseline  <- "res_duration-60_stress-1_scenario-shield+fifo_measure"
OUTDIR <- str_c(PLOTDIR, "tpch/x86_tsc/")
exp.list  <- c("res_duration-60_stress-0_scenario-default_measure",
               "res_duration-60_stress-1_scenario-default_measure",
               "res_duration-60_stress-1_scenario-fifo_measure",
               "res_duration-60_stress-1_scenario-shield_measure",
               "res_duration-60_stress-1_scenario-shield+fifo_measure")
map.exp  <- c("res_duration-60_stress-0_scenario-default_measure"="No Load",
              "res_duration-60_stress-1_scenario-default_measure"="Load",
              "res_duration-60_stress-1_scenario-fifo_measure"="Load/FIFO",
              "res_duration-60_stress-1_scenario-shield+fifo_measure"="L/S/FIFO",
              "res_duration-60_stress-1_scenario-shield_measure"="Load/Shield")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query <- order.tpch.query(dat$query)

## Remove, for now, outliers that are known to be mendable by changing the measurement basis
## The specific cutoff is based on visual inspection
if (scenario=="tpch" && cpu=="x86" && meas=="tsc") {
    dat.pruned  <- rbindlist(list(dat[experiment=="res_duration-60_stress-1_scenario-default_measure" & latency < 10**8],
                                  dat[experiment!="res_duration-60_stress-1_scenario-default_measure" & latency < 45000,]))
}

g <- gen.latency.plot.by.experiment(dat.pruned[idx>10000], sample=TRUE, max.idx=5*10**5, scales.fixed=FALSE,
                                    divisor.x=10**5, divisor.y=1000, label.max=TRUE) +
    scale_x_continuous("100k Tuples Processed", breaks=c(0,1,2,3,4,5)) + ylab("Latency [k TSC Cycles]")
#ggsave(str_c(OUTDIR, "latencies_tpch_x86_tsc.png"), g, width=WIDTH.PAPER, height=0.75*WIDTH.PAPER, dpi=360, units="cm")
tikz(file=str_c(OUTDIR, "latencies_tpch_x86_tsc.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.75*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

span.tsc <- compute.span(dat.pruned[idx > 150000 & idx < 450000], map.exp)

g <- plot.span(span.tsc)
ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.PAPER, height=0.5*WIDTH.PAPER, units="cm")


#####################################################################################################################

##### TPCH/x86/clock
query.list <- c("1", "6", "11a") ## "2"
scenario <- "tpch"
cpu <- "x86"
os <- "linux"
meas <- "clock"
DATADIR <-  str_c(MEASDIR, "tpch/x86_clock/")
baseline  <- NULL
OUTDIR <- str_c(PLOTDIR, "tpch/x86_clock/")
exp.list  <- c("res_duration-60_stress-0_scenario-default_measure",
               "res_duration-60_stress-1_scenario-default_measure",
               "res_duration-60_stress-1_scenario-fifo_measure",
               "res_duration-60_stress-1_scenario-shield_measure",
               "res_duration-60_stress-1_scenario-shield+fifo_measure")
map.exp  <- c("res_duration-60_stress-0_scenario-default_measure"="No Load",
              "res_duration-60_stress-1_scenario-default_measure"="Load",
              "res_duration-60_stress-1_scenario-fifo_measure"="Load/FIFO",
              "res_duration-60_stress-1_scenario-shield+fifo_measure"="L/S/FIFO",
              "res_duration-60_stress-1_scenario-shield_measure"="Load/Shield")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query <- order.tpch.query(dat$query)

## Remove, for now, outliers that are known to be mendable by changing the measurement basis
## The specific cutoff is based on visual inspection
#if (scenario=="tpch" && cpu=="x86" && meas=="clock") {
#    dat.pruned  <- rbindlist(list(dat[experiment=="res_duration-60_stress-1_scenario-default_measure"],
#                                  dat[experiment!="res_duration-60_stress-1_scenario-default_measure" & latency < 1000000,]))
#}

dat.sub <- dat[experiment=="res_duration-60_stress-1_scenario-default_measure" |
               experiment=="res_duration-60_stress-1_scenario-shield+fifo_measure"]
dat.sub$experiment <- order.experiment(map.exp[dat.sub$experiment])
dat.sub$combine <- interaction(dat.sub$experiment, dat.sub$query, sep=" | ")
dat.sub$combine <- factor(dat.sub$combine, levels=c("Load | Q6", "Load | Q1", "Load | Q11a",
                                                    "L/S/FIFO | Q6",  "L/S/FIFO | Q1", "L/S/FIFO | Q11a"))

cond.exp <- function(x) {
    f <- function(.x) {
        if (is.na(.x)) return (NA)
        if (.x %% 1 != 0) {
            ## Non-Integer exponent, format as non-exponential
            return(prettyNum(10^.x, digits=3))
        } else {
            return(math_format(10^.x)(.x))
        }}
    
    sapply(x, f)
}

g <- gen.latency.plot.by.experiment(dat.sub, sample=TRUE, max.idx=5*10**5, scales.fixed=FALSE, alpha.line=0.25,
                                    divisor.x=10**5, divisor.y=1000, label.max=TRUE, facet.combine=TRUE) +
    xlab("100k Tuples Processed") + scale_y_log10("Latency [\\(\\mu\\)s, log]")
#, breaks = trans_breaks("log10", function(x) 10^x),
                                        #                                                  labels = trans_format("log10", math_format(10^.x)))
                                           #       labels = trans_format("log10", cond.exp))

##+ facet_wrap(combine~., ncol=3, scales="free")

#ggsave(str_c(OUTDIR, "latencies_tpch_x86_clock.png"), g, width=WIDTH.PAPER, height=0.5*WIDTH.PAPER, dpi=360, units="cm")
tikz(file=str_c(OUTDIR, "latencies_tpch_x86_clock.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.5*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

#g <- plot.span(dat[idx > 150000 & idx < 450000])
#ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.COL, height=0.5*WIDTH.COL)

##### Joint dataset plots

span.clock <- compute.span(dat[idx > 150000 & idx < 450000], map.exp)
span.tsc$measure <- "TSC"
span.clock$measure <- "Clock"

span.dat <- rbind(span.clock, span.tsc)
span.dat$experiment <- order.experiment(span.dat$experiment)
span.dat$measure <- factor(span.dat$measure, levels=c("TSC", "Clock"))

g <- plot.span(span.dat, multi=TRUE) + facet_grid(measure~query, scales="free_y")

#ggsave(str_c(OUTDIR, "../span_tpch.pdf"), g, width=WIDTH.PAPER, height=0.35*WIDTH.PAPER, units="cm")
tikz(file=str_c(OUTDIR, "../span_tpch.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.35*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

q("no")
