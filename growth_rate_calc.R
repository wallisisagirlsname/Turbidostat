#set working dir to location of dat files
# V. IMPORTANT. CHANGE THIS SO I DON'T OVERWRITE EXISTING FILES.
setwd("/Users/andrewmorgenthaler/Google Drive/MCDB/Copley/AMorgenthaler_lab_notebook/data_files/turbidostat/2017-03-27_Sphingobium_TNseq_1/")

#see what files are in there
list.files(getwd())

# CHANGE THESE OBJECTS BEFORE RUNNING THE SCRIPT
# which chambers weren't used?
notused <- c()
# set t to the time corresponding with the number of chambers used in this experiment (see table below). 
#   Chamber   time (sec)
#   1         8
#   2         10
#   3         12
#   4         14
#   5         18
#   6         20
#   7         22
#   8         24
t <- 24
# Number of seconds after last dilution to pull OD measurements
s <- 16


# import log.dat file into R
odlog <- read.table(file = "odlog.dat",sep = "",fill=TRUE,col.names = c("timestamp","rx.1","tx.1","rx.2","tx.2","rx.3","tx.3","rx.4","tx.4","rx.5","tx.5","rx.6","tx.6","rx.7","tx.7","rx.8","tx.8"))

# stack odlog and calculate rx/tx
odlog.long <- reshape(odlog, 
                      varying = list(c("rx.1","rx.2","rx.3","rx.4","rx.5","rx.6","rx.7","rx.8"),c("tx.1","tx.2","tx.3","tx.4","tx.5","tx.6","tx.7","tx.8")),
                      v.names = c("rx","tx"),
                      direction="long")
odlog.long <- odlog.long[,1:4]
colnames(odlog.long)[2] <- "chamber"
odlog.long$msrmnt.ratio <- odlog.long$tx/odlog.long$rx

# get rid of chambers for odlog that weren't used. Change this for each experiment.
odlog.long <- odlog.long[!(odlog.long$chamber %in% notused),]
# check to make sure the chambers not in use were properly removed and that each chamber 
# has the same number of rows. 
tapply(odlog.long$timestamp,INDEX = odlog.long$chamber, FUN = length)

# import log.dat file into R and clean up
log <- read.table(file = "log.dat",sep = ",",col.names = c("timestamp","OD.1","OD.2","OD.3","OD.4","OD.5","OD.6","OD.7","OD.8","dil.1","dil.2","dil.3","dil.4","dil.5","dil.6","dil.7","dil.8","avgdil.1","avgdil.2","avgdil.3","avgdil.4","avgdil.5","avgdil.6","avgdil.7","avgdil.8"))
log$timestamp <- as.numeric(gsub(pattern = "{timestamp: ","",x = log$timestamp, fixed = TRUE))
log$OD.1 <- as.numeric(gsub(pattern = "ods: [","",x = log$OD.1, fixed = TRUE))
log$OD.8 <- as.numeric(gsub(pattern = "]","",x = log$OD.8, fixed = TRUE))
log$dil.1 <- as.integer(gsub(pattern = "u: [","",x = log$dil.1, fixed = TRUE))
log$dil.8 <- as.integer(gsub(pattern = "]","",x = log$dil.8, fixed = TRUE))
log$avgdil.1 <- as.numeric(gsub(pattern = "z: [","",x = log$avgdil.1, fixed = TRUE))
log$avgdil.8 <- as.numeric(gsub(pattern = "]}","",x = log$avgdil.8, fixed = TRUE))

#keep only timestamp and OD columns
log <- log[,1:9]

#stack columns
log.long <- reshape(log, 
                    varying = c("OD.1","OD.2","OD.3","OD.4","OD.5","OD.6","OD.7","OD.8"),
                    v.names = "OD",
                    direction="long")
colnames(log.long)[2] <- "chamber"

# get rid of chambers for log that weren't used. Refer to notused object above.
log.long <- log.long[!(log.long$chamber %in% notused),]

