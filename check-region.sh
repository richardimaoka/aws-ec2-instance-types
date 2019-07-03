#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

######################################
# 1.1 Parse options
######################################
for OPT in "$@"
do
  case "$OPT" in
    '--region' )
      if [ -z "$2" ]; then
          echo "option --region requires an argument -- $1" 1>&2
          exit 1
      fi
      REGION="$2"
      shift 2
      ;;  
    '--instance-type' )
      if [ -z "$2" ]; then
          echo "option --instance-type requires an argument -- $1" 1>&2
          exit 1
      fi
      INSTANCE_TYPE="$2"
      shift 2
      ;;
    '-f' | '--mapping-file' )
      if [ -z "$2" ]; then
          echo "option -f or --mapping-file requires an argument -- $1" 1>&2
          exit 1
      fi
      MAPPING_FILE="$2"
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
if [ -z "${REGION}" ] ; then
  >&2 echo "ERROR: Option --region needs to be specified"
  ERROR="1"
fi
if [ -z "${INSTANCE_TYPE}" ] ; then
  >&2 echo "ERROR: Option --instance-type needs to be specified"
  ERROR="1"
fi
if [ -z "${MAPPING_FILE}" ] ; then
  >&2 echo "ERROR: Option --mapping-file or -f needs to be specified"
  ERROR="1"
elif ! jq "." < "${MAPPING_FILE}" 1>/dev/null ; then
  >&2 echo "ERROR: The value for the option --mapping-file or -f is not a valid JSON."
  ERROR="1"
fi

if [ -n "${ERROR}" ] ; then
  exit 1
fi

######################################
# 2. Main processing
######################################
for AVAILABILITY_ZONE in $(aws ec2 describe-availability-zones \
  --query "AvailabilityZones[].[ZoneName]" --output text --region "${REGION}")
do
  # echo "Checking ${INSTANCE_TYPE} availability in ${AVAILABILITY_ZONE} (${REGION})"
  ./check-instance-type.sh \
    --instance-type "${INSTANCE_TYPE}" \
    --availability-zone "${AVAILABILITY_ZONE}" \
    --mapping-file "${MAPPING_FILE}"
done
