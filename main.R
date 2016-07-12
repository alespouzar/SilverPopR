setwd("/Etnetera/RPackages/SilverPopR")
source("lib/SilverPop.R")

keystore <- "/Etnetera/credentials_silverpop.json"

client_id <- fromJSON(keystore)$client_id
client_secret <- fromJSON(keystore)$client_secret
refresh_token <- fromJSON(keystore)$refresh_token
sftp_user <- fromJSON(keystore)$sftp_user
sftp_pwd <- fromJSON(keystore)$sftp_pwd

authorize_api(client_id, client_secret, refresh_token)
authorize_sftp(sftp_user, sftp_pwd)

database_id <- "2119224"
event_date_start <- as.Date("2016-01-01")
event_date_end <- as.Date("2016-04-01")
events <- list("opens","clicks","sent")
RawRecipientDataExport(database_id,event_date_start,event_date_end,events)
csv_file <- GetDataFile("Contacts-CH.zip")
sp <- read.csv(csv_file)