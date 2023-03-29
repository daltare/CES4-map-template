# Pre-process data for use in Shiny app

# packages ----------------------------------------------------------------
library(tidyverse)
library(sf)
library(here)
# library(mapview)
library(janitor)
library(httr)
library(esri2sf) # install using remotes::install_github("yonghah/esri2sf"); for more info see: https://github.com/yonghah/esri2sf 
library(tigris)

## conflicts ----
library(conflicted)
conflicts_prefer(dplyr::filter)



# CES Data ----------------------------------------------------------------
## get CES data ----
temp_dir <- tempdir()
url_ces4_shp <- 'https://oehha.ca.gov/media/downloads/calenviroscreen/document/calenviroscreen40shpf2021shp.zip'

### download zipped shapefile to temporary directory ----
GET(url = url_ces4_shp, 
    write_disk(file.path(temp_dir, 'calenviroscreen40shpf2021shp.zip'),
               overwrite = TRUE))
unzip(zipfile = file.path(temp_dir, 'calenviroscreen40shpf2021shp.zip'), 
      exdir = file.path(temp_dir, 'calenviroscreen40shpf2021shp'))

### read shapefile saved in temporary directory ----
sf_ces4 <- st_read(file.path(temp_dir, 'calenviroscreen40shpf2021shp')) %>% 
    arrange(Tract) %>% 
    clean_names()
# st_crs(sf_ces4)
names(sf_ces4)

## write CES data to geopackage file ----
st_write(sf_ces4, 
         here('data_processed', 'calenviroscreen_4-0.gpkg'), 
         append = FALSE)



# CA boundary -------------------------------------------------------------
## get CA boundary ----
ca_boundary <- states(year = 2020, 
                      cb = TRUE) %>% # use cb = TRUE to get the cartographic boundary file
    filter(STUSPS == 'CA') %>%
    st_transform(3310)

## write CA boundary ----
st_write(ca_boundary, 
         here('data_processed', 
              'ca_boundary.gpkg'), 
         append = FALSE)