#import blank.dat file, stack it, and calculate btx/brx ratio for each chamber
blank <- read.table(file = "blank.dat",sep = "",col.names = c("brx.1","btx.1","brx.2","btx.2","brx.3","btx.3","brx.4","btx.4","brx.5","btx.5","brx.6","btx.6","brx.7","btx.7","brx.8","btx.8"))
blank.long <- reshape(blank, 
                      varying = list(c("brx.1","brx.2","brx.3","brx.4","brx.5","brx.6","brx.7","brx.8"),c("btx.1","btx.2","btx.3","btx.4","btx.5","btx.6","btx.7","btx.8")),
                      v.names = c("brx","btx"),
                      direction="long")
blank.long <- blank.long[,1:3]
colnames(blank.long)[1] <- "chamber"
blank.long$blank.ratio <- blank.long$btx/blank.long$brx

# get rid of chambers for blank that weren't used. Refer to notused object above.
blank.long <- blank.long[!(blank.long$chamber %in% notused),]

# convert light readings into OD's on "odlog.long" by first merging the btx/brx ratio to the odlog.long df
# then calculating OD with equation -log10(msrmnt.ratio/blank.ratio)
odlog.long$blank.ratio <- rep(blank.long$blank.ratio, each = nrow(odlog))
odlog.long$OD <- -log10(odlog.long$msrmnt.ratio/odlog.long$blank.ratio)

# make subset of odlog with necessary rows to calculate growth rate 
# (i.e. reading immediately after dilution and right before next dilution)
#...but not all timestamps from "log" are in "odlog.long" so I need to selectively import
#those rows w/ OD's into subset. Make sure to label which rows are taken from
#the "log" or match with timestamp from "log" (i.e. which times a dilution started).
#These timestamps will be the T1 OD measurement for the growth rate calculation and
#used to judge where the T0 timestamp should be. T0 should be 8 rows after previous
#dilution time.

#1. Add readings that were used for dilutions (i.e. "log.long") that aren't in "odlog.long" to
# "odlog.long". Sort by chamber then timestamp.
# 1a. subset only rows from the log that aren't also in the odlog.
log.long.subset <- log.long[((log.long$timestamp %in% odlog$timestamp)=="FALSE"),]
log.long.subset <- log.long.subset[,1:3]
odlog.long.trim <- odlog.long[,c(1,2,7)]
# 1b. Looks like the 4th decimal place of OD is different in odlog and log calculations. Probably has
# something to do with floating point numbers. Let's put both OD to only 4 decimal places...
odlog.long.trim$OD <- round(odlog.long.trim$OD, digits = 4)
log.long.subset$OD <- round(log.long.subset$OD, digits = 4)
# 1c. combine dataframes using rbind. Sort by chamber then timestamp.
all.ods <- rbind(odlog.long.trim,log.long.subset)
all.ods.sort <- all.ods[order(all.ods$chamber,all.ods$timestamp),]
# 1d. get rid of those bad reads...
all.ods.sort <- all.ods.sort[(all.ods.sort$timestamp>1480000000),]
#now we have a dataframe with every OD reading!

#2. Label readings in all.ods.sort that were used for dilutions (i.e. match timestamp in "log")
# with "1". These are the T2 measurements. There should be a "1" every 60sec (or however long 
# the period was set to for dilutions). Then make a growth rate group label for all readings
# in between each T2.
all.ods.sort$T2 <- (all.ods.sort$timestamp %in% log$timestamp)*1
all.ods.sort$gr.group <- c(0,cumsum(all.ods.sort$T2)[-length(all.ods.sort$T2)])


