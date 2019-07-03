#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

# Start of JSON
echo "{"

# Returned regions can be different dependent on your AWS account
REGIONS=$(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)
for REGION in $REGIONS
do
  # Somehow single quote + backquote works for the boolean in --query, but otherwise it doesn't work...
  VPC_ID=$(
    aws ec2 describe-vpcs \
      --query 'Vpcs[?IsDefault==`true`].VpcId'\
      --output text \
      --region "${REGION}"
  )
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
  AMI_LINUX2=$(aws ec2 describe-images \
    --owners amazon \
    --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' \
    --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
    --output text \
    --region "${REGION}"
  )
  SUBNETS_JSON=$(
    aws ec2 describe-subnets \
      --query "Subnets[?VpcId=='${VPC_ID}']" \
      --region "${REGION}"
  )

  AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones \
    --query "AvailabilityZones[].[ZoneName]" \
    --output text \
    --region "${REGION}"
  )
  for AVAILABILITY_ZONE in $AVAILABILITY_ZONES
  do
    SUBNET_ID=$(echo "${SUBNETS_JSON}" | jq -r ".[] | select(.AvailabilityZone==\"${AVAILABILITY_ZONE}\") | .SubnetId")

    echo "\"${AVAILABILITY_ZONE}\": {"
    echo "  \"region\": \"${REGION}\","
    echo "  \"image_id\": \"${AMI_LINUX2}\","
    echo "  \"subnet_id\": \"${SUBNET_ID}\""
    if [ "$REGION" = "$(echo "${REGIONS}" | tail -1)" ] && \
       [ "$AVAILABILITY_ZONE" = "$(echo "${AVAILABILITY_ZONES}" | tail -1)" ] ; then 
      echo "}"
    else
      echo "},"
    fi
  done
done

# End of JSON
echo "}"
