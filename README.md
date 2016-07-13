#SilverPopR
##Example
```R
library(SilverPopR)

load_credentials("credentials_silverpop.json")
authorize_api()

list_available_events() # List all event types in SilverPop

database_id <- "1234567890"
event_date_start <- as.Date("2016-01-01")
event_date_end <- as.Date("2016-06-30")
events <- list("opens","clicks","sent")
csv_file <- RawRecipientDataExport(database_id,event_date_start,event_date_end,events)
sp <- read.csv(csv_file, sep="|")
DeleteDataFiles()
```
##Credentials file
All fields are mandatory.
```json
{
  "client_id" : "",
  "client_secret" : "",
  "refresh_token" : "",
  "sftp_user" : "",
  "sftp_pwd" : ""
}
```

##Supported API methods
RawRecipientDataExport