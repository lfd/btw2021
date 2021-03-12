source("base.r")

### Finance/x86 jailhouse/tsc
query.list <- c("axfinder", "pricespread", "countone")
scenario <- "finance"
cpu <- "x86"
os <- "jailhouse"
meas <- "tsc"
DATADIR <- str_c(MEASDIR, "finance/x86_jailhouse_tsc/")
baseline  <- "default"
OUTDIR <- str_c(PLOTDIR, "finance/x86_jailhouse_tsc/")
exp.list  <- c("noload", "load")
map.exp  <- c("noload"="No Load",
              "load"="Load")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query  <- order.finance.query(dat$query)

g <- gen.latency.plot.by.experiment(dat, sample=TRUE, divisor.x=10**5, divisor.y=1000, label.max=TRUE) +
    xlab("100k Tuples Processed") +  ylab("Latency [\\(\\mu\\)s]")
#ggsave(str_c(OUTDIR, "latencies_jh_x86.png"), g, width=WIDTH.PAPER, height=0.45*WIDTH.PAPER, dpi=300, units="cm")
tikz(file=str_c(OUTDIR, "latencies_jh_x86.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.45*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

span.jh <- compute.span(dat, map.exp)
#ggsave(str_c(OUTDIR, "span.pdf"), g, width=WIDTH.COL, height=0.25*WIDTH.COL)



################################################################################################
## Joint plots

## ARM/RTEMS
query.list <- c("axfinder", "pricespread", "countone")
scenario <- "finance"
cpu <- "arm"
os <- "rtems"
meas <- "clock"
DATADIR <- str_c(MEASDIR, "finance/arm_clock/")
baseline  <- "res_duration-20_stress-1_scenario-shield+fifo_measure"
OUTDIR <- str_c(PLOTDIR, "finance/arm_clock/")
exp.list  <- c("default")
map.exp  <- c("default"="No Load")

dat  <- rbindlist(lapply(exp.list, function(experiment) { read.experiment(query.list, experiment, verbose=TRUE) }))
dat$query  <- order.finance.query(dat$query)
span.bbb  <- compute.span(dat, map.exp)

span.bbb$measure <- "ARM"
span.jh$measure <- "x86/JH"
span.all <- rbind(span.bbb, span.jh)

span.all$query <- factor(span.all$query, levels=c("countone", "axfinder", "pricespread"))

g <- plot.span(span.all, multi=TRUE) + facet_grid(measure~query) + scale_y_continuous("Relative Span")
#ggsave(str_c(OUTDIR, "../span_bare.pdf"), g, width=WIDTH.PAPER, height=0.35*WIDTH.PAPER, units="cm")
tikz(file=str_c(OUTDIR, "../span_bare.tex"), width=WIDTH.PAPER*INCH.PER.CM, height=0.35*WIDTH.PAPER*INCH.PER.CM)
print(g)
dev.off()

q("no")
