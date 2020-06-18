#!/bin/bash

#Read environment parameters from udagram-dev-variables.txt file and add them to array
EnvValuesArr=()
while IFS= read -r line; do
   EnvValuesArr+=("$line")
done < ./udagram-dev-variables.txt

#Empty S3 Buket
echo ""
echo -e "\e[1;32mTask1:\e[0m"
echo "Deleting S3 Bucket objects...."
#Get S3 Bucket Name from the stack resources
StackS3BuckName=`aws cloudformation describe-stack-resources --stack-name ${EnvValuesArr[0]} --logical-resource-id S3Bucket --query "StackResources[0].PhysicalResourceId" --output text`
aws s3 rm s3://$StackS3BuckName --recursive

#Delete CloudFormation Stack
echo ""
echo -e "\e[1;32mTask2:\e[0m"
echo "Deleting CloudFormation Stack ${EnvValuesArr[0]} from AWS Region ${EnvValuesArr[1]}...."
aws cloudformation delete-stack --stack-name ${EnvValuesArr[0]} --region ${EnvValuesArr[1]}

echo ""
echo "Deleting Cloud Formation Stack ${EnvValuesArr[0]} on AWS Region ${EnvValuesArr[1]} has been initiated"
echo -e "To Monitor stack deletion events open another session and run command:\e[1;34m aws cloudformation describe-stacks --stack-name ${EnvValuesArr[0]} --region ${EnvValuesArr[1]} --query \"Stacks[0].[StackName, StackStatus]\" --output text \e[0m"

#Wait until stack deletion completes
aws cloudformation wait  stack-delete-complete --stack-name ${EnvValuesArr[0]} --region ${EnvValuesArr[1]}
echo "Stack has been deleted"

#Delete the SSH Key Pair
echo ""
echo -e "\e[1;32mTask3:\e[0m"
echo "Deleting SSH Key Pair from AWS Region ${EnvValuesArr[1]}...."
aws ec2 delete-key-pair --key-name ${EnvValuesArr[2]} --region ${EnvValuesArr[1]}

#Delete the SSH key from user's SSH directory
echo ""
echo -e "\e[1;32mTask4:\e[0m"
echo "Deleting SSH key ${EnvValuesArr[2]}.pem from $HOME/.ssh directory...."
rm $HOME/.ssh/${EnvValuesArr[2]}.pem

#Delete AWS SSM Parameters
echo ""
echo -e "\e[1;32mTask5:\e[0m"
echo "Deleting AWS SSM Parameters from AWS Region ${EnvValuesArr[1]}...."
aws ssm delete-parameter --name /Dev/Udagram/EnvironmentName --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/S3BucketName --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/AWSManagedPolicyARNForS3 --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/AWSManagedPolicyARNForCF --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/AWSManagedPolicyARNForSSMRO --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/AWSManagedPolicyARNForSSMCore --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/AWSManagedPolicyARNForCloudWatchAgent --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/VpcCIDR --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/PublicSubnet1CIDR --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/PublicSubnet2CIDR --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/PrivateSubnet1CIDR --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/PrivateSubnet2CIDR --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/WebAppImageID --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/WebAppInstancesNumber --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/LinuxSSHKey --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/SSHPrivateKey --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/WebAppInstanceType --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/WebAppDiskSize --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/BastionHostImageID --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/BastionHostInstanceType --region ${EnvValuesArr[1]}
aws ssm delete-parameter --name /Dev/Udagram/BastionHostDiskSize --region ${EnvValuesArr[1]}

#Delete environment parameters file
echo ""
echo -e "\e[1;32mTask6:\e[0m"
echo "Deleting environment parameters file...."
rm ./udagram-dev-variables.txt

echo ""
echo -e "\e[1;32mDone\e[0m"
