library(httr) # HTTP client
library(RCurl) # Used for SFTP
library(jsonlite) # Parsing credentials in JSON format
library(R.cache) # Storing secrets in cache
library(XML) # Building XML

setCacheRootPath(path="~/.Rcache")
oauth_endpoint <- "https://api3.ibmmarketingcloud.com/oauth/token"
api_endpoint <- "https://api3.ibmmarketingcloud.com/XMLAPI"
sftp_server <- "sftp://transfer3.silverpop.com"

load_credentials <- function(keystore) {
  
  client_id <<- fromJSON(keystore)$client_id
  client_secret <<- fromJSON(keystore)$client_secret
  refresh_token <<- fromJSON(keystore)$refresh_token
  sftp_user <<- fromJSON(keystore)$sftp_user
  saveCache(fromJSON(keystore)$sftp_pwd,key=list("sftp_pwd"))
  
}

# Obtain access token using user refresh token
authorize_api <- function() {
  
  response <- POST(oauth_endpoint,
                   body = list(grant_type = "refresh_token",
                               client_id = client_id,
                               client_secret = client_secret,
                               refresh_token = refresh_token))
  
  access_token <- content(response)$access_token
  print(access_token)
  saveCache(access_token,key=list("access_token"))
}

list_available_events <- function() {
  
  events = c("sent","suppressed","opens","clicks","optins","optouts","forwards","attachments","conversions","clickstreams","hard_bounces","soft_bounces","reply_abuse","reply_coa","reply_other","mail_blocks","mails_restrictions")
  cat(events, sep="\n")
  
}

# POST Request to API
SPost <- function(body) {
  
  access_token <- loadCache(key=list("access_token"))
  r <- POST(url = api_endpoint, body = as(body,"character"), encode = "raw", add_headers(Authorization = paste("Bearer",access_token,sep=" ")), content_type("text/xml"))
  return(xmlInternalTreeParse(content(r,as = "text")))
  
}

# Get Job Status
GetJobStatus <- function (job_id) {
  
  xml = newXMLDoc()
  envelope = newXMLNode("Envelope", parent = xml)
  body = newXMLNode("Body", parent = envelope)
  job = newXMLNode("GetJobStatus", parent = body)
  id = newXMLNode("JOB_ID", parent = job)
  newXMLTextNode(job_id, parent = id)
  
  response <- SPost(xml)
  status <- xpathApply(response,"/Envelope/Body/RESULT/JOB_STATUS",xmlValue)
  return(status)
}

DataJob <- function(job_id) {
  
  message(sprintf("Waiting for SilverPop to finish data job %s.",job_id))
  
  repeat {
    status <- GetJobStatus(job_id)
    if (status == "COMPLETE") {
      message(sprintf("Data job %s is complete.",job_id))
      break
    } else {
      print(status)
      Sys.sleep(5)
    }
  }
  
}

# Request data
RawRecipientDataExport <- function(list_id, start_date, end_date, events) {
  
  xml = newXMLDoc()
  envelope = newXMLNode("Envelope", parent = xml)
  body = newXMLNode("Body", parent = envelope)
  params = newXMLNode("RawRecipientDataExport", parent = body)
  start = newXMLNode("EVENT_DATE_START", parent = params)
  end = newXMLNode("EVENT_DATE_END", parent = params)
  format = newXMLNode("EXPORT_FORMAT", parent = params)
  list = newXMLNode("LIST_ID", parent = params)
  newXMLNode("MOVE_TO_FTP", parent = params)
  if (length(events) == 0) {
    newXMLNode("ALL_EVENT_TYPES", parent = params)
  } else {
    lapply(lapply(events, toupper), newXMLNode, parent = params) 
  }
  newXMLTextNode("1", parent = format)
  newXMLTextNode(format(start_date, format="%m/%d/%Y"), parent = start)
  newXMLTextNode(format(end_date, format="%m/%d/%Y"), parent = end)
  newXMLTextNode(list_id, parent = list)
  response <- SPost(xml)
  
  status <- xpathApply(response,"/Envelope/Body/RESULT/SUCCESS",xmlValue)
  
  if (status == "false") {
    message("API error occurred.")
    message(response)
    quit()
  } else {
    job_id <- xpathApply(response,"/Envelope/Body/RESULT/MAILING/JOB_ID", xmlValue)
    file_path <- xpathApply(response,"/Envelope/Body/RESULT/MAILING/FILE_PATH",xmlValue)
    message(sprintf("Job ID %s created.", job_id))
    DataJob(job_id)
    GetDataFile(file_path) 
  }
  
}

GetDataFile <- function(file_path) {
  
  path <- paste(sftp_server,"/download/",file_path,sep="")
  f = CFILE("temp.zip", mode="wb")
  curlPerform(url = path, writedata = f@ref, noprogress=FALSE, userpwd=paste(sftp_user,loadCache(key=list("sftp_pwd")),sep=":"))
  close(f)
  csv_file <- unzip("temp.zip",list = TRUE)$Name
  unzip("temp.zip", exdir = "files")
  message(sprintf("File %s successfully downloaded.",csv_file))
  file.remove("temp.zip")
  return(paste("files",csv_file,sep = "/"))
  
}

DeleteDataFiles <- function() {
  
  file.remove(list.files("files",full.names = TRUE))
  
}