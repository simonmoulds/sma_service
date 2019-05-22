## Author : Simon Moulds, Imperial College London
## Date   : May 2019

meteo = read.csv("princeton_data.csv")
nt = nrow(meteo)
write.table(
    meteo[1:30,,drop=FALSE],
    "simulated_realtime_met_data.csv",
    sep=",",
    row.names=FALSE,
    col.names=TRUE
)

i = 31
while (i <= nt) {
    write.table(
        meteo[i,,drop=FALSE],
        "simulated_realtime_met_data.csv",
        append=TRUE,
        sep=",",
        row.names=FALSE,
        col.names=FALSE
    )
    i = i+1
    Sys.sleep(1)
}
