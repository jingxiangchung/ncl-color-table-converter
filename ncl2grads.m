%Written by JingXiang CHUNG on 27th Jan 2015 (version beta 0.3)
%Reformat NCL .rgb file to MATLAB and GrADS format
%
%Report bugs at jingxiang89@gmail.com
%Updated 1 on 26th Aug 2015 (version beta 0.4)
%Updated 2 on 23th Apr 2016 (version beta 0.5)
%
%NCL color table file can be obtained from 
%   http://www.ncl.ucar.edu/Document/Graphics/color_table_gallery.shtml
%
%Usage:
% [matlab_col, rgb_set, kodama_col] = ncl2grads('<ncl.rgb file>','number of colours wanted');
%
%e.g. precip_11lev.rgb
% [matlab_col, rgb_set, kodama_col] = ncl2grads('precip_11lev.rgb',2);
%
%Note:
%1. matlab_col will hold the R G B values formatted to MATLAB format.
%2. rgb_set will hold the R G B values formatted to GrADS set rgb format.
%3. kodama_col will hold the R G B values formatted to Chihiro Kodama's color.gs format.
%4. The 'number of colours wanted' need not to be specified if all the colours in the .rgb file are wanted.

 function varargout = ncl2grads (varargin)

    if nargin  > 2; error('Error:ArgumentsNumber','Too many input arguments specified! \n Type help ncl2grads for help ...');end
    if nargout > 3; error('Error:ArgumentsNumber','Too many output arguments specified!\n Type help ncl2grads for help ...');end
    
    try
        colfname = varargin{1};
    catch
        help ncl2grads
        return
    end
    
    if nargin==2
        
        if isnumeric(varargin{2})
            intV=varargin{2};
        else
            intV=str2double(varargin{2});
        end
       
       if isnan(intV)
           error('Error:InputErr','Interval input is NaN! Please give a number instead!')        
       end      
    end
    	
	if ls(colfname);else error('Error:NullFile',['Colour map ''',colfname,''' specified is not available']); end
    
    %Reading the text file line by line
    fid = fopen(colfname);
    tline = fgetl(fid); 
    count=1;
    while ischar(tline)
        coldat(count,:) = cellstr(tline);
        tline = fgetl(fid);
        count=count+1;
    end
    fclose(fid);
    
    %Locate where the R G B values start in the .rgb
    coldat = coldat(~cellfun('isempty', coldat));
    %Remove all everything expect word, standardizing all .rgb (equavalent with ^a-zA-Z0-9)
    coldat_tmp = regexprep(coldat,'[^\w]',''); 
    tagloc = find(strcmpi(coldat_tmp,'rgb'));
    coldat = strtrim(coldat(tagloc+1: length(coldat),:));
    
    %Determine the interval of colours wanted
    if nargin==2
        
        if intV > length(coldat)
           error('Error:OutOfBound','Interval specified is larger than the number of colours available!') 
        end
        
        numberColour=floor(length(coldat)/intV);
        lastColour=coldat(length(coldat),:);
        coldat=coldat(1:numberColour:length(coldat));
        coldat(length(coldat),:)=lastColour;
    end
    
    
    %Read in values, convert them to 0-255 format
    rgb_val=ones(1,3)*-130389;
    rgb_col=ones(length(coldat),3);
    for colnum = 1:length(coldat)
        
        col_tmp = textscan(coldat{colnum},'%q');
        
        for valnum = 1:3
            val = str2double(col_tmp{1}{valnum});            
            rgb_val(:,valnum) = val;
        end   
        
        rgb_col(colnum,:) = rgb_val;
        
    end
    
    try
        if find(rgb_col > 0 & rgb_col <1); rgb_col = rgb_col*255; end %Making sure format is 0-255
        rgb_col = strtrim(cellstr(num2str(floor(rgb_col))));
    catch
        error('Error:FormatError', ['Format file not supported!', ...
            ' \n Make sure your colour map file follow the format of NCL''s'])
    end
  
    %Clean up unwanted spacing
    rgb_col = regexprep(rgb_col,' +',' '); %Replace multiple blanks with single blank
    
    %Split the colour values into appropriate rows and columns
    for i = 1:length(rgb_col); val_array(i,:)=strsplit(rgb_col{i,:}); end
    
    %Convert to MATLAB format
    for i = 1:size(val_array,1);
        for j = 1:size(val_array,2)
	end
    end
    
    varargout(1) = {rgb_num};
    
    %Convert to GrADS set rgb forme
    if nargout >= 2 
        rgbset = cell(length(rgb_col),1); %Preallocate cells
        for colnum = 1:length(rgb_col)          
            rgbset(colnum,:)   = cellstr(['''set rgb ',num2str(20+colnum),' ',rgb_col{colnum},'''']);
        end
        varargout(2) = {rgbset};
        
    end
    
    %Convert to GrADS Kodama's color.gs forme
    if nargout == 3
        colorset = cell(length(rgb_col),1); %Preallocate cells
        for colnum = 1:length(rgb_col)
            colorset(colnum,:) = cellstr(['( ',rgb_col{colnum},')']);
        end
        
        colorset = strrep(colorset, ' '  , ',' );
        colorset = strrep(colorset, '(,' , '(' );
        
        kodama_col = [colorset{1:length(colorset)}];
        kodama_col = cellstr(strrep(kodama_col,')(',')->('));
        
        varargout(3) = {kodama_col};
    end 
 
 end
