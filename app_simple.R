## Author : Simon Moulds, Imperial College London
## Date   : May 2019

## A simple application of the daily water balance model to
## a site near Kumasi, Ghana, between 2014-2016

library(xts)
library(ggplot2)
library(magrittr)

source("utils.R")
source("water_balance_model.R")

## driving data
## ############

## This is taken from the Princeton dataset (link), with
## reference ET computed with the Hargreaves equation (?)
meteo = read.csv("princeton_data.csv")
time = as.POSIXct(meteo$time)        
meteo$prcp = meteo$prcp * 24 * 60 * 60  # kg/m2/s -> mm/day

## parameters
## ##########

## soil parameters, from HiHydroSoil
fc = 0.33
wp = 0.10

## fixed runoff parameter (decrease runoff by
## increasing gamma); GCWM uses a value of 2
## for rainfed, 3 for irrigated cropland
gamma = 2

## crop-specific parameters (kc, root depth,
## depletion factor).
crop = "Maize"
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

## make some plots
time=as.POSIXct(meteo$time, tz="GMT", format="%Y-%m-%d")
data = data.frame(
    temp=meteo$tas,
    prec=meteo$prcp,
    eta=eta_out,
    th=th_out) %>%
    xts(order.by=time, tzone="GMT")

## TODO: work out how to join these in one plot
ggplot(data=data, aes(x=Index, y=th)) +
    geom_line(colour="blue", size=0.5) +
    ylim(wp, fc) +
    ylab("Soil moisture (-)") +
    xlab("")

ggplot(data=data, aes(x=Index, y=eta)) +
    geom_line(colour="orange", size=0.5) +
    ylab("AET (mm/day)") +
    xlab("")

ggplot(data=data, aes(x=Index, y=temp)) +
    geom_line(colour="red", size=0.5) +
    ylab("Temperature (degC)")          #TODO

ggplot(data=data, aes(x=Index, y=prec)) +
    geom_bar(stat="identity") +
    ylab("Precipitation (mm/day)")
