#!/bin/bash
#Written by Jing Xiang CHUNG 8th April 2021
#Please report bugs at jingxiang89@gmail.com
#
#ncl2qgis version 0.02a, reformats the ncl color table to QGIS XML format.
#
#Usage: 
# ncl2qgis.sh <ncl-color.rgb> [ -c <num-of-col> ] [ -f ]
#
#note:
#1. "ncl-color.rgb" file can be downloaded from:
#    http://www.ncl.ucar.edu/Document/Graphics/color_table_gallery.shtml"
#
#2. optional option switches (need not to be specified in sequence):
#  i.  -c <num-of-col> : specified the number of colours wanted
#  ii. -f              : flip the colour wanted in opposite direction
#
#e.g of usage:
# i.   Normal conversion:
#      bash ncl2qgis.sh CBR_drywet.rgb
# ii.  Only 6 colours wanted:
#      bash ncl2qgis.sh CBR_drywet.rgb -c 6
# iii. Flipping the colours and only 6 colours wanted: 
#      bash ncl2qgis.sh CBR_drywet.rgb -c 6 -f
# iv.  Flipping the the colours only:
#      bash ncl2qgis.sh CBR_drywet.rgb -f
#-----------------------------------------------------------------------------------
#0. Checking user's inputs
#rgbfile=${1}; [[ ${rgbfile} == "" ]] && echo "Please provide the .rgb file name from NCL color table!" && exit
rgbfile=${1}; [[ ${rgbfile} == "" ]] && cat ncl2qgis.sh | head -n 26 | sed 's/#//g' && exit
[[ ! -f ${rgbfile} ]] && echo "${rgbfile} not found!" && exit

if [[ ${2} != "" ]]; then
	case ${2} in
		"-c" ) 
			coltnum=${3}; ! [[ ${coltnum} =~ ^[0-9]+$ ]] &&	echo "Number of colours wanted must be a positive integer!" && exit
			if [[ ${4} != "" ]]; then
				if [[ ${4} == "-f" ]]; then
					flipopt='_flipud'; echo "Color table will be flipped!";
				else
					echo "Option ${4} is not available!"; exit
				fi
			fi
			;;
		"-f" ) 
			flipopt='_flipud'
			if [[ ${3} != "" ]]; then
				if [[ ${3} == "-c" ]]; then
					coltnum=${4}; ! [[ ${coltnum} =~ ^[0-9]+$ ]] && echo "Number of colours wanted must be a positive integer!" && exit
				else
					echo "Option ${3} is not available!"; exit
				fi
			fi
			echo "Color table will be flipped!" 
			;;
		*)
			echo "Option ${2} is not supported!"; exit
			;;	
	esac
fi

#Script start-----------------------------------------------------------

#1. Clean up the .rgb file from NCL color table gallery
#remove lines with non-numeric characters, empty lines and empty spaces at the begining of lines
rgbclean=$( cat ${rgbfile} | sed 's/\r//g;s/^[ \t]*//g;s/ \{1,\}/,/g' | awk -F ',' '{print $1,$2,$3}' | sed '/^[^0-9]/d' )

#2. Pre-process the .rgb output
#Check the values in the .rgb file, make sure it is in 0-255 format
if [[ ${rgbclean} == *.* ]]; then coltype=0; else coltype=255; fi

#3. Set standardized the .rgb file to 0-255 format
if [[ ${coltype} == 255 ]]; then
	rgbcol="${rgbclean}"
elif [[ ${coltype} == 0 ]]; then
	echo "${rgbclean}" | while read -r R G B; do
		r=$(printf %.0f $(echo "scale=1;${R}*255" | bc -l))
		g=$(printf %.0f $(echo "scale=1;${G}*255" | bc -l))
		b=$(printf %.0f $(echo "scale=1;${B}*255" | bc -l))
		echo "${r} ${g} ${b}">>rgbclean.tmp
	done
	rgbcol=$(cat rgbclean.tmp ); rm -rf rgbclean.tmp
fi

#4. Did user specified how many colours he/she wants?
if [[ ${coltnum} == "" ]];then
	rgbcol="${rgbcol}"
else
	rgbnum=$( echo "${rgbcol}" | wc -l )
	[ ${rgbnum} -lt ${coltnum} ] && echo "${rgbfile} does not have ${coltnum} colours!"	&& exit
	rgbint=$(printf %.0f $(echo "scale=1;${rgbnum}/${coltnum}" | bc -l))
	for (( rnum=1; rnum<=${rgbnum}; rnum++ )); do
		echo "${rgbcol}" | awk "NR == ${rnum}">>rgbintv.tmp
		rnum=$(printf %.0f $(echo "scale=1;${rnum}+${rgbint}-1" | bc -l))
	done
	
	rgbcol=$(cat rgbintv.tmp ); rm -rf rgbintv.tmp
fi

#5. Did the user want the colours table flipped?
if [[ ${flipopt} == '_flipud' ]]; then
	rgbcol=$( echo "${rgbcol}" | tac )
fi

#6. Formatting the output to QGIS understandable
#How many colours we have?
tcol=`echo "${rgbcol}" | wc -l`
#Check the intervals
intervals=`echo ${tcol} 1 | awk -F " " '{print $2/($1-1)}'`

rgbcol=(`echo "${rgbcol}" | sed 's/ /,/g;s/$/,255/g'`)
segments=(`seq 0 ${intervals} 100`)

[[ -f qgisrgb.tmp ]] && rm qgisrgb.tmp
for (( x=0; x<${tcol}; x++ )); do

	echo "${segments[${x}]};${rgbcol[${x}]}" >> qgisrgb.tmp

done

#7. Writting output to QGIS XML
rgbqgis=`cat qgisrgb.tmp`; rm qgisrgb.tmp
rgbqgis=`echo ${rgbqgis} | sed 's/ /:/g'`

startcol=`echo ${rgbqgis} | cut -d ":" -f 1 | cut -d ";" -f 2`
endcol=`echo ${rgbqgis} | cut -d ":" -f ${tcol} | cut -d ";" -f 2`
colbody=`echo ${rgbqgis} | cut -d ":" -f 2-$((tcol-1))`

colname=`basename ${rgbfile%.rgb}${coltnum}`
if [[ ${flipopt} == '_flipud' ]]; then
	colname=${colname}_flipud
fi
cat > ${colname}.xml << EOF

<!DOCTYPE qgis_style>
<qgis_style version="2">
  <symbols/>
  <colorramps>
    <colorramp tags="${colname}" type="gradient" name="${colname}">
      <prop v="${startcol}" k="color1"/>
      <prop v="${endcol}" k="color2"/>
      <prop v="0" k="discrete"/>
      <prop v="gradient" k="rampType"/>
      <prop v="${colbody}" k="stops"/>
    </colorramp>
  </colorramps>
  <textformats/>
  <labelsettings/>
</qgis_style>

EOF

echo "Job converting ${rgbfile} to QGIS XML format completed!"

