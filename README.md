InvertLandsat_SST
===
_Invert sea surface temperature from Landsat 4, 5, 7 and 8 collection 2 level 2 images and apply masks._


### INPUT:  
  - **`pathfolder`**: Landsat-8 folder path <1xM char>  
### Optional input:  
  - **`retrieve_land`**: <boolean> retrieve land, lakes and rivers temperature; default = false  
  - **`prc_lim`**: <1x2 double> percentils to remove (%); default = [2.5 99]  

### OUTPUT:
  - **`dt`**: <1x1 datetime> satellite over pass date and time  
  - **`lat`**: <NxM double> matrix of latitudes  
  - **`lon`**: <NxM double> matrix of longitudes  
  - **`temperature`**: <NxM double> matrix of surface temperature  
  - **`fmask`**: <NxM double> matrix of masks generated from fmask  

### Examples:
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(file)
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(file, true)
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(file, false, [5 97.5])