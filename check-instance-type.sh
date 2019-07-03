#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

######################################
# 1.1 Parse options
######################################
for OPT in "$@"
do
  case "$OPT" in
    '--availability-zone' )
      if [ -z "$2" ]; then
          echo "option --availability-zone requires an argument -- $1" 1>&2
          exit 1
      fi
      AVAILABILITY_ZONE="$2"
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
if [ -z "${AVAILABILITY_ZONE}" ] ; then
  >&2 echo "ERROR: Option --availability-zone needs to be specified"
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
mkdir -p "output"
OUTPUT_FILE="output/${AVAILABILITY_ZONE}.${INSTANCE_TYPE}.json"
JSON_MAPPING=$(jq ".\"${AVAILABILITY_ZONE}\"" < "${MAPPING_FILE}")

# "null" is used when jq does not find the key ${AVAILABILITY_ZONE}
if [ -z "${JSON_MAPPING}" ] || [ "${JSON_MAPPING}" = "null" ]; then
  >&2 "ERROR: mapping for \"${AVAILABILITY_ZONE}\" does not exist in ${MAPPING_FILE}"
  exit 1
else
  IMAGE_ID=$(echo "${JSON_MAPPING}" | jq -r '.image_id')
  SUIBNET_ID=$(echo "${JSON_MAPPING}" | jq -r '.subnet_id')
  REGION=$(echo "${JSON_MAPPING}" | jq -r '.region')
  OUTPUT=$(aws ec2 run-instances \
      --image-id "${IMAGE_ID}" \
      --instance-type "${INSTANCE_TYPE}" \
      --subnet-id "${SUIBNET_ID}"  \
      --tag-specifications "ResourceType=instance,Tags=[{Key=experiment-name,Value=aws-ec2-instance-types}]" \
      --region "${REGION}" 2>&1)
  if [ $? -eq 0 ] ; then
    echo "{ \"${AVAILABILITY_ZONE}\": { \"${INSTANCE_TYPE}\": true } }" > "${OUTPUT_FILE}"
    INSTANCE_ID=$(echo "${OUTPUT}" | jq -r '.Instances[].InstanceId')
    aws ec2 wait instance-status-ok --instance-ids "${INSTANCE_ID}" --region "${REGION}" 1>/dev/null
    aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION}" 1>/dev/null
    aws ec2 wait instance-terminated --instance-ids "${INSTANCE_ID}" --region "${REGION}" 1>/dev/null
  else
    >&2 echo "ERROR: Failed to run instance of image_id=${IMAGE_ID}, instance_type=${INSTANCE_TYPE} and availability_zone=${AVAILABILITY_ZONE}. ${OUTPUT}"
  fi
fi