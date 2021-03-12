read.experiment <- function(query.list, experiment, verbose=FALSE) {
  res <- rbindlist(lapply(query.list, function(i) {
    file <- str_c(DATADIR, experiment, "/", i, "/latencies.txt")
    if (verbose) {
       cat ("Processing ", file, " (limited to 4M entries)\n")
    }
    res <- fread(file, header=FALSE, nrows=4000000)
    dat <- data.table(idx=res$V1, time=res$V2, latency=res$V3,
                      query=i, experiment=experiment)

    return(dat)
  }))

  return(res)
}

compute.diffs  <- function(dat, .query, BASELINE) {
    dat.baseline  <- dat[query==.query & experiment==BASELINE]
    
    cat("Processing query ", .query, "\n")
    res <- rbindlist(lapply(exp.list, function(exp) {
        cat("Processing experiment ", exp, "\n")
        dat.cmp <- dat[query==.query & experiment==exp]

        ## Ensure the comparison is performed on the same number of rows
        num.rows  <- min(max(dat.baseline[,idx]), max(dat.cmp[,idx]))
        dat.baseline <- dat.baseline[1:num.rows]
        dat.cmp <- dat.cmp[1:num.rows]

        ## Sanity check to ensure that indices match up pairwise
        if (any((dat.cmp[,idx]-dat.baseline[,idx]) != 0)) {
            cat("Internal error: row indices don't match up for ", exp, "!\n")
            browser()
            return(NULL)
        }

        return(data.table(idx=dat.cmp[,idx], query=.query, compare=exp,
                          diff=dat.cmp[,latency]-dat.baseline[,latency],
                          diffabs=abs(dat.cmp[,latency]-dat.baseline[,latency])))
                   
    }))

    return(na.omit(res))
}

sample.plot <- function(dat, i, sample.rate, delta, max.idx=0, sample=TRUE) {
    dat.sub <- dat[query==i,]
    if (max.idx) {
        dat.sub <- dat.sub[idx <= max.idx]
    }

    dat.sub$type="Extreme Value"
    dat.sub$rmean <- runmean(dat.sub$latency, 1000)

    if (sample) {
        dat.samp  <- sample_frac(dat.sub, sample.rate)
        dat.samp$type="Standard Value"
        dat.plot <- do.call(rbind, list(dat.samp, dat.sub[dat.sub$latency > quantile(dat.sub$latency, 1-delta/2),],
                                        dat.sub[dat.sub$latency < quantile(dat.sub$latency, delta/2),]))
        return(dat.plot)
    }

    return(dat.plot)
}

