## Author : Simon Moulds, Imperial College London
## Date   : May 2019

library(xts)
library(shiny)
library(shinydashboard)
library(leaflet)
library(ggplot2)

source("utils.R")
source("water_balance_model.R")

## Some useful links:
## ==================
## Updating csv: https://stackoverflow.com/q/31410512
## Retaining date window: https://stackoverflow.com/a/44244994
## Visualization: https://www.showmeshiny.com/wp-content/uploads/2018/03/Time-Series-Dashboard.png

## Run a script which simulates a realtime service
## TODO: make this platform independent
system(command='Rscript update_meteo.R', wait=FALSE)

header <- dashboardHeader(
    title = 'Crop water stress'
)

sidebar <- dashboardSidebar(
    ## select crop type from a list
    selectInput(
        "crop",
        label="Crop type",
        choices=c("Maize","Cassava","Cocoa"),
        selected=c("Maize")
    )## ,
    
    ## ## select planting date as month, day. Wrap the
    ## ## numericInput(...) command in div(...) to enable us to
    ## ## control the font color, which otherwise is white (and
    ## ## therefore invisible).
    ## box(
    ##     title="Planting date",
    ##     width=12,
    ##     splitLayout(
    ##         div(numericInput(
    ##             "plant_month", "Month", value=1, width=NULL),
    ##             style="color:#545454"),
    ##                 div(numericInput(
    ##                     "plant_day", "Day", value=1, width=NULL),
    ##                     style="color:#545454")
    ##     )
    ## ),    
    ## box(
    ##     title="Harvest date",
    ##     width=12,
    ##     splitLayout(
    ##         div(numericInput(
    ##             "harvest_month", "Month", value=1, width=NULL),
    ##             style="color:#545454"),
    ##                 div(numericInput(
    ##                     "harvest_day", "Day", value=1, width=NULL),
    ##                     style="color:#545454")
    ##     )
    ## )
    
)

body <- dashboardBody(    
    ## Create plots as two columns
    fluidRow(
        column(
            width=6,
            box(
                title="Soil water",
                width=NULL,
                plotOutput("soil_moisture_plot", height=200)
            ),
            box(
                title="Temperature",
                width=NULL,
                plotOutput("temperature_plot", height=200)
            ),
            box(
                title="Rainfall",
                width=NULL,
                plotOutput("precipitation_plot", height=200)
            )
        ),
        column(
            width=6,
            box(
                title="Map",
                width=NULL,
                leafletOutput("map", height=800)
            )
        )
    ),    
    ## The following set of commands prevent the flickering
    ## which is otherwise experienced by the user when the
    ## site updates.
    tags$style(type="text/css", "#soil_moisture_plot.recalculating { opacity: 1.0; }"),
    tags$style(type="text/css", "#temperature_plot.recalculating { opacity: 1.0; }"),
    tags$style(type="text/css", "#precipitation_plot.recalculating { opacity: 1.0; }")    
)

# Shiny UI
ui <- dashboardPage(
    header,
    sidebar,
    body
)

## Define server logic
server <- function(input, output)
{

    ## soil parameters
    fc = 0.33
    wp = 0.10
    
    ## fixed runoff parameter (decrease runoff by
    ## increasing gamma); GCWM uses a value of 2
    ## for rainfed, 3 for irrigated cropland
    gamma = 2
    
    run_model <- reactive({
        
        invalidateLater(1000)

        ## import meteorological data - the idea here is that
        ## the meteorological files are regularly updated.
        meteo = read.csv("simulated_realtime_met_data.csv")
        time = as.POSIXct(meteo$time)        
        meteo$prcp = meteo$prcp * 24 * 60 * 60  # kg/m2/s -> mm/day
        
        ## crop-specific parameters (kc, root depth,
        ## depletion factor)
        crop = input$crop
        db = read.csv("gcwm_crop_data.csv")
        crop_params = get_crop_params(db, crop)

        ## planting/harvest day for maize in Ghana (from
        ## MIRCA2000 dataset). Eventually this should be
        ## retrieved from a spatial database for a user-
        ## specified site.
        pd = 152 
        hd = 304

        ## the value of these parameters changes in time
        ## according to the growth stage, so here we get
        ## the correct values for each time point so far
        ## available.
        kc = compute_kc(time, pd, hd, crop_params)
        p_std = compute_p_std(time, pd, hd, crop_params)
        zr = compute_zr(time, pd, hd, crop_params)

        ## having got the rooting depth (zr), we can now
        ## compute the total available water.
        taw = (fc - wp) * zr

        ## initial condition (let's just assume midpoint
        ## between fc and wp)
        theta0 = (wp + (fc - wp) / 2)
        s0 = (theta0 - wp) * zr[1]
        
        ## for now we just rerun the model every time the
        ## webpage refreshes, but this is needlessly
        ## computationally intensive - look up some way
        ## to store the results between each refresh, and
        ## only run the model for new time points.
        nt = nrow(meteo)
        th_out = rep(NA, nt)
        wc_out = rep(NA, nt)
        eta_out = rep(NA, nt)
        for (i in seq_len(nt)) {            
            out = water_balance_model(
                s0,
                meteo$prcp[i],
                meteo$etref[i],
                kc[i],
                p_std[i],
                gamma,
                wp,
                zr[i],
                taw[i])

            wc_out[i] = out$s
            th_out[i] = out$th
            eta_out[i] = out$eta
            s0 = out$s
        }

        time=as.POSIXct(meteo$time, tz="GMT", format="%Y-%m-%d")
        data = data.frame(
            temp=meteo$tas,
            prec=meteo$prcp,
            eta=eta_out,
            th=th_out) %>%
            xts(order.by=time, tzone="GMT")
        
        data = tail(data, n=30)
        ## data = tail(data, n=input$window)
        data
    })

    ## plot the results
    output$soil_moisture_plot = renderPlot({
        ## plot(run_model()$sm)
        ggplot(data=run_model(), aes(x=Index, y=th)) +
            geom_line(colour="blue", size=2) +
            ylim(wp, fc)
    })
    output$temperature_plot = renderPlot({
        ggplot(data=run_model(), aes(x=Index, y=temp)) +
            geom_line(colour="red", size=2)
    })
    output$precipitation_plot = renderPlot({
        ggplot(data=run_model(), aes(x=Index, y=prec)) +
            geom_bar(stat="identity")
    })
    output$map = renderLeaflet({
        leaflet() %>% addTiles() %>% setView(lng=-1.6163, lat=6.666, zoom=10)
    })    
}

shinyApp(ui = ui, server = server)
