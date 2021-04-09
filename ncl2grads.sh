#!/bin/bash
#Written by Jing Xiang CHUNG 18 Dec 2015 [UPDATED:26/12/2019]
#Please report bugs at jingxiang89@gmail.com
#
#ncl2grads version 0.09a, reformats the ncl color table to GrADS format.
#
#Usage: 
# ncl2grads.sh <ncl-color.rgb> <type-of-conversion> [ -c <num-of-col> ] [ -f ]
#
#note:
#1. "ncl-color.rgb" file can be downloaded from:
#    http://www.ncl.ucar.edu/Document/Graphics/color_table_gallery.shtml"
#
#2. types of conversion supported are:
#  i.  "grads" - GrADS default set rgb,
#       output will be ended with ".gcol"
#  ii. "kodama" - Kodama's color.gs format, 
#       output will be ended with ".kcol"
#
#3. optional option switches (need not to be specified in sequence):
#  i.  -c <num-of-col> : specified the number of colours wanted
#  ii. -f              : flip the colour wanted in opposite direction
#
#e.g of usage:
# i.   Normal conversion:
#      bash ncl2grads.sh CBR_drywet.rgb kodama
# ii.  Only 6 colours wanted:
#      bash ncl2grads.sh CBR_drywet.rgb kodama -c 6
# iii. Flipping the colours and only 6 colours wanted: 
#      bash ncl2grads.sh CBR_drywet.rgb kodama -c 6 -f
# iv.  Flipping the the colours only:
#      bash ncl2grads.sh CBR_drywet.rgb kodama -f
#-----------------------------------------------------------------------------------

#0. Checking user's inputs
#rgbfile=${1}; [[ ${rgbfile} == "" ]] && echo "Please provide the .rgb file name from NCL color table!" && exit
rgbfile=${1}; [[ ${rgbfile} == "" ]] && cat ncl2grads.sh | head -n 32 | sed 's/#//g' && exit
[[ ! -f ${rgbfile} ]] && echo "${rgbfile} not found!" && exit

cformat=${2}; [[ ${cformat} == "" ]] && echo "Please provide the format you want the color table to be formatted to!" && exit
#if [[ "${cformat,,}" != "grads" ]] && [[ "${cformat,,}" != "kodama" ]]; then
cformat=$(echo ${cformat} | awk '{print tolower($0)}') #Mac BASH not support ${cformat,,} conversion
[[ "${cformat}" != "grads" ]] && [[ "${cformat}" != "kodama" ]] && echo "Conversion format specified not available!" &&	exit

#coltnum=${3}; [[ ${coltnum} != "" ]] && ! [[ ${coltnum} =~ ^[0-9]+$ ]] && echo "Number of colours wanted must be a positive integer!" && exit

if [[ ${3} != "" ]]; then
	case ${3} in
		"-c" ) 
			coltnum=${4}; ! [[ ${coltnum} =~ ^[0-9]+$ ]] &&	echo "Number of colours wanted must be a positive integer!" && exit
			if [[ ${5} != "" ]]; then
				if [[ ${5} == "-f" ]]; then
					flipopt='_flipud'; echo "Color table will be flipped!";
				else
					echo "Option ${5} is not available!"; exit
				fi
			fi
			;;
		"-f" ) 
			flipopt='_flipud'
			if [[ ${4} != "" ]]; then
				if [[ ${4} == "-c" ]]; then
					coltnum=${5}; ! [[ ${coltnum} =~ ^[0-9]+$ ]] && echo "Number of colours wanted must be a positive integer!" && exit
				else
					echo "Option ${4} is not available!"; exit
				fi
			fi
			echo "Color table will be flipped!" 
			;;
		*)
			echo "Option ${3} is not supported!"; exit
			;;	
	esac
fi

#Script start-----------------------------------------------------------

#1. Clean up the .rgb file from NCL color table gallery
#	remove lines with non-numeric characters, empty lines and empty spaces at the begining of lines
#rgbclean=$(grep -v '[A-Za-z]' <${rgbfile} | grep -v '^$' | sed -e 's/^[[:space:]]*//' );
#rgbclean=$(grep -v '[A-Za-z]' <${rgbfile} | sed 's/[^0-9" ".]//g'); #Make sure only numbers remain
#rgbclean=$(sed '/[A-Za-z]/d;/^\s*$/d;/^$/d' < ${rgbfile})
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
		echo "${r} ${g} ${b} ">>rgbclean.tmp
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

#6. Format to wanted format and write the colour out
case ${cformat} in
	"grads"  )
		[[ -f ${rgbfile%.*}${flipopt}${coltnum}.gcol ]] && rm ${rgbfile%.*}${flipopt}${coltnum}.gcol
		count=100
		echo "${rgbcol}" | while read -r R G B; do
			echo "'set rgb ${count} ${R} ${G} ${B}'">>${rgbfile%.*}${flipopt}${coltnum}.gcol
			count=$((count+1))
		done
		;;
	"kodama" )
		[[ -f ${rgbfile%.*}${flipopt}${coltnum}.kcol ]] && rm ${rgbfile%.*}${flipopt}${coltnum}.kcol
		echo "${rgbcol}" | while read -r R G B; do
			#echo "(${R},${G},${B})->">>kodacol.tmp
			echo "(${R},${G},${B}) " >>kodacol.tmp
		done
		
		#sed -i '$s/->//g' kodacol.tmp #Remove the -> at the last line #"sed -i" behaves differently between Linux and Mac
		kodacol=$(cat kodacol.tmp)
		rm -rf kodacol.tmp
		# echo ${kodacol} | sed 's/[[:space:]]/->/g'>${rgbfile%.*}${flipopt}${coltnum}.kcol
		echo ${kodacol} | sed 's/[[:space:]]/->/g' | tr '\n' ' ' | sed 's/[[:space:]]//g' >${rgbfile%.*}${flipopt}${coltnum}.kcol
		#sed -i 's/[[:space:]]//g' ${rgbfile%.*}.kcol
		;;
esac
echo "Job converting ${rgbfile} to ${cformat} format completed!"
#Script end-----------------------------------------------------------
#
#Change Logs
#08/01/2016, ncl2grads version 0.02 alpha:
#	1. Correct Mac BASH does not support string substitution.
#	2. Able to remove the special character behind the RGB value of some .rgb files.
#
#09/01/2016, ncl2grads version 0.03 alpha:
#	1. Correct sed -i incompability between Linux and Mac.
#	2. Correct Mac BASH does not support string substitution.
#
#23/04/2016, ncl2grads version 0.04 alpha:
#	1. Correct remove empty lines not working.
#
#27/04/2016, ncl2grads version 0.05 alpha:
#	1. Added the ability to extract number of colours wanted.
#   2. Added the ability to show the usage instruction when user call the script without specifying any input arguments.
#
#18/05/2016, ncl2grads version 0.06 alpha:
#   1. Added the ability to flip the colours wanted in opposite direction.
#   2. Redesigned the way user specifies the number of colours wanted.
#
#05/08/2016, ncl2grads version 0.07 alpha:
#	1. Correct remove empty lines with tab/empty space not working.
#
#26/09/2016, ncl2grads version 0.08 alpha:
#	1. Correct the mistaken removal of lines of RGB values with words written at the end of line.
#	2. Able to work with .rgb ascii file written in Windows OS.
#
#26/12/2019, ncl2grads version 0.09 alpha
#	1. Remove the annoying new line spacing for .kcol file.
