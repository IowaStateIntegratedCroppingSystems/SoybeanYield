# code to generate data objects for the Shiny applet
library(ggplot2)
library(reshape2)
library(plyr)
library(dplyr)
library(lubridate)
library(stringr)

# Read in yield data
yield <- read.csv("./Data/IowaAnalysis3.csv", stringsAsFactors=F)
yield$id <- 1:nrow(yield)

# Format dates
yield$PlantDay <- yield$Planting
yield$Planting2 <- dmy(paste0(yield$Planting, "-2000"))
yield$PlantDay <- factor(yield$PlantDay, levels=unique(yield$PlantDay)[order(ydm(paste0("2000-", unique(yield$PlantDay))))])
yield$Date.of.first.frost2 <- dmy(paste0(yield$Date.of.first.frost, "-2000"))

# Create maturity groups as a number
yield$MG <- as.character(gsub("MG", "", yield$MG))
yield$MG <- (nchar(yield$MG)==1)*as.numeric(yield$MG) + (nchar(yield$MG)==2)*(as.numeric(yield$MG)/10)

# Fix missouri yield
yield$oldYield <- yield$Yield
yield$Yield[yield$Location=="Missouri"] <- yield$pot.Yield[yield$Location=="Missouri"]

# Function to convert datetimes into "Day - Month" format, where "Month" is a 3-letter string. 
dm <- function(x){
  sprintf("%i-%s", mday(x), as.character(month(x, label=T, abbr=T)))
}

# Create planting date variable
plantdates <- unique(yield$Planting2)[order(unique(yield$Planting2))]

# Read in additional data
newdata <- read.csv("./Data/2014Data.csv", stringsAsFactors=F)
newdata$id <- (nrow(yield)+1):(nrow(yield)+nrow(newdata))

# Fix dates
newdata$oldPlanting <- newdata$Planting
newdata$PlantDay <- mdy(newdata$Planting)
year(newdata$PlantDay) <- 2000
newdata$Planting2 <- ymd(
  plantdates[sapply(newdata$PlantDay, 
                    # This function finds the closest planting date to the data 
                    # and sets that as the "PlantDay"
                    function(i) which.min(abs(as.numeric(plantdates-i)))
                    )])
newdata$Planting <- dm(newdata$Planting2)
newdata$PlantDay <- factor(newdata$Planting, levels=unique(yield$PlantDay)[order(ydm(paste0("2000-", unique(yield$PlantDay))))])
newdata$Date.of.first.frost2 <- NA

# Fix MG
newdata$MG <- round(newdata$MG/.5)*.5

# Variable compatibility between old data and 2014 data.
newdata$Year <- 2014
newdata$VE <- dm(mdy(newdata$VE))
newdata$R1 <- dm(mdy(newdata$R1))
newdata$R4 <- dm(mdy(newdata$R4))
newdata$R7 <- dm(mdy(newdata$R7))
newdata$R8 <- dm(mdy(newdata$R8))
newdata$Comment <- ""
newdata$Comment[is.na(newdata$Yield)] <- "failed"
newdata$Yield[is.na(newdata$Yield)] <- 0

# Merge old and new data
yield <- rbind.fill(yield, newdata[,-which(names(newdata)%in%c("bushels", "moisture", "oldDate", "oldPlanting"))])

# Fix strings
yield$Location <- gsub("^Crawford ?$", "Crawfordsville", yield$Location)
yield$Location <- gsub("(.*) $", "\\1", yield$Location)

# Function to replace locations with approximate regions
fix.locations <- function(x){
  x %>% 
  str_replace(pattern="Sutherland", replacement="Northwest Iowa") %>%
  str_replace(pattern="Kanawha", replacement="North Central Iowa") %>%
  str_replace(pattern="Nashua", replacement="Northeast Iowa") %>%
  str_replace(pattern="IowaWest", replacement="West Central Iowa") %>%
  str_replace(pattern="Ames", replacement="Central Iowa") %>%
  str_replace(pattern="IowaEast", replacement="East Central Iowa") %>%
  str_replace(pattern="Armstrong", replacement="Southwest Iowa") %>%
  str_replace(pattern="McNay", replacement="South Central Iowa") %>%
  str_replace(pattern="Crawfordsville", replacement="Southeast Iowa")
}

yield$Location <- fix.locations(yield$Location)

# Make data into long form. 
# ID variables: Year, MG, Location, Yield, Date of first frost, Comment, id, and PlantDay
# Measure variables: Planting, VE, R1, R4, R7, R8
longyield <- melt(yield, id.vars=c(1,2,3,5,18:21), measure.vars=c(4,7:11), variable.name="Stage", value.name="Date")

# Fix dates to have year 2000 so years are comparable
longyield$Date <- paste0(longyield$Date, "-2000")
longyield$Date <- dmy(longyield$Date)

# Relabel Stage
longyield$Stage <- factor(longyield$Stage, 
                          levels=c("Planting", "VE", "R1", "R4", "R7", "R8"), 
                          labels=c("Planting", "Emergence", "Flowering", 
                                   "Start Grain\nFilling", "Maturity", "R8"))
# Leave out R8 for now
longyield <- filter(longyield, Stage!="R8")

# Remove NAs
# longyield <- filter(longyield, !is.na(Date))

# Calculate maximum times for NA "Not Acheived" 
maxvals <- list(
  Location = ddply(longyield, .(Location, Stage), summarize, compare="Location", ymax.backup=max(c(Date, ymd("1999-01-01")), na.rm=T)),
  PlantDay = ddply(longyield, .(PlantDay, Stage), summarize, compare="PlantDay", ymax.backup=max(c(Date, ymd("1999-01-01")), na.rm=T)),
  MG = ddply(longyield, .(MG, Stage), summarize, compare="MG", ymax.backup=max(c(Date, ymd("1999-01-01")), na.rm=T))
)

# Substitute November 15 for any 1999 values (placeholder for "No combination acheived maturity" at a given comparison variable level)
maxvals <- lapply(maxvals, function(df){df$ymax.backup[df$ymax.backup==ymd("1999-01-01")] <- ymd("2000-11-15"); return(df)})

save(yield, longyield, maxvals, file="Data/serverStart.rda")

# Get options for ui.R
locations <- unique(yield$Location)
planting.date <- unique(yield$Planting)
planting.date <- planting.date[order(ydm(paste0("2000-", planting.date)))]
maturity <- unique(yield$MG)
save(locations, planting.date, maturity, file="Data/uiStart.rda")

