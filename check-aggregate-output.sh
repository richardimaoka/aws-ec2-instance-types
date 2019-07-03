#!/bin/sh

# cd to the current directory as it scans files in sub directories
cd "$(dirname "$0")" || exit

######################################
# 2. Main processing
######################################
OUTPUT_FILE=instance_type_availability.json
echo "{}" > "${OUTPUT_FILE}"
for JSON_FILE in output/*.json
do
  OUTPUT=$(jq -s '.[0] * .[1]' "${OUTPUT_FILE}" "${JSON_FILE}")
  echo "${OUTPUT}" > "${OUTPUT_FILE}"
done
