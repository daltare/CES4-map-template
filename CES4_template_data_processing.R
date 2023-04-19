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
library(tools)
library(rmapshaper)

## conflicts ----
library(conflicted)
conflicts_prefer(dplyr::filter)



# CES Data ----------------------------------------------------------------

## get raw CES data ----

### set path to shapefile ----
url_ces4_shp <- 'https://oehha.ca.gov/media/downloads/calenviroscreen/document/calenviroscreen40shpf2021shp.zip'

### download zipped shapefile to temporary directory ----
temp_dir <- tempdir()

GET(url = url_ces4_shp, 
    write_disk(file.path(temp_dir, 
                         basename(url_ces4_shp)),
               overwrite = TRUE))

### unzip ----
unzip(zipfile = file.path(temp_dir, 
                          basename(url_ces4_shp)), 
      exdir = file.path(temp_dir, 
                        basename(url_ces4_shp) %>% 
                            file_path_sans_ext()))

### read shapefile saved in temporary directory ----
sf_ces4_raw <- st_read(file.path(temp_dir, 
                             basename(url_ces4_shp) %>% 
                                 file_path_sans_ext())) %>% 
    arrange(Tract) %>% 
    clean_names()
# st_crs(sf_ces4_raw)
# names(sf_ces4_raw)

## process CES 4 data ----

## create processed dataset ----
sf_ces4_processed <- sf_ces4_raw

## fix self-intersecting polygons ----
if (sum(!st_is_valid(sf_ces4_processed)) > 0) {
    sf_ces4_processed <- st_buffer(sf_ces4_processed, 
                                   dist = 0)
}

## remove un-needed fields ----
sf_ces4_processed <- sf_ces4_processed %>% 
    select(-shape_leng, -shape_area)

## fix field names ----
### NOTE: manually created the ces-4_names.csv file to make more descriptive 
### names for the fields in the CES 4.0 shapefile, based on the 'Data Dictionary'
### tab in the excel workbook at: 
### https://oehha.ca.gov/media/downloads/calenviroscreen/document/calenviroscreen40resultsdatadictionaryf2021.zip
ces_names <- read_csv(here('data_processed', 'ces-4_names.csv')) %>% 
    mutate(ces_variable = make_clean_names(variable_name, 
                                           case = 'snake', 
                                           replace = c('CalEnviroScreen' = 'calenviroscreen',
                                                       '(%)' = 'percent')), 
           .before = 1)

### set names in the sf dataset
if (all(ces_names$ces_variable_original_shapefile == names(sf_ces4_processed))) { # make sure the field names in the SF dataset match the names from the ces-4_names.csv file 
    names(sf_ces4_processed) <- ces_names$ces_variable
}

## set missing / negative values to NA ----
### check
# map_dbl(.x = sf_ces4_processed %>% 
#             st_drop_geometry() %>% 
#             select_if(is.numeric), 
#         .f = ~sum(.x < 0, na.rm = TRUE)) 
### replace 
sf_ces4_processed <- sf_ces4_processed %>% 
    mutate(across(.cols = where(is.numeric), 
                  .fns = ~ifelse(. < 0, NA, .)))
### check
# map_dbl(.x = sf_ces4_processed %>%
#             st_drop_geometry() %>%
#             select_if(is.numeric),
#         .f = ~sum(.x < 0, na.rm = TRUE))



## use TIGER census tract geometry ----
### Data Sources:
### FTP: https://www2.census.gov/geo/pvs/tiger2010st/06_California/06/tl_2010_06_tract10.zip
### Web Inerface: https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2010&layergroup=Census+Tracts
### tigris package: tract_2010 <- tigris::tracts(state = 'CA', year = 2010)

### get tiger data ----
sf_tracts_2010_tiger <- tracts(state = 'CA', 
                              year = 2010)
sum(!st_is_valid(sf_ces4_tiger)) # should be zero

### clean up tiger data ----
sf_ces4_tiger <- sf_tracts_2010_tiger %>% 
    select(GEOID10, geometry) %>%
    mutate(GEOID10 = as.numeric(GEOID10)) %>% 
    filter(GEOID10 %in% sf_ces4_processed$census_tract_2010) %>% 
    st_transform(3310) %>% 
    rename(census_tract_2010 = GEOID10) %>% 
    arrange(census_tract_2010) %>% 
    {.}

## add CES4 data to 2010 tiger tracts ----
sf_ces4_tiger <- sf_ces4_tiger %>% 
    left_join(sf_ces4_processed %>% 
                  st_drop_geometry(), 
              by = c('census_tract_2010'))

# names(sf_ces4_tiger)
# glimpse(sf_ces4_tiger)

## simplify ----
sf_ces4_tiger_simple <- sf_ces4_tiger %>% 
    ms_simplify(keep = 0.3, # keep = 0.05 (default)
                keep_shapes = TRUE, 
                snap = TRUE) 
sum(!st_is_valid(sf_ces4_tiger_simple)) # should be zero

## write processed CES 4 data to geopackage file ----
st_write(sf_ces4_processed, 
         here('data_processed', 
              'calenviroscreen_4-0_processed.gpkg'), 
         append = FALSE)

st_write(sf_ces4_tiger, 
         here('data_processed', 
              'calenviroscreen_4-0_processed_tiger.gpkg'), 
         append = FALSE)

st_write(sf_ces4_tiger_simple, 
         here('data_processed', 
              'calenviroscreen_4-0_processed_tiger_simple.gpkg'), 
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