#3. Subset readings in all.ods.sort that will be used as T1 OD measurements. These should correspond
# to the reading immediately after all the chambers have been diluted from the previous T2 measurement.
# Which measurment to take will depend on how many chambers are being used. For example: If all 8
# chambers are being used, it takes 20sec after T2 measurment for the turbidostat to distribute all the
# allocated dilution volumes. Here are the approximate times after the previous T2 measurment for each 
# chamber when the instrument finishes diluting:
#   Chamber   time (sec)
#   1         4
#   2         6
#   3         8
#   4         10
#   5         14
#   6         16
#   7         18
#   8         20
# make all possible timestamps that could be used immediately after the final dilution for that chamber.
# Despite the instrument giving a reading every ~3sec, there is such a high variability because when
# there is a "bad read" the read is not registered.
t1.times <- vector("numeric", length = length(log$timestamp)*s)
for (i in 1:length(log$timestamp)){
  t1.times[(s*(i-1))+(1:s)] <- log$timestamp[i] + t + c(1:s)
}

# match those timestamps with all.ods.sort and label with "1" in T1 column.
t1.ods <- all.ods.sort[which(all.ods.sort$timestamp %in% t1.times),]
all.ods.sort$T1 <- (all.ods.sort$timestamp %in% t1.ods$timestamp)*1
# create a new dataframe with only the potential T1 times and include a column with the row number
# from all.ods.sort of each timepoint.
t1.options <- all.ods.sort[all.ods.sort$T1==1,]
t1.options$row <- which(all.ods.sort$timestamp %in% t1.options$timestamp)

#4. Pick out the first row of each gr.group (i.e. the T1 row that will be used in all.ods.sort)
t1.options.thin <- t1.options[,c(5,7)]
t1.min <- tapply(t1.options.thin$row, INDEX = t1.options.thin$gr.group, FUN = min)
###t1.split <- split(t1.options.thin, t1.options.thin$gr.group)

#5. Create final table to calculate growth rate in each group. Table will include chamber, gr.group, T1, T2, OD1, and OD2
gr.ods.t2 <- all.ods.sort[all.ods.sort$T2==1,c(1:5)]
colnames(gr.ods.t2) <- c("T2","chamber","OD2","T2.group","gr.group")
gr.ods.t2 <- gr.ods.t2[-1,]
gr.ods.t1 <- all.ods.sort[t1.min,c(1:3,5,6)]
colnames(gr.ods.t1) <- c("T1","chamber","OD1","gr.group","T1.group")
gr.ods.t1 <- gr.ods.t1[-nrow(gr.ods.t1),]
# remove any rows in gr.ods.t2 that don't have a corresponding t1 (i.e. don't have a matching gr.group)
gr.ods.t2 <- {
  if (setequal(gr.ods.t2$gr.group, gr.ods.t1$gr.group)=='TRUE')
    gr.ods.t2
  else gr.ods.t2[-setdiff(gr.ods.t2$gr.group, gr.ods.t1$gr.group),]
}
# dim of gr.ods.t1 and gr.ods.t2 should be the same at this point. If not, most likely I did not get every
# T1 measurment in step #3. Try adding more times to see if that helps.
dim(gr.ods.t1);dim(gr.ods.t2)
# combine T1 and T2 tables... but only after going through some QC checks.
gr.ods <- {
  if (setequal(gr.ods.t1$gr.group ,gr.ods.t2$gr.group)=='FALSE') 
    stop("gr.groups in t1 and t2 tables are not equal (i.e. not every growth rate group has both a T1 and T2). Probably needs to be fixed in steps #3, 4, or 5. May the R gods smile upon you in your troubleshooting efforts")
  if ((sum(gr.ods.t1$T1.group)==nrow(gr.ods.t1))=='FALSE')
    stop("Not every row in gr.ods.t1 is a proper T1 measurment (i.e. doesn't have a 1 in the T1.group column. Probably an issue with step #3.")
  if ((sum(gr.ods.t2$T2.group)==nrow(gr.ods.t2))=='FALSE')
    stop("Not every row in gr.ods.t2 is a proper T2 measurment (i.e. doesn't have a 1 in the T2.group column. Probably an issue with step #3 or 4.")
  else cbind(gr.ods.t1[,1:4], gr.ods.t2[,c(1,3)])
}


