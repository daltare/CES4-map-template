# Template for a Shiny application that contains a map showing CalEnviroScreen 
# 4.0 data

## To deploy to shinyapps.io, include:
##      - this script 
##      - all of the files in the 'data_processed' folder 
## (no other files need to be published - e.g., don't need to publish the 
## 'data_raw' folder)


# load packages -----------------------------------------------------------
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(shinyWidgets)
library(tidyverse)
library(sf)
library(leaflegend)
library(leaflet)
library(glue)
library(janitor)
library(here)

## conflicts ----
library(conflicted)
conflicts_prefer(dplyr::filter)



# setup -------------------------------------------------------------------
## coordinate systems for transformations
projected_crs <- 3310 # see: https://epsg.io/3310 
# other options: 26910 see: https://epsg.io/26910
# resources: 
# https://nrm.dfg.ca.gov/FileHandler.ashx?DocumentID=109326&inline
# 
geographic_crs <- 4269 # see: https://epsg.io/4269
# see: https://epsg.io/4326



# load data ----------------------------------------------------------------
## CalEnviroScreen 4 ----
ces_4 <- st_read(here('data_processed', 
                      'calenviroscreen_4-0_processed_tiger_simple.gpkg'))

## CA boundary ----
ca_boundary <- st_read(here('data_processed', 
                            'ca_boundary.gpkg'))



# define UI ---------------------------------------------------------------
ui <- fillPage(
    leafletOutput('ces4_map_render', height = "100%") %>% 
        # withSpinner(color="#0dc5c1") %>% # not working
        addSpinner(color = '#0dc5c1', 
                   spin = 'double-bounce' # 'fading-circle' 'rotating-plane'
        ) %>% 
        {.}
)



# Define server logic -----------------------------------------------------
server <- function(input, output) {
    
    ## create leaflet map ----
    output$ces4_map_render <- renderLeaflet({
        
        ### create empty map ----
        ces4_map <- leaflet()
        
        
        ### set initial zoom ----
        ces4_map <- ces4_map %>% 
            setView(lng = -119.5, # CA centroid: -119.5266
                    lat = 37.5, # CA centroid: 37.15246
                    zoom = 6) 
        
        
        ### add basemap options ----
        basemap_options <- c( # NOTE: use 'providers$' to see more options
            #'Stamen.TonerLite',
            'CartoDB.Positron',
            'Esri.WorldTopoMap', 
            # 'Esri.WorldGrayCanvas',
            'Esri.WorldImagery'#,
            # 'Esri.WorldStreetMap'
        ) 
        
        for (provider in basemap_options) {
            ces4_map <- ces4_map %>% 
                addProviderTiles(provider, 
                                 group = provider, 
                                 options = providerTileOptions(noWrap = TRUE))
        }
        
        
        ### add panes ----
        
        #### (sets the order in which layers are drawn/stacked -- higher 
        #### numbers appear on top)
        ces4_map <- ces4_map %>% 
            addMapPane('ces_4_pane', zIndex = 500) %>% 
            addMapPane('ca_boundary_pane', zIndex = 510) %>% 
            {.}
        
        
        ### add CalEnviroScreen (CES) ----
        
        #### create color palette for CES scores ----
        ces_pal <- colorNumeric(
            palette = 'RdYlGn', 
            domain = ces_4$calenviroscreen_4_0_percentile, 
            reverse = TRUE)
        
        #### add CES polygons ----
        ces4_map <- ces4_map %>%
            addPolygons(data = ces_4 %>%
                            st_transform(crs = geographic_crs), 
                        options = pathOptions(pane = "ces_4_pane"),
                        color = 'darkgrey', 
                        weight = 0.5,
                        smoothFactor = 1.0,
                        opacity = 0.8,
                        fillOpacity = 0.8,
                        fillColor = ~ces_pal(calenviroscreen_4_0_percentile), 
                        highlightOptions = highlightOptions(color = "white", weight = 2), 
                        popup = ~paste0('<b>', '<u>','CalEnviroScreen 4.0 (CES)', '</u>','</b>','<br/>',
                                        '<b>', 'Census Tract: ', '</b>',  census_tract_2010, '<br/>',
                                        '<b>', 'CES Score: ', '</b>', round(calenviroscreen_4_0_score, 2), '<br/>',
                                        '<b>', 'CES Percentile: ', '</b>', round(calenviroscreen_4_0_percentile, 2), '<br/>'),
                        group = 'CalEnviroScreen 4.0'#,
                        # label = ~glue('CES 4.0 (Percentile: {round(calenviroscreen_4_0_percentile, 2)})')
            )
        
        #### add CES legend ----
        ces4_map <- ces4_map %>%
            addLegend(position = 'bottomleft',
                      pal = ces_pal,
                      values = ces_4$calenviroscreen_4_0_percentile,
                      opacity = 1,
                      layerId = 'ces_legend',
                      bins = 4,
                      group = 'CalEnviroScreen 4.0',
                      title = 'CalEnviroScreen 4.0 Percentile'
            )
        
        
        ### add CA boundary ----
        ces4_map <- ces4_map %>%
            addPolylines(data = ca_boundary %>% 
                             st_transform(crs = geographic_crs), # have to convert to geographic coordinate system for leaflet)
                         options = pathOptions(pane = 'ca_boundary_pane'),
                         color = 'black', 
                         weight = 1.0,
                         smoothFactor = 1.0,
                         opacity = 0.7,
                         group = 'CA Boundary',
                         label = 'CA Boundary') %>% 
            hideGroup('CA Boundary')
        
        
        ### add layer controls ----
        ces4_map <- ces4_map %>%
            addLayersControl(baseGroups = basemap_options,
                             overlayGroups = c(
                                 'CalEnviroScreen 4.0',
                                 'CA Boundary'
                             ),
                             options = layersControlOptions(collapsed = TRUE,
                                                            autoZIndex = TRUE))
    })
    
}


# run application  --------------------------------------------------------
shinyApp(ui = ui, server = server)
