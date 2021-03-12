library(ggplot2)
library(stringr)
library(plyr)
library(dplyr)
library(data.table)
library(reshape2)
library(caTools)
library(xtable)
library(scales)
library(ggrepel)
library(ggrastr)
library(tikzDevice)

WIDTH.PAPER <- 12.6
WIDTH.COL <- 12.6
INCH.PER.CM <- 0.394
BASE.SIZE <- 8
MEASDIR  <- "/Users/wolfgang/papers/btw2021/meas/"
PLOTDIR  <- "/Users/wolfgang/papers/btw2021/plots/"
INCH.PER.CM <- 0.394
source("lib.r")

options(tikzDocumentDeclaration = "\\documentclass[english]{lni}")
options(tikzLatexPackages = c(
             getOption( "tikzLatexPackages" ),
             "\\usepackage{amsmath}
              \\usepackage[utf8]{inputenc}
              \\usepackage[T1]{fontenc}"
         ))
