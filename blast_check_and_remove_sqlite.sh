#!/bin/bash 

perc_identity=80
word_size=11
rejected_file=""
declare -A blast_pattern_assoc

while getopts ":o:s:q:p:w:r:" opt; do
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
	r) rejected_file="$OPTARG"
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
printf "Rejected file %s\n" "$rejected_file"
printf "perc_identity file %s\n" "$perc_identity"
printf "word_size %s\n" "$word_size"
tempfa="$(basename subject)${timestamp}"
tempsqlite="sqliteblast${timestamp}.db"
printf "temp_file %s\n" "$tempfa"
printf "SQLLiteDB %s\n" "$tempsqlite"
#cat $subject

#cp $subject $output
echo -n "" > "$output"
if [[ -n "$rejected_file" ]]
then 
	echo -n "" > "$rejected_file"
fi
awk '(NR-1)%4<2'  $subject | sed -e "s/^@/>/" > $tempfa

blast_patterns=($(blastn -query $query -subject $tempfa -perc_identity $perc_identity -word_size $word_size -outfmt 6 | awk '{print $2}'))
sqlite3 $tempsqlite "VACUUM;"
sqlite3 $tempsqlite <<EOF
create table seqs (id INTEGER PRIMARY KEY , seq text);CREATE INDEX idx_unq_seq ON seqs(seq);
EOF
printf "database created\n"
printf "filling database\n"
for row in "${blast_patterns[@]}"
do
   :
   #blast_pattern_assoc[$row]=""
   sqlite3 $tempsqlite "insert into seqs (seq) \
         values (\"$row\");"
done
countblast=$( sqlite3 $tempsqlite "select count(*) from seqs" )
printf "Length output blastn %s\n" "$countblast"

removed=0
copied=0
copy=1
init=1
rejected=0
tested=0
while read line; do
		# reading each line
	#echo $line
	if [[ $line == @* ]]
	then
		#echo $line
		tested=$((tested+1))
		id=$(echo $line|awk '{print $1}')
		id="${id:1}"		
		#if [[ -v "blast_pattern_assoc[$id]" ]] ; then
		exists=$( sqlite3 $tempsqlite "select count(*) from seqs where seq=\"$id\"" )
		if [ $exists -ge 1 ] ; then
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
		if [[ $line == @* ]]
		then
			copied=$((copied+1))
		fi 
	else #copy eq 0 (false)
	
		if [ $init -lt 3 ]
		then
			#echo "SKIP"
			#printf "%s begin \n" "$line"
			init=$((init+1))
			if [[ -n "$rejected_file" ]]
			then
				
				echo "$line" >> "$rejected_file"
				if [[ $line == @* ]]
				then
					rejected=$((rejected+1))
				fi
			fi
		else
			#printf "%sstop \n" "$line"
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
printf "%s sequences copied\n" "$copied"
printf "%s sequences rejected\n" "$rejected"
printf "%s sequences tested\n" "$tested"
printf "Finish $now \n"