gen.latency.plot.by.experiment <- function(dat, sample=FALSE, sample.rate=0.001, delta=0.001, max.idx=0,
                                           scales.fixed=TRUE, alpha.line=0.75, divisor.x=1, divisor.y,
                                           label.max=FALSE, facet.combine=FALSE) {
    dat.plot  <- rbindlist(lapply(unique(dat$query), function(i) {
        sample.plot(dat, i, sample.rate, delta, max.idx)
    }))

    exp.labeller <- function(variable, value){
        return(map.exp[value])
    }

    if (label.max && !facet.combine) {
        dat.max  <- dat.plot %>% group_by(experiment,query) %>% summarise(max=max(latency))
        dat.min  <- dat.plot %>% group_by(experiment,query) %>% summarise(min=min(latency))
        dat.max  <- left_join(dat.plot, dat.max) %>% mutate(select = latency==max) %>% filter(select==TRUE) %>%
            select(idx, time, latency, query, type, experiment)
        dat.min  <- left_join(dat.plot, dat.min) %>% mutate(select = latency==min) %>% filter(select==TRUE) %>%
            select(idx, time, latency, query, type, experiment)
    }

    if (label.max && facet.combine) {
        dat.max  <- dat.plot %>% group_by(combine) %>% summarise(max=max(latency))
        dat.min  <- dat.plot %>% group_by(combine) %>% summarise(min=min(latency))
        dat.max  <- left_join(dat.plot, dat.max) %>% mutate(select = latency==max) %>% filter(select==TRUE) %>%
            select(idx, time, latency, type, combine)
        dat.min  <- left_join(dat.plot, dat.min) %>% mutate(select = latency==min) %>% filter(select==TRUE) %>%
            select(idx, time, latency, type, combine)
    }

    
    if (sample) {
        g  <- ggplot(dat.plot, aes(x=idx/divisor.x, y=latency/divisor.y, colour=type))
    } else {
        g  <- ggplot(dat.plot, aes(x=idx/divisor.x, y=latency/divisor.y))
    }
    g <- g + geom_point_rast(size=0.2, stroke=0.2)
    if (scales.fixed) {
        if (facet.combine) {
            g <- g + facet_wrap(combine~., ncol=3)
        } else {
            g <- g + facet_grid(experiment~query, labeller=labeller(experiment=map.exp))
        }
    } else {
        if (facet.combine) {
            g <- g + facet_wrap(combine~., ncol=3, scales="free")
        } else {
            g <- g + facet_grid(experiment~query, labeller=labeller(experiment=map.exp), scales="free")
        }

    }
    g  <- g + scale_colour_manual("Observation", values=c("#999999", "#E69F00"),
                                  guide=guide_legend(keywidth=2, keyheight=2, default.unit="mm",
                                                     override.aes = list(size=1))) +
        theme_paper() +  theme(legend.position="top", legend.box.margin = margin(-0.2, 0, -0.25, 0, "cm")) +
        geom_line(aes(x=idx/divisor.x, y=rmean/divisor.y), size=0.2, colour="red", alpha=alpha.line)

    if (label.max) {
        g  <- g + geom_point(data=dat.max, inherit.aes=TRUE, colour="red", shape=2, size=0.5) +
            geom_label_repel(data=dat.max, inherit.aes=TRUE, show.legend=FALSE, size=1.8,
                       aes(label=signif(latency/divisor.y,digits=3), hjust=0, vjust=0.5, alpha=0), nudge_x=0.1, label.padding=unit(0.25, "mm"), colour="black")
        g  <- g + geom_point(data=dat.min, inherit.aes=TRUE, colour="red", shape=2, size=0.5) +
            geom_label_repel(data=dat.min, inherit.aes=TRUE, show.legend=FALSE, size=1.8,
                      aes(label=signif(latency/divisor.y,digits=3), hjust=1, vjust=0.5, alpha=0), nudge_x=-0.1, label.padding=unit(0.25, "mm"), colour="black")
    }
        
    return(g)
}

gen.latency.plots.by.query <- function(dat, sample=FALSE, sample.rate=0.001, delta=0.001, max.idx=0, title.pfx="TPCH query") {
    plts  <- lapply(unique(dat$query), function(i) {
        dat.plot <- sample.plot(dat, i, sample.rate, delta, max.idx)

        cat("Plotting graph for experiment ", i, "\n")
        exp.labeller <- function(variable, value){
            return(map.exp[value])
        }
        
        if (sample) {
            g  <- ggplot(dat.plot, aes(x=idx, y=latency, colour=type))
        } else {
            g  <- ggplot(dat.plot, aes(x=idx, y=latency))
        }
        g <- g + geom_point(size=0.1) + facet_grid(experiment~., scale="free",
                                              labeller=labeller(experiment=map.exp)) +
            ggtitle(str_c(title.pfx, " ", i)) + scale_colour_manual("Observation",
                                                                       values=c("#999999", "#E69F00")) +
            geom_line(aes(x=idx, y=rmean), inherit.aes=FALSE, colour="#009371", size=0.5) + scale_y_sqrt() +
            theme_paper() + theme(legend.position="top")
        ##            scale_y_log10(limits=c(0.8*quantile(dat.sub$latency, QUANTILE.LOWER), max(dat.sub$latency)))
 #           geom_hline(yintercept=quantile(dat.sub$latency, QUANTILE.LOWER), colour="red", size=1) +
 #           geom_hline(yintercept=quantile(dat.sub$latency, QUANTILE.UPPER), colour="red", size=1) +

    })
    return(plts)
}

save.latency.plots  <- function(plts, outdir, label.x, label.y,
                                .width=WIDTH.COL, .height=WIDTH.COL, sfx="") {
    dummy  <- lapply(1:length(plts), function(i) {
        filename  <- str_c(OUTDIR, "/latency_", i, sfx, ".png")
        cat("Saving ", filename, "\n")
        png(filename, units="cm", width=.width, height=.height, res=250)
        g  <- plts[[i]] + xlab(label.x) + ylab(label.y)
        print(g)
        dev.off()
    })
}

do.diff.plots <- function(diff.all) {
    dummy  <- lapply(unique(diff.all$query), function(.query) {
        png(str_c(OUTDIR, "/plots_diff", .query, ".png"), width=20, height=6, units="in", res=250)
        cat("Processing query ", .query, "\n")
        g <- ggplot(sample_frac(diff.all[query==.query], 0.05), aes(x=idx, y=diff)) + geom_point(size=0.1) +
            facet_grid(compare~., labeller=labeller(compare=map.exp)) + ylim(-5000, 12500) +
            ggtitle(str_c("Query: ", .query)) 
        print(g)
        dev.off()
    })
}


q1 <- function(x) { quantile(x, c(0.25))}
q2 <- function(x) { quantile(x, c(0.5))}
q3 <- function(x) { quantile(x, c(0.75))}

#scientific_10 <- function(x) {
#  parse(text=gsub("e", "%*%10^", scales::scientific_format()(x)))
#}

scientific_10 <- function(x) {
    x <- scales::scientific_format()(x)
    x <- gsub("1e+00", "10^0", x, fixed=TRUE)
    x <- gsub("+0", "", x, fixed=TRUE)
    x <- gsub("e", "%.%10^", x)
    return(parse(text=x))
}

theme_paper <- function() {
    return(theme_light(base_size=BASE.SIZE) +
           theme(axis.title.x = element_text(size = BASE.SIZE),
                 axis.title.y = element_text(size = BASE.SIZE),
                 legend.title = element_text(size = BASE.SIZE)))
}

compute.span <- function(dat, map.exp)  {
    res  <- dat[, .(scale.up=max(latency)/q2(latency), scale.down=q2(latency)/min(latency)), by=.(experiment, query)]
    res$experiment <- map.exp[res$experiment]
    res.molten <- melt(res, id.vars=c("experiment", "query"))

    return(res.molten)
}

plot.span <- function(res, multi=FALSE) {
    g  <- ggplot(res, aes(x=experiment, y=value, fill=variable)) + geom_bar(position="dodge", stat="identity")
    if (multi) {
        g  <- g + facet_grid(measure~query, scales="free_y")
    } else {
        g  <-  g +  facet_wrap(~query)
    }

    g <- g + xlab("") + scale_fill_manual("",
                                          values=c("#999999", "#E69F00"), labels=c("Maximum", "Minimum"),
                                          guide=guide_legend(override.aes = list(size=0.25))) +
        theme_paper() + theme(axis.text.x = element_text(angle = 20, vjust=0.6, hjust=0.5)) +
        xlab("") + scale_y_log10("Relative Span [log]", breaks = trans_breaks("log10", function(x) 10^x),
                                 labels = trans_format("log10", math_format(10^.x))) 
        
    return(g)
}

order.finance.query <- function(dat.query) {
    return(factor(dat.query, levels=c("countone", "countone_nostream", "axfinder", "pricespread")))
}


order.tpch.query <- function(dat.query) {
    return(factor(dat.query, levels=c("6", "1", "11a"),
                  labels=c("Q6", "Q1", "Q11a")))
}

order.experiment <- function(dat.exp) {
    return(factor(dat.exp, levels=c("No Load", "Load", "Load/FIFO", "Load/Shield", "L/S/FIFO")))
}


