# purpose       : Prediction of heavy metal concentrations for the Geul river valley in NL;
# reference     : [http://www.isric.org]
# producer      : Prepared by T. Hengl and G.B.M. Heuvelink
# address       : In Wageningen, NL.
# inputs        : 100 lead concentrations (samples) and DEM map of the area;
# outputs       : visualizations/plots;
# remarks 1     : this code requires some added functions;

library(GSIF)
library(plotKML)
library(RCurl)
library(sp)
library(rgdal)
library(randomForest)
nl.rd <- getURL("http://spatialreference.org/ref/sr-org/6781/proj4/")

## Geul data:
geul <- read.table("geul.dat", header = TRUE)
coordinates(geul) <- ~x+y
proj4string(geul) <- CRS(nl.rd) 
grd25 <- readGDAL("dem25.txt")
names(grd25) = "dem"
# grd25$river <- factor(readGDAL("river.txt")$band1, labels = "River")
grd25$dis <- readGDAL("riverdist.txt")$band1
## mask out missing pixels:
grd25 <- as(grd25, "SpatialPixelsDataFrame")
proj4string(grd25) <- CRS(nl.rd) 
# spplot(grd25)

## fit a model:
grd25.spc <- spc(grd25, ~ dem+dis)
m = log1p(pb) ~ PC1+PC2
#pbm <- fit.gstatModel(m, observations=geul, grd25.spc@predicted, family=gaussian(link=log))
pbm <- fit.gstatModel(m, observations=geul, grd25.spc@predicted)
## predict values:
pb.rk0 <- predict(pbm, grd25.spc@predicted)
## block kriging by default!
## back-transform:
pb.rk0@predicted$pb <- expm1(pb.rk0@predicted$pb + pb.rk0@predicted$var1.var/2)
pb.rk0
## 57% of variability explained by the model;
plot(pb.rk0)

## compare to randomForest-kriging:
pb.rk <- autopredict(geul["pb"], grd25)
plot(pb.rk)

## geostat simulations:
pb.rks <- predict(pbm, grd25.spc@predicted, nsim=20, block = c(0,0))
plotKML(pb.rks)

## the same using plot in GoogleMaps:
library(plotGoogleMaps)
str(pb.rk@predicted)
pal <- get("colour_scale_numeric", envir = plotKML.opts)
mp <- plotGoogleMaps(pb.rk@predicted, zcol='pb', add=T, colPalette=pal)
ms <- plotGoogleMaps(geul, zcol='pb', add=F, previousMap=mp)

## extend the model using a new covariate:
library(RSAGA)
writeGDAL(grd25["dem"], "dem.sdat", "SAGA", mvFlag=-99999)
rsaga.geoprocessor(lib="ta_hydrology", module=15, param=list(DEM ="dem.sgrd", TWI="swi.sgrd"), check.module.exists = FALSE, warn=FALSE)
grd25$swi <- readGDAL("swi.sdat")$band1[grd25@grid.index]
library(raster)
plot(stack(grd25))

grd25.spc2 <- spc(grd25, ~ dem+dis+swi)
m2 = log1p(pb) ~ PC1+PC2+PC3
pbm2 <- fit.gstatModel(m2, observations=geul, grd25.spc2@predicted)
pb.rk2 <- predict(pbm2, grd25.spc2@predicted)
show(pb.rk2)
plot(pb.rk2)

## compare to randomForest-kriging:
pb.rk <- autopredict(geul["pb"], grd25)

## end of script;