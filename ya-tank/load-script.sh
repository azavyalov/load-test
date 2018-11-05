#!/bin/bash

set -x

# string parameters in jenkins
incrementDay=$DAYS
loadSchedule=$loadSchedule

# boolean parameter in jenkins
noCache=$noCache

# date of access log file and name of test folder 
accessLogDate="$(date -d "$incrementDay day" +"%Y%m%d")" 
          
# name of reportFolder
reportName="$(date +%Y-%m-%d-%H-%M-%S)"
                   
# dir of reportFolder
reportDirectory=/home/user/testproject

# fullname of accesslog file
nameOfAccesslog=testproject_$accessLogDate.access.log

# fullname of accesslog archive
nameOfAccesslogArchive=$nameOfAccesslog.gz

# directory of accesslog archive
dirOfAccesslogFromBackups=/mnt/logs/nginx/nginx/$nameOfAccesslogArchive
   
# directory of loadtest
directory=$directory
 
copy_accesslog() {
	mkdir -p "$directory"
	cp $dirOfAccesslogFromBackups $directory
	gunzip -f "$directory/$nameOfAccesslogArchive"
}

create_requests() {
	cat $directory/$nameOfAccesslog | awk '$9 < 400' | grep GET | awk '{print $7}' > $directory/get-requests.txt
	cat $directory/$nameOfAccesslog | awk '$9 < 400' | grep POST | grep '/view' | awk '{print $7}' > $directory/post-requests.txt
}

prepare_requests() {
	sed 's/^/GET||/;s/$/||good||/' $directory/get-requests.txt > $directory/get-requests-for-ammo-generator.txt
	sed 's/^/POST||/;s/$/||good||/' $directory/post-requests.txt > $directory/post-requests-for-ammo-generator.txt
}

copy_report() {
	mkdir -p "$reportDirectory/$reportName" 
	find $directory -iname '*.html' -and -type f -mmin -1 -exec cp '{}' $reportDirectory/$reportName \; # search and copy new report file
}

# copy access.log from nginx backup
copy_accesslog

# remove requests with 4**/5** code return and create 2 file with GET and POST URL's
create_requests

# prepare requests for ammo generator
prepare_requests

# merge GET and POST requests
cat $directory/get-requests-for-ammo-generator.txt $directory/post-requests-for-ammo-generator.txt > $directory/all-requests.txt

# shuffle lines
shuf $directory/all-requests.txt --output="$directory/all-requests.txt"

# Generate requests. If noCache is disabled then create an ammuniniton without no cache parameter. If noCache is enabled, then create an ammunition with no cache
if $noCache; then
	cat $directory/all-requests.txt | python $directory/make_ammo_no_cache.py > $directory/ammunition.ammo
else
	cat $directory/all-requests.txt | python $directory/make_ammo.py > $directory/ammunition.ammo
fi

# start load test
cd $directory
yandex-tank -c "load.ini" -o "$loadSchedule"

# copy report from test directory to public server
copy_report