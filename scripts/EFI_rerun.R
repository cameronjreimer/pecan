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

#Load site.xml and outputPath (i.e. where the model outputs will be stored) into args
args = list()
args$settings = file.path(homedir, "/Site_XMLS/bart.xml") #remember to change to where you store the site.xmls
args$continue = TRUE
args$start_date = as.Date("2021-06-01") #remember to change start & end date to your desired dates
args$end_date = as.Date("2021-06-02") #remember to change start & end date to your desired dates

args$outputPath <- file.path(homedir, "Site_Outputs/Bartlett/") #remember to change to where you want the model outputs saved

if(!dir.exists(args$outputPath)){dir.create(args$outputPath, recursive = TRUE)}
setwd(args$outputPath)

#Create loop variables
dates = args$start_date + 0:as.numeric(args$end_date - args$start_date)
days_with_met_data = NULL
days_without_met_data = NULL 
input_checkinfo <- list()

# Open and read in settings file for PEcAn run.
settings <- PEcAn.settings::read.settings(args$settings)
site_id <- settings$run$site$id %>% as.character()
con <-try(PEcAn.DB::db.open(settings$database$bety), silent = TRUE)

for(t in 1:length(dates)){
  
  input_check <- PEcAn.DB::dbfile.input.check(
                              siteid = site_id,
                              startdate = dates[t],     #changed to loop through days here
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
  
  #Add successful input checks to the input_checkinfo object
  if(!is.null(input_check$id)){
    days_with_met_data = append(days_with_met_data, dates[t])
    input_checkinfo[[length(days_with_met_data)]] = input_check
    input_checkinfo[[length(days_with_met_data)]]$date = dates[t]
  }else{
      days_without_met_data = append(days_without_met_data, dates[t])
    }
}


#if there are NO met files for any of the days, throw an error
if(length(days_without_met_data) == length(dates)){
  PEcAn.utils::logger.error("No met files found")
}

#format EFI_workflow system call 
source("/projectnb/dietzelab/cjreimer/pecan/scripts/EFI_workflow.R")
site_path <- args$settings
output_path <- args$outputPath

for(i in 1:length(days_with_met_data)){
  start_date = as.character(days_with_met_data[i])
  system2(command = "Rscript --vanilla EFI_workflow.R", args = c(site_path, output_path, start_date))
}





