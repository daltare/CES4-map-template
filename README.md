# CES 4.0 Map Template

This repository contains a template for a Shiny application that displays a simple map showing the CalEnviroScreen 4.0 dataset. More information about CalEnviroScreen 4.0 is available at: <https://oehha.ca.gov/calenviroscreen/report/calenviroscreen-40>

NOTE: The application uses a processed version of the CalEnviroScreen 4.0 dataset that is derived from the official CalEnviroScreen 4.0 shapefile found [here](https://oehha.ca.gov/media/downloads/calenviroscreen/document/calenviroscreen40shpf2021shp.zip). The processing includes:

-   replacing the spatial data associated with the census tracts in the original CalEnviroScreen 4.0 shapefile with a simplified version of census tracts from the 2010 TIGER dataset (this was done to eliminate minor gaps and overlaps between adjacent census tracts that exist in the CalEnviroScreen 4.0 shapefile)
-   encoding missing values as `NA` rather than `-999`
-   editing variable names to make them more descriptive

More details about these processing steps can be found in the `CES4_template_data_processing.R` script, and the processed datasets (in geopackage file format) can be found in the `data_processed` folder.
