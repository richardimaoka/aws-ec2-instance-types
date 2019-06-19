#!/bin/sh

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
    -*)
      echo "illegal option -- $1" 1>&2
      exit 1
      ;;
  esac
done

######################################
# 1.2 Validate options
######################################
if [ -z "${REGION}" ] ; then
  echo "ERROR: Option --region needs to be specified"
  exit 1
fi

######################################
# 2. Main processing
######################################
for INSTANCE_TYPE in $(cat instance-types.txt | grep -v "#")
do
  echo "${INSTANCE_TYPE}"
  aws ec2 run-instances \
    --image-id "${SOURCE_IMAGE_ID}"
    --instance-type "${SOURCE_INSTANCE_TYPE}" \
    --region "${REGION}"
done