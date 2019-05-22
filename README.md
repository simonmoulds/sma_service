# sma_service
Prototype soil moisture accounting service

This directory contains a prototype Shiny application which models root zone soil moisture over time. The model is an implementation of the [Global Crop Water Model](https://www.uni-frankfurt.de/45217988/Global_Crop_Water_Model__GCWM). At the moment we only consider rainfed crops, but we have extended the model to include deep percolation.

The Shiny application is in the file 'app.R', which implements the water balance model for a site near Kumasi, Ghana, between 2014-2016. To run this file, start an R session (in RStudio or Emacs ESS, for example) and enter:

```r
shiny::runApp()
```
You may get some errors about not having certain packages installed. If this happens, use the command `install.packages("<package-name>")` to install the missing packages.

Once the dependencies are resolved, the `shiny::runApp()` command should open a tab in your internet browser. On the left hand side there are three plots showing, from top to bottom, volumetric soil moisture, temperature, and precipitation. This page is updated every few seconds, and you will see that time (on the x-axis) is moving forwards. The idea here is that the soil moisture service could be linked to a near-realtime weather forecast. For the prototype, we use an historical weather dataset `princeton_data.csv` which is released gradually to the file `simulated_realtime_met_data.csv`. This aspect is handled by `update_meteo.R`, which is automatically started when `shiny::runApp()` is called.

The file `app_simple.R` contains a simple application of the water balance model. This is **NOT** a Shiny application; it simply loops through the meteorological data in `princeton_data.csv`. It is therefore useful to explore the water balance model in more detail without having to deal with the Shiny boilerplate.
