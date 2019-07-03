#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

############################################################
# Kill the child (background) processes on Ctrl+C = (SIG)INT
############################################################
# This script runs check-region.sh in the background
# https://superuser.com/questions/543915/whats-a-reliable-technique-for-killing-background-processes-on-script-terminati/562804
trap 'kill -- -$$' INT

######################################
# 1.1 Parse options
######################################
for OPT in "$@"
do
  case "$OPT" in
    '-f' | '--mapping-file' )
      if [ -z "$2" ]; then
          echo "option -f or --mapping-file requires an argument -- $1" 1>&2
          exit 1
      fi
      MAPPING_FILE="$2"
      shift 2
      ;;
    '--instance-types-file' )
      if [ -z "$2" ]; then
          echo "option --instance-types-file requires an argument -- $1" 1>&2
          exit 1
      fi
      INSTANCE_TYPES_FILE="$2"
      shift 2
      ;;
    -*)
      echo "illegal option $1" 1>&2
      exit 1
      ;;
  esac
done

######################################
# 1.2 Validate options
######################################
if [ -z "${MAPPING_FILE}" ] ; then
  >&2 echo "ERROR: Option --mapping-file or -f needs to be specified"
  ERROR="1"
fi
if [ -z "${INSTANCE_TYPES_FILE}" ] ; then
  >&2 echo "ERROR: Option --instance-types-file needs to be specified"
  ERROR="1"
fi

if [ -n "${ERROR}" ] ; then
  exit 1
fi

######################################
# 2. Main processing
######################################
INSTANCE_TYPES=$(grep -v "#" < "${INSTANCE_TYPES_FILE}" | sed -e 's/\s//g') # sed to remove whitespace

for REGION in $(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)
do
  for INSTANCE_TYPE in $INSTANCE_TYPES
  do
    echo "Checking ${INSTANCE_TYPE} availability in ${REGION}"
    if [ -n "${INSTANCE_TYPE}" ] ; then
      ./check-region.sh \
        --instance-type "${INSTANCE_TYPE}" \
        --mapping-file "${MAPPING_FILE}" \
        --region "${REGION}" &
    fi
  done
done

######################################
# 3. Wait until the children complete
######################################
echo "Wait until all the child processes are finished..."

#Somehow VARIABLE=$(jobs -p) gets empty. So, need to use a file.
TEMP_FILE=$(mktemp)
jobs -p > "${TEMP_FILE}"

# Read and go through the ${TEMP_FILE} lines
while IFS= read -r PID
do
  wait "${PID}"
done < "${TEMP_FILE}"

rm "${TEMP_FILE}"
echo "Finished!!"