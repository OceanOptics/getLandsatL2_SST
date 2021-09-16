function [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder, retrieve_land, prc_lim)
% author: Guillaume Bourdin
% created: April 12, 2021
% MIT License
%%
% Invert sea surface temperature from Landsat 4, 5, 7 and 8 collection 2 level 2 images and apply masks
%
% INPUT:
%   - pathfolder: Landsat-8 folder path <1xM char>
% Optional input:
%   - retrieve_land: <boolean> retrieve land, samll lake and river temperature; default = false
%   - prc_lim: <1x2 double> percentils to remove (%); default = [2.5 99]
%
% OUTPUT:
%   - dt: <1x1 datetime> satellite over pass date and time
%   - lat: <NxM double> matrix of latitudes
%   - lon: <NxM double> matrix of longitudes
%   - temperature: <NxM double> matrix of surface temperature
%   - fmask: <NxM double> matrix of masks generated from fmask
%
% examples:
%    - [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder)
%    - [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder, true)
%    - [dt, lat, lon, temperature, fmask] = InvertLandsat_SST(pathfolder, false, [5 97.5])
%%
if nargin < 1
  error('Not enough input argument')
elseif nargin < 2
  fprintf('Warning: Land, small lakes and rivers retrieval not defined, default = false\n')
  retrieve_land = false;
  fprintf('Warning: Percentils limit not defined, default = [2.5 99]\n')
  prc_lim = [2.5 99];
elseif nargin < 3
  fprintf('Warning: Percentils limit not defined, default = [2.5 99]\n')
  prc_lim = [2.5 99];
elseif nargin > 3
  error('Too many input arguments,')
end

% disable warnings
warning('off')

% list files in directory
[~, filename] = fileparts(pathfolder);
foo = {dir(fullfile(pathfolder, '*L2*')).name}'; % (1:end-4)
foo = cellfun(@(x) [pathfolder filesep x], foo, 'un', 0); % (1:end-4)

% read MTL file
MTLfile = fileread([foo{contains(foo, '_MTL.txt')}]);

% get variables from MTL files
spacecraft = parseMTL(MTLfile, 'SPACECRAFT_ID =');

% set thermal band by spacecraft (B6 for L7 and B10 for L8)
switch spacecraft
  case {'LANDSAT_4','LANDSAT_5','LANDSAT_7'}
    STBAND = '6';
  case 'LANDSAT_8'
    STBAND = '10';
  otherwise
    error('Spacecraft %s not known', spacecraft)
end

% get calibration slope and intercept
slope = parseMTL(MTLfile, ['TEMPERATURE_MULT_BAND_ST_B' STBAND ' =']);
intercept = parseMTL(MTLfile, ['TEMPERATURE_ADD_BAND_ST_B' STBAND ' =']);

% extract date time and info for lat/lon
date = parseMTL(MTLfile, 'DATE_ACQUIRED =');
time = parseMTL(MTLfile, 'SCENE_CENTER_TIME =');
dt = datetime([date ' ' time], 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSSSSSS''Z');

% get thermal band data
fprintf('Loading thermal band from %s ... ', filename)
sst_band = [foo{contains(foo, ['_ST_B' STBAND '.TIF'])}];
t = Tiff(sst_band);
temp = double(read(t));
temperature = temp * slope + intercept - 273.15;
fprintf('Done\n')

% get image lat/lon
fprintf('Recovering latitude and longitude from %s ... ', filename)
info = geotiffinfo(sst_band);
img_height = info.Height; % Integer indicating the height of the image in pixels
img_width = info.Width; % Integer indicating the width of the image in pixels
[cols,rows] = meshgrid(1:img_width, 1:img_height);
[x,y] = pix2map(info.RefMatrix, rows, cols);
[lat,lon] = projinv(info, x, y);
fprintf('Done\n')

if retrieve_land
  fprintf('Applying ice and cloud masks to %s ... ', filename)
else
  fprintf('Applying land, ice and cloud masks to %s ... ', filename)
end
% reconstruct fmask output Quality Assessment Band
% fmask = 0 => land
% fmask = 1 => water
% fmask = 2 => cloud shaddow
% fmask = 3 => snow
% fmask = 4 => cloud
% fmask = 5 => outside
fmask = qa_to_mask(foo{contains(foo, '_QA_PIXEL.TIF')});
fprintf('Done\n')

% apply fmask
if retrieve_land
  temperature(fmask > 1) = NaN;
else
  temperature(fmask ~= 1) = NaN;
end

% Remove aberrant data
temperature(temperature < -60) = NaN;

% Remove data out of predefined percentils (default = [2.5 99])
prct = prctile(temperature(:), prc_lim);
fprintf('%.2f%% pixel deleted from %s: out of [%.1f %.1f] percentils\n', ...
  sum(sum(temperature < prct(1) | temperature > prct(2))) / size(temperature(:), 1) * 100, ...
  filename, prc_lim(1), prc_lim(2))
temperature(temperature < prct(1) | temperature > prct(2)) = NaN;
end


function parsed_parameters = parseMTL(MTLfile, toparse)
% Author: Guillaume Bourdin
% Date: Jan 20th, 2021
%
% Parse MTL file of landsat
if ~iscell(toparse)
  parsed_parameters = strrep(cell2mat(regexp(MTLfile, ['(?<=' toparse ' ).(.*)'],...
    'match','dotexceptnewline')), '"', '');
  try
    foo = str2double(parsed_parameters);
    if ~isnan(foo)
      parsed_parameters = foo;
    end
  catch
  end
else
  parsed_parameters = cell(size(toparse));
  for i = 1:max(size(toparse))
    parsed_parameters{i} = strrep(regexp(MTLfile, ['(?<=' toparse{i} ' ).(.*)'],...
      'match','dotexceptnewline'), '"', '');
    try
      foo = str2double(parsed_parameters{i});
      if ~isnan(foo)
        parsed_parameters{i} = foo;
      end
    catch
    end
  end
end
end


%% function qa_to_mask to extract f_mask output from QA band
% Author: Gabriel Hesketh
% Date: April 2021

% A function to read a level 2, collection 2 Landsat-8 file's QA band
% and generate a working mask for the file.
% The only band necessary for mask generation is qa_pixel.TIF; however,
% creating images from this file also requires the accompanying MTL file.
% qa_path          The qa_pixel band's full path 
% return f_mask   The generated mask for the L2C2 file
% Author: Gabriel Hesketh
% Date: April 2021
function f_mask = qa_to_mask(qa_path)

% here is an example qa_path, comment out the function line and corresponding end 
% if you want to do make your own list or processes scenes individually
% qa_path = '/Users/gabe/Documents/GitHub/OSI/testfiles/010_029/L2C2/LC08_L2SP_010029_20190214_20200829_02_T1/LC08_L2SP_010029_20190214_20200829_02_T1_QA_PIXEL.TIF';

info = Tiff(qa_path, 'r'); %read the file
qa = read(info);
f_mask = zeros(size(qa, 1), size(qa, 2)); %make a blank array to fill

% now get each bit of the band to get the important values from the band
bit1 = bitget(qa, 1); %fill
bit2 = bitget(qa, 2); %dilated cloud
bit3 = bitget(qa, 3); %cirrus
bit4 = bitget(qa, 4); %cloud 
bit5 = bitget(qa, 5); %cloud shadow
bit6 = bitget(qa, 6); %snow
% bit7 = bitget(qa, 7); %clear
bit8 = bitget(qa, 8); %water

% fill the zeros array based on the bit bands

% from FMask 4.3's autoFmask file, this shows the values given
% autoFmask, 
%     fmask      0: clear land
%                1: clear water
%                2: cloud shadow
%                3: snow
%                4: cloud
%                5: filled (outside)*

% (in autoFmask, outside values are set to 255)

f_mask(bit8 == 1) = 1; %set water
f_mask(bit2 == 1) = 4; %set clouds
f_mask(bit3 == 1) = 4; 
f_mask(bit4 == 1) = 4; 
% f_mask(bit7 == 0) = 4; 
f_mask(bit5 == 1) = 2; %overrwite some of cloud with cloud shadow
f_mask(bit6 == 1) = 3; %set snow
f_mask(bit1 == 1) = 5; %set outside

% if you don't need image generation, comment out the rest of this code
% including all the helper functions
% prepare_image(qa_path, f_mask);

% A function for getting all the relevant data from the .mtl file
% corresponding to the file, then passing the information to draw_map.
% qa_path          The qa_pixel band's full path 
% return f_mask   The generated mask for the L2C2 file
% function prepare_image(qa_path, f_mask)
% get the important data from the accompanying .mtl file
mtl_file = strrep(qa_path, 'QA_PIXEL.TIF', 'MTL.txt');
value_list = ["DATE_ACQUIRED"; "WRS_PATH"; "WRS_ROW";...
    "CORNER_UL_LAT_PRODUCT"; "CORNER_UL_LON_PRODUCT";...
    "CORNER_UR_LAT_PRODUCT"; "CORNER_UR_LON_PRODUCT";...
    "CORNER_LL_LAT_PRODUCT"; "CORNER_LL_LON_PRODUCT";... 
    "CORNER_LR_LAT_PRODUCT"; "CORNER_LR_LON_PRODUCT"];

%extract the values
values = get_meta_values(mtl_file, value_list);

%separate the values
file_date = values(1);
path = values(2);
row = values(3);
ul_lat = str2double(values(4));
ul_lon = str2double(values(5));
ur_lat = str2double(values(6));
ur_lon = str2double(values(7));
ll_lat = str2double(values(8));
ll_lon = str2double(values(9));
lr_lat = str2double(values(10));
lr_lon = str2double(values(11));

lats = [ul_lat, ur_lat, ll_lat, lr_lat];
lons = [ul_lon, ur_lon, ll_lon, lr_lon];

% x and y lat-lon axes for the image
x_lin = linspace(min(lons(:)),max(lons(:)),size(f_mask,1));
y_lin = linspace(min(lats(:)),max(lats(:)),size(f_mask,2));

% x_lin = round(linspace(min(lats), max(lats), 10), 1);
% y_lin = round(linspace(min(lons), max(lons), 10), 1); 

% concatenate the path_row string
if (str2double(path) < 100)
  path = strcat("0", path);
end
if (str2double(row) < 100)
  row = strcat("0", row);
end
path_row = strcat(path, "-", row);

final_path = strrep(qa_path, 'QA_PIXEL.TIF', 'testmask.png');

% draw_map(final_path, f_mask, axes, path_row, file_date);
draw_qa_mask(final_path, f_mask, x_lin, y_lin, path_row, file_date);
end

% makes an image of the f_mask
% pic_name    The path where the image will be saved
% map_data    The calculated data
% x_lin       The lon values for the picture's axes
% y_lin       The lat values for the picture's axes
% file_date    The date of the satellite pass
% path_row    The string version of the path-row combination
% Author: Gabriel Hesketh
% Date: April 2021
function draw_qa_mask(pic_name, map_data, x_lin, y_lin, path_row, file_date)
  figure1 = figure('visible', 'off');  %this is similar to Window in IDL
  f = 'Times New Roman';
  %set the color map
  c_map =  vertcat([.4, .4, .4], [0 0 .8],  [.8 .8 .8], [.9 .9 .9], [1 1 1], [0 0 0]);
  col_labels = {'Land', 'Ocean', 'Cloud Shadow', 'Snow','Cloud', 'Outside'};
  colormap(c_map); 

  % process axes and other image elements
  imagesc(x_lin, flipud(y_lin'), map_data);
  hold on;
  axis xy; % remove the _ from path_row so it isn't subscripted in the title
  title(strcat("QA Pixel Band Generated Mask for ", file_date),...
    strcat(" Landsat-8 Path-Row: ", path_row), 'FontName', f, 'FontSize',14);
%   t = set(t);
  set(gca,'Ydir','normal');
  caxis([0 5]);
  cbh = colorbar('vert','XTick', 0:1:5, 'XTickLabel', col_labels);
%   cbh.Position(1) = cbh.Position(1) - .001;
%   c = set(cbh);
  xLab = xlabel(cbh, "Types");
  xLab.Position(1) = xLab.Position(1) - 1;
%   x_l = set(xLab);
%   disp(pic_name);
  print(figure1, '-dpng', '-r800', pic_name);

  % uncomment the next two lines for a detailed tif image
  % tif_name = strrep(pic_name, 'png', 'tif');
  % print(figure1, '-dtiffn', '-r800', pic_name);

  % uncomment the next lines to resize the image
  % figImage = imread(png_name);
  % resizedImage = imresize(figImage, [1244 933]); %resize it to different sizes here
  % imwrite(resizedImage, pic_name);
  hold off;
  clf(1);
end

% This is a function to scan Landsat .mtl files and return
% all requested meta data. 
% path                   The file's path
% values_list            A list of values to search for
% return meta_values    The values to be returned
% Author: Gabriel Hesketh
% Date: April 2021
function meta_values = get_meta_values(path, values_list)
  meta_values = [];
  raw_text = fileread(path);
  % disp(timeText); %next line moves to cloud cover
  for i=1:length(values_list)
    value_to_search = values_list(i);
    value_obtained = base_parse(value_to_search, raw_text);
    % disp(valueToSearch);
    % disp(valueObtained);
    meta_values = [meta_values; value_obtained];
  end
end

% A function for filtering the text file by search term.
% This function is optimized for Landsat-8 files. Some queries
%  even for L8 may require additional trimming or different search terms.
% search_term          The term being searched for
% init_text            The file, given as a character array
% return parse_text    The value of the desired variable
% Author: Gabriel Hesketh
% Date: April 2021
function parse_text = base_parse(search_term, init_text)
  search_term = strcat(search_term, " = ");
  parse_text = strsplit(init_text, search_term); 
  parse_text = char(parse_text(2));
  parse_text = strsplit(parse_text, ' '); 
  parse_text = char(parse_text(1)); 
  parse_text = strtrim(parse_text); 
  parse_text = convertCharsToStrings(parse_text);
end
