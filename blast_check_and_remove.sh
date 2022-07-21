#!/bin/bash 

perc_identity=80
word_size=11
declare -A blast_pattern_assoc

while getopts ":o:s:q:p:w:" opt; do
  case $opt in
    o) output="$OPTARG"
    ;;
    q) query="$OPTARG"
	 ;;
    s) subject="$OPTARG"
    ;;
	p) perc_identity=${OPTARG}
	;;
	w) word_size=${OPTARG}
	;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

now=$(date)
timestamp=$(date +%s)
printf "$now \n"
printf "$timestamp (temp)\n"
printf "Subject file %s\n" "$subject"
printf "Query file %s\n" "$query"
printf "Output file %s\n" "$output"
printf "perc_identity file %s\n" "$perc_identity"
printf "word_size %s\n" "$word_size"
tempfa="$(basename subject)${timestamp}"
printf "temp_file %s\n" "$tempfa"
#cat $subject

#cp $subject $output
echo -n "" > "$output"

awk '(NR-1)%4<2'  $subject | sed -e "s/^@/>/" > $tempfa

blast_patterns=($(blastn -query $query -subject $tempfa -perc_identity $perc_identity -word_size $word_size -outfmt 6 | awk '{print $2}'))
for row in "${blast_patterns[@]}"
do
   :
   blast_pattern_assoc[$row]=""
done

removed=0
copy=1
init=1
while read line; do
		# reading each line
	#echo $line
	if [[ $line == @* ]]
	then
		#echo $line
		id=$(echo $line|awk '{print $1}')
		id="${id:1}"		
		if [[ -v "blast_pattern_assoc[$id]" ]] ; then
			#echo "SET"
			#echo $id
			removed=$((removed+1))
			copy=0
			init=0
		fi
	fi
	if [ $copy -eq 1 ]
	then
		echo "$line" >> "$output"
	else #copy eq 0 (false)
		if [ $init -lt 4 ]
		then
			#echo "SKIP"
			init=$((init+1))
		else
			copy=1
			init=0
		fi		
	fi
	
done < $subject


#lines=$(echo $blast_patterns | tr "\n" "\n")
#for pattern in $lines
#do
#	#echo $pattern
#	sed -i '/@$pattern/,+4 d' $output
#done

now=$(date)
rm $tempfa
printf "temp_file %s removed\n" "$tempfa"
printf "%s sequences removed\n" "$removed"
printf "Finish $now \n"
