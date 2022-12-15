#!/bin/bash

# Verify the user is root user
[[ ! $(id -u) == 0 ]] && echo you gotta be root && exit 256

# Verify aws CLI installation

linux_architecture=$(uname -m)
echo "My linux kernel architecture: "$linux_architecture
apt-get install curl unzip -y
if [[ $linux_architecture != *"x86_64"* ]]; then
     curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
else
     curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
fi

AWS_CLI_VERSION=$(aws --version 2>&1)
if [ $? -eq 0 ]; then
    echo "AWS CLI is installed tryng to upgrade if its outdated......."
    ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
else
    echo "Did not found AWS CLI installation. Trying to Install............."
    unzip awscliv2.zip
    ./aws/install
    echo "AWS CLI Installed....................."
fi

# Reading user params

read -p "Enter ACCESS_KEY:  " ACCESS_KEY
read -p "Enter SECRET_KEY:  " SECRET_KEY
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ $? -eq 0 ]; then
	echo "Connected to AWS account: "$ACCOUNT_ID
else
	echo "Invalid account credentials"
	exit 100
fi

echo "Started creating Record configs ........................"

STATIC_DOMAIN="sample.com"
ALB_NM="dualstack.sample-9xxxx.us-east-2.elb.amazonaws.com."
REC_TYP="A"
# Refer to: https://docs.aws.amazon.com/general/latest/gr/elb.html)
HostedZoneId="xxxx"
ROUTE53_HostedZoneId="xxxxxxx"
TMP_DIR="$(pwd)/rec_temp"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

for SUB_DOMAIN in "$@"
do

        NEW_DOMAIN="${SUB_DOMAIN}.${STATIC_DOMAIN}"
        echo "Your domain will be : "$NEW_DOMAIN
	cat > "${TMP_DIR}/${SUB_DOMAIN}.json" <<- EOM
	{
	    "Comment": "Creating Alias resource record sets in Route 53(Automated)",
 	    "Changes": [{
        	"Action": "CREATE",
        	"ResourceRecordSet": {
            		"Name": "${NEW_DOMAIN}",
            		"Type": "${REC_TYP}",
            		"AliasTarget": {
                		"HostedZoneId": "${HostedZoneId}",
                		"DNSName": "${ALB_NM}",
                		"EvaluateTargetHealth": false
            		}
       	    	}
    	    }]
	}
	EOM

done

echo "Completed Record configs ........................"

echo "Creating Records in AWS ........................."
for SUB_DOMAIN in "$@"
do
	NEW_DOMAIN="${SUB_DOMAIN}.${STATIC_DOMAIN}.json"
	aws route53 change-resource-record-sets --hosted-zone-id "${ROUTE53_HostedZoneId}" --change-batch "file://${TMP_DIR}/NEW_DOMAIN"
done
echo "Records added"
