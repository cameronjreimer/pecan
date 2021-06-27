#You must run this script in the terminal using the code:
#Rscript --vanilla EFI_rerun.R "[file path to site xml]" "[file path to output folder]" [start_date] [end_date]

library("PEcAn.all")
library("PEcAn.utils")
library("RCurl")
library("REddyProc")
library("tidyverse")
library("furrr")
library("R.utils")
library("dynutils")

###### Preping Workflow for regular SIPNET Run ##############
#set home directory as object (remember to change to your own directory before running this script)
homedir <- "/projectnb/dietzelab/cjreimer"

#Load site.xml, start & end date, (with commandArgs specify args in terminal) and outputPath (i.e. where the model outputs will be stored) into args
tmp = commandArgs(trailingOnly = TRUE)
if(length(tmp)<3){
  logger.severe("Missing required arguments")
}
args = list()
args$settings = tmp[1]
if(!file.exists(args$settings)){
  logger.severe("Not a valid xml path")
}
args$outputPath = tmp[2]
if(!isAbsolutePath(args$outputPath)){
  logger.severe("Not a valid outputPath")
}
args$start_date = as.Date(tmp[3])
if(is.na(args$start_date)){
  logger.severe("No start date provided")
}

args$end_date = as.Date(tmp[4])
if(is.na(args$end_date)){
  logger.severe("No end date provided")
}

if(length(args)>4){
  args$continue = tmp[5]
} else {
  args$continue = TRUE
}

if(!dir.exists(args$outputPath)){dir.create(args$outputPath, recursive = TRUE)}
setwd(args$outputPath)


dates = args$start_date + 0:as.numeric(args$end_date - args$start_date)
days_with_met_data = NA

for(t in 1:length(dates)){
  # Open and read in settings file for PEcAn run.
  settings <- PEcAn.settings::read.settings(args$settings)
  
  start_date <- dates[t]
  end_date<- dates[t] + 35 
  
  # Finding the right end and start date
  met.start <- start_date 
  met.end <- met.start + lubridate::days(35)
  
  settings$run$start.date <- as.character(met.start)
  settings$run$end.date <- as.character(met.end)
  settings$run$site$met.start <- as.character(met.start)
  settings$run$site$met.end <- as.character(met.end)
  #info
  settings$info$date <- paste0(format(Sys.time(), "%Y/%m/%d %H:%M:%S"), " +0000")
  
  # Update/fix/check settings.
  # Will only run the first time it's called, unless force=TRUE
  settings <-
    PEcAn.settings::prepare.settings(settings, force = FALSE)
  
  # Write pecan.CHECKED.xml
  PEcAn.settings::write.settings(settings, outputfile = "pecan.CHECKED.xml")
  
  ##############################################################
  
  
  #manually add in clim files 
  con <-try(PEcAn.DB::db.open(settings$database$bety), silent = TRUE)
  
  input_check <- PEcAn.DB::dbfile.input.check(
    siteid=settings$run$site$id %>% as.character(),
    startdate = settings$run$start.date %>% as.Date,
    enddate = NULL,
    parentid = NA,
    mimetype="text/csv",
    formatname="Sipnet.climna",
    con = con,
    hostname = PEcAn.remote::fqdn(),
    pattern = NULL, 
    exact.dates = TRUE,
    return.all=TRUE
  )
  
  if(length(input_check$id) == 0){
    days_with_met_data[t] = FALSE
    PEcAn.DB::db.close(con)
    next
  }

  days_with_met_data[t] = TRUE
  
  if(length(input_check$id) > 0){
    #met paths 
    clim_check = list()
    for(i in 1:length(input_check$file_path)){
      
      clim_check[[i]] <- file.path(input_check$file_path[i], input_check$file_name[i])
    }#end i loop for creating file paths 
    #ids
    index_id = list()
    index_path = list()
    for(i in 1:length(input_check$id)){
      index_id[[i]] = as.character(input_check$id[i])#get ids as list
      
    }#end i loop for making lists
    names(index_id) = sprintf("id%s",seq(1:length(input_check$id))) #rename list
    names(clim_check) = sprintf("path%s",seq(1:length(input_check$id)))
    
    settings$run$inputs$met$id = index_id
    settings$run$inputs$met$path = clim_check
  }else{print(length(input_check$id))}
  
  if(is_empty(settings$run$inputs$met$path) & length(clim_check)>0){
    settings$run$inputs$met$id = index_id
    settings$run$inputs$met$path = clim_check
  }
  
  PEcAn.DB::db.close(con)
  
}

print("The following dates have met data!!!! yay!")
print(dates[days_with_met_data])


