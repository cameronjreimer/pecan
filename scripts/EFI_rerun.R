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
args$end_date = as.Date("2021-06-12") #remember to change start & end date to your desired dates

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
#manually add in clim files 
con <-try(PEcAn.DB::db.open(settings$database$bety), silent = TRUE)

for(t in 1:length(dates)){
  
  input_check <- PEcAn.DB::dbfile.input.check(
                              siteid = site_id,
                              startdate = dates[t],                #changed to loop through days here
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
  if(!is.null(input_check$id)){
    input_checkinfo[[t]] = input_check
    input_checkinfo[[t]]$date = dates[t]
    days_with_met_data = append(days_with_met_data, dates[t])
  }else{
      days_without_met_data = append(days_without_met_data, dates[t])
    }
}




#If INPUTS already exists, add id and met path to settings file

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
  
  settings[[t]]$run$inputs$met$id = index_id
  settings[[t]]$run$inputs$met$path = clim_check
}else{PEcAn.utils::logger.error("No met file found")}
#settings <- PEcAn.workflow::do_conversions(settings, T, T, T)

if(is_empty(settings[[t]]$run$inputs$met$path) & length(clim_check)>0){
  settings[[t]]$run$inputs$met$id = index_id
  settings[[t]]$run$inputs$met$path = clim_check
}
PEcAn.DB::db.close(con)

# Write out the file with updated settings
PEcAn.settings::write.settings(settings[[t]], outputfile = "pecan.GEFS.xml")
 
print(days_with_met_data)



