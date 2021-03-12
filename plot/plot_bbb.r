source("base.r")

### Finance/arm/clock
query.list <- c("axfinder", "pricespread", "countone")
scenario <- "finance"
cpu <- "arm"
os <- "rtems"
meas <- "clock"
DATADIR <- str_c(MEASDIR, "finance/arm_clock/")
baseline  <- "res_duration-20_stress-1_scenario-shield+fifo_measure"
OUTDIR <- str_c(PLOTDIR, "finance/arm_clock/")
exp.list  <- c("default")
map.exp  <- c("default"="RTEMS/ARM")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query  <- order.finance.query(dat$query)

## Skip the first few samples that warm up the caches
g <- gen.latency.plot.by.experiment(dat[idx>5], sample=TRUE, divisor.x=10**5, divisor.y=1000, label.max=TRUE) +
    xlab("100k Tuples Processed") + ylab("Latency [\\(\\mu\\)s]")

##ggsave(str_c(OUTDIR, "latencies_bbb.png"), g, width=WIDTH.COL, height=0.25*WIDTH.COL, dpi=300)
#ggsave(str_c(OUTDIR, "latencies_bbb.pdf"), g, width=WIDTH.PAPER, height=0.3*WIDTH.PAPER, units="cm")
tikz(file=str_c(OUTDIR, "latencies_bbb.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.3*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

#g <- compute.span(dat) + scale_y_continuous("Relative Span")
#ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.COL, height=0.25*WIDTH.COL) 

q("no")