#6. Time to calculate the growth rate for each timepoint!
# make growth rate function in 1/hr units if T1 and T2 are in seconds...
gr <- function(OD1,OD2,T1,T2){
  u <- (log(OD2/OD1)/(T2-T1))*3600
  return(u)
}
# calculate growth rate for all gr.groups...
gr.ods$gr <- gr(OD1 = gr.ods$OD1, 
                OD2 = gr.ods$OD2, 
                T1 = gr.ods$T1, 
                T2 = gr.ods$T2)
# get rid of all the Inf values
gr.ods[is.infinite(gr.ods$gr),'gr'] <- NaN
# get rid of extreme outliers
upperlimit <- 3
lowerlimit <- -2
gr.ods[!is.na(gr.ods$gr) & gr.ods$gr > upperlimit | !is.na(gr.ods$gr) & gr.ods$gr < lowerlimit,'gr'] <- NA
# Do I want to get rid of all negative growth rate values?
#gr.ods[!is.na(gr.ods$gr) & gr.ods$gr < 0, 'gr'] <- NA

#7. Calculate average growth rate for each day.
gr.ods$day <- ceiling((gr.ods$T1 - gr.ods[1,1])/86400)
mean.gr <- t(tapply(gr.ods$gr, INDEX = list(gr.ods$chamber, gr.ods$day), mean, na.rm = TRUE)[,-1])
# in mean.gr...
# columns = chambers
# rows = days


#8. Plot growth rates
mean.gr.long <- reshape(as.data.frame(mean.gr), 
                        varying = as.character(c(1:ncol(mean.gr))),
                        v.names = "gr",
                        direction="long")
colnames(mean.gr.long) <- c("chamber","gr","day")

# Histogram of growth rates by chamber by day. Set 'day' and 'chamber' objects to desired numbers.
day <- 3
palette(rainbow(8))
op <- par(mar = c(5.1,4.1,4.1,2.1), mfrow = c(2,4))
for (i in min(unique(gr.ods$chamber)):max(unique(gr.ods$chamber))){
  hist(gr.ods[gr.ods$day==day & gr.ods$chamber==i, 7],
       breaks = seq(from = lowerlimit, to = upperlimit, length.out = 25),
       col = i,
       xlab = expression("growth rate" ~ (hr^{-1})),
       main = paste('chamber', i, ',', 'day', day),
       ylim = c(0,200)
  )
}
par(op)

# Mean growth rate plot
op <- par(mar = c(5.1,5.1,4.1,8.1), xpd = TRUE, las = 1, cex.lab = 1.4, cex.axis = 1.2, cex.main = 1.4)
palette(rainbow(8))
matplot(mean.gr,
        type = "n",
        main = "growth rate by chamber",
        xlab = "day",
        ylab = expression("growth rate" ~ (hr^{-1})),
        bty = 'n',
        axes = FALSE,
        ylim = c(0,1),
        xlim = c(0.8,nrow(mean.gr)))
axis(1, pos = 0, lwd = 2, at = 1:4)
axis(1, pos = 0, lwd = 2, at = c(0.8,1), labels=c("",""), lwd.ticks=0)
axis(2, pos = 0.8, lwd = 2)
for (i in 1:ncol(mean.gr)){
  lines(mean.gr[,i],
        lty = 1,
        lwd = 2,
        pch = 19,
        lend = 1,
        col = i)
}
for (i in 1:ncol(mean.gr)){
  points(mean.gr[,i],
         pch = 19,
         col = i)
}
legend("topright",
       inset = c(-0.1,0),
       legend = colnames(mean.gr),
       title = "chamber",
       cex = 1.5,
       col = palette(),
       pch = 19,
       y.intersp = 1)
par(op)

mean.gr