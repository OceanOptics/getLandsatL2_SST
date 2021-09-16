InvertLandsat_SST
===
_Invert sea surface temperature from Landsat 4, 5, 7 and 8 collection 2 level 2 images and apply masks._

Matlab mapping toolbox required.

### Warning: The function 'gettiffinfo.m' from matlab's mapping toolbox need to be modified to recover accurate geolocalisation.
Follow instructions: https://cosmojiang.wordpress.com/2018/04/02/matlab-geotiffread-for-multiple-layers/

### INPUT:  
  - **`pathfolder`**: Landsat-8 folder path <1xM char>  
### Optional input:  
  - **`retrieve_land`**: < 1x1 boolean > retrieve land, small lake and river temperature; default = false  
  - **`prc_lim`**: < 1x2 double > percentils to remove (%); default = [2.5 99]  

### OUTPUT:
  - **`dt`**: < 1x1 datetime > satellite over pass date and time  
  - **`lat`**: < NxM double > matrix of latitudes  
  - **`lon`**: < NxM double > matrix of longitudes  
  - **`temperature`**: < NxM double > matrix of surface temperature  
  - **`fmask`**: < NxM double > matrix of masks generated from fmask  

### Examples:
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder)
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder, true)
    [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder, false, [5 97.5])

### Example of LANDSAT-8 image without applying any land mask:

![alt text](https://github.com/OceanOptics/InvertLandsat_SST/blob/main/L8_image_with_land.jpg?raw=true)

### Example of the same LANDSAT-8 image applying the land mask of QA band:

![alt text](https://github.com/OceanOptics/InvertLandsat_SST/blob/main/L8_image_without_land.jpg?raw=true)

