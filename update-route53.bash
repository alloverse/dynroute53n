#!/bin/bash

set -x

TMPFILE=/tmp/u53tempfile
TMPFILE_URI="file://$TMPFILE"
AWS=/usr/local/bin/aws

function try  {
    eval $*
    if [ $? -ne 0 ]; then
        echo "Error while evaluating \"$*\", exiting..."
        exit 1
    fi
}

try rm -f $TMPFILE

try curl -s http://169.254.170.2/v2/metadata -o $TMPFILE 

ECS_CLUSTER=$(cat $TMPFILE | jq -r '.Cluster'|cut -d/ -f2)
ECS_TASK=$(cat $TMPFILE | jq -r '.TaskARN'|cut -d/ -f2)

if [[ -z "${ECS_CLUSTER}" ]]  || [[ -z "${ECS_TASK}" ]] ; then
    echo "Missing Task or Cluster ID, exiting..." 
    exit 1
fi

try $AWS ecs describe-tasks --tasks $ECS_TASK --cluster $ECS_CLUSTER  > $TMPFILE
ENI_ID=$(cat $TMPFILE | jq -r '.tasks[].attachments[].details[] | select(.name =="networkInterfaceId") | .value ')


if [[ -z "${ENI_ID}" ]] ; then
    echo "Missing ENI ID, exiting..." 
    exit 1
fi

try $AWS ec2 describe-network-interfaces  --filters Name=network-interface-id,Values=$ENI_ID > $TMPFILE

R53_PUBLIC_IP=$(cat $TMPFILE | jq -r '.NetworkInterfaces[0].Association.PublicIp')

if [[ -z "${R53_PUBLIC_IP}" ]] ; then
    echo "Missing Public IP, exiting..." 
    exit 1
fi

# The below two parameters are expected to be supplied as environment variables. 
# Preferably supplied under Container settings in the ECS task definition
 
if [[ -z "${R53_HOST}" ]] || [[ -z "${R53_ZONEID}" ]]  ; then
    echo "Missing required parameters to update Route53, exiting..." 
    exit 1
fi


cat << EOF > $TMPFILE
{
    "Comment": "Upsert record for new ECS public address",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$R53_HOST",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$R53_PUBLIC_IP"
                    }
                ]
            }
        }
    ]
}
EOF

echo "Trying to upsert $R53_HOST to $R53_PUBLIC_IP in zone $R53_ZONEID"
try $AWS route53 change-resource-record-sets --hosted-zone-id $R53_ZONEID --change-batch $TMPFILE_URI

echo "Done! Now sleeping."
while true; do sleep 86400; done