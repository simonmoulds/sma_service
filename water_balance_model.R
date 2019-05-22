## Author : Simon Moulds, Imperial College London
## Date   : May 2019

water_balance_model = function(s0, prec, eto, kc, p_std, gamma, wp, zr, taw) {
    ## This function implements the water balance model
    ## which is part of the Global Crop Water Model,
    ## described in Siebert & Doell (2008)
    ## [http://tiny.cc/mra36y, accessed May 2019]. The model
    ## implemented here does *not* include irrigation. It
    ## does, however, extend the model to include deep
    ## percolation, which is assumed to occur when soil water
    ## content exceeds field capacity.
    ##
    ## Equation numbers in the comments correspond with
    ## those in the GCWM documentation (link above).
    ##
    ## Args:
    ##   s0    : initial soil water storage (mm)
    ##   prec  : daily precipitation (mm)
    ##   eto   : daily reference evapotranspiration (mm)
    ##   kc    : crop coefficient (-)
    ##   p_std : crop water depletion factor (-)
    ##   gamma : runoff coefficient (?)
    ##   wp    : soil wilting point (-)
    ##   zr    : root depth (mm)
    ##   taw   : total available water capacity (mm)
    ##
    ## Returns:
    ##   Updated soil water storage (mm), the corresponding
    ##   volumetric water content (-), actual ET (mm),
    ##   surface runoff (mm) and deep percolation (mm).
    etc = kc * eto                      # eqn 28
    p = p_std + 0.04 * (5 - etc)        # eqn 31
    ks = min((s0 / ((1 - p) * taw)), 1) # eqn 30
    eta = ks * etc                      # eqn 29
    runoff = prec * (s0 / taw) ** gamma # eqn 34
    s = s0 + prec - runoff - eta        # eqn 33
    dp = max(s - taw, 0)
    s = s - dp 
    th = wp + (s / zr)
    out = list(s=s, th=th, eta=eta, runoff=runoff, dp=dp)
    out
}

