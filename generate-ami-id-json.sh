#!/bin/bash

echo "{"

LAST_REGION=$(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text | tail -1)
for REGION in $(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)
do
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
  AMI_LINUX2=$(aws ec2 describe-images \
    --region "${REGION}" \
    --owners amazon \
    --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' \
    --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
    --output text
  )


  if [ "$REGION" = "${LAST_REGION}" ]; then 
    echo "\"${REGION}\": \"${AMI_LINUX2}\""
  else
    echo "\"${REGION}\": \"${AMI_LINUX2}\","
  fi
done

# End of JSON
echo "}"
