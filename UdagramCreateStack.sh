#!/bin/bash

function CreateStack ()
{

#Validate CloudFormation YAML Template
#Creation script will be terminated in case of template error to avoid creation of SSH Keys and SSM Parameters 
echo ""
echo -e "\e[1;32mTask1:\e[0m"
echo "Validating CloudFormation Template file $TemplateFile...."
if aws cloudformation validate-template --template-body file://$TemplateFile > /dev/null ; then
    echo ""
    echo "Template file $TemplateFile is valid"
else
   echo -e "\e[1;31mError:\e[0m Template file $TemplateFile is not valid"
   exit
fi

#Create EC2 SSH Key Pair in AWS selected region
#Query the SSH key and add it to user's SSH directory
echo ""
echo -e "\e[1;32mTask2:\e[0m"
echo "Creating SSH Key pair on AWS Region $AWSRegion...."
SSHKeyName="${StackName}-SSHKey"
SSHKeyPair=`aws ec2 create-key-pair --key-name $SSHKeyName --query 'KeyMaterial' --output text --region $AWSRegion`

echo ""
echo -e "\e[1;32mTask3:\e[0m"
echo "Copying the SSH key to your local SSH directory. File name is $HOME/.ssh/$SSHKeyName.pem"
echo -e "${SSHKeyPair//_/\\n}" > $HOME/.ssh/$SSHKeyName.pem
chmod 600 $HOME/.ssh/$SSHKeyName.pem
echo ""

#Get Ubuntu server 18.04 Image AMI from the selected AWS region
UbuntuImageID=`aws ec2  describe-images  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20200408" "Name=architecture,Values=x86_64"  "Name=root-device-type,Values=ebs" "Name=virtualization-type,Values=hvm"   --query 'Images[*].[ImageId]' --output text --region $AWSRegion`

#Create AWS SSM Parameters in the selected Region 
/bin/echo -e "\e[1;32mTask4:\e[0m"
echo "Creating SSM Parameters on AWS Region $AWSRegion...."
aws ssm put-parameter --name /Dev/Udagram/EnvironmentName --value "Udagram-Dev-George" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/S3BucketName --value "udagram-dev-code" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/AWSManagedPolicyARNForS3 --value "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/AWSManagedPolicyARNForCF --value "arn:aws:iam::aws:policy/AWSCloudFormationReadOnlyAccess" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/AWSManagedPolicyARNForSSMCore --value "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/AWSManagedPolicyARNForCloudWatchAgent --value "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/VpcCIDR --value "10.0.0.0/16" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/PublicSubnet1CIDR --value "10.0.0.0/24" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/PublicSubnet2CIDR --value "10.0.1.0/24" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/PrivateSubnet1CIDR --value "10.0.2.0/24" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/PrivateSubnet2CIDR --value "10.0.3.0/24" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/WebAppImageID --value "$UbuntuImageID" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/WebAppInstancesNumber --value "$WebAppIncNum" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/LinuxSSHKey --value "$SSHKeyName" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/SSHPrivateKey --type SecureString --value "$SSHKeyPair" --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/WebAppInstanceType --value "t3.medium" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/WebAppDiskSize --value "10" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/BastionHostImageID --value "$UbuntuImageID" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/BastionHostInstanceType --value "t2.micro" --type String --overwrite --region $AWSRegion
aws ssm put-parameter --name /Dev/Udagram/BastionHostDiskSize --value "8" --type String --overwrite --region $AWSRegion

#Create environment parameters file which will be used during cleanup
echo $StackName >  ./udagram-dev-variables.txt
echo $AWSRegion >>  ./udagram-dev-variables.txt
echo $SSHKeyName >>  ./udagram-dev-variables.txt

#Create the CloudFormation Stack on the selected Region
CFCreateStackCMD="aws cloudformation create-stack --stack-name $StackName --template-body file://$TemplateFile --capabilities "CAPABILITY_IAM" "CAPABILITY_NAMED_IAM" --region $AWSRegion";
echo ""
/bin/echo -e "\e[1;32mTask5:\e[0m"
echo "Creating Cloud Formation Stack $StackName on AWS Region $AWSRegion...."
eval $CFCreateStackCMD
echo "Creating Cloud Formation Stack $StackName on AWS Region $AWSRegion has been initiated"
echo ""
echo -e "To Monitor stack creation status open another session and run command:\e[1;34m aws cloudformation describe-stacks --stack-name $StackName --region $AWSRegion --query \"Stacks[0].[StackName, StackStatus]\" --output text \e[0m"
#Wait until stack creation completes
aws cloudformation wait  stack-create-complete --stack-name $StackName --region $AWSRegion 
echo -e "Stack Creation has completed. Stack output are:" 
echo ""
aws cloudformation describe-stacks --stack-name $StackName --region $AWSRegion --query Stacks[0].Outputs[*] --output table
echo ""

#List Web Application instances IDs and Private IPs
WebAppAutoSclaingGroupName=$(aws cloudformation describe-stacks --stack-name $StackName --region $AWSRegion --query 'Stacks[0].Outputs[?OutputKey==`WebAppAutoScalingGroup`].[OutputValue]' --output text)
echo $WebAppAutoSclaingGroupName
InstancesIDsArr=( $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $WebAppAutoSclaingGroupName --query [AutoScalingGroups[*].Instances[*].[InstanceId]] --output text) )

for i in "${InstancesIDsArr[@]}"
do
        InstancePrivateIP=`aws ec2 describe-instances --instance-ids $i  --query [Reservations[*].Instances[*].PrivateIpAddress] --output text`
        echo -e "\e[1;34mInstance ID:\e[0m $i"
        echo -e "\e[1;34mInstance Private IP:\e[0m $InstancePrivateIP"
        echo ""
done

/bin/echo -e "\e[1;32mDone\e[0m"
}

#Get the Stack Name from the User
printf "Enter CloudFormation Stack Name to be created on AWS: "
read StackName

#Get Stack Template File Name
printf "Enter CloudFormation Template File Name: "
read TemplateFile

#Get Number of Web Application EC2 instances 
printf "Enter Number of Web Application EC2 instances: "
read WebAppIncNum

#Menu to select the AWS Region on which the environment will be created 
echo ""
echo 'Select AWS Region to create the environment: '
AWSAllowedRegions=("US East (Ohio)" "US East (N. Virginia)" "US West (N. California)" "US West (Oregon)" "Canada (Central)" "Africa (Cape Town)" "Asia Pacific (Hong Kong)"  "China (Beijing)" "Europe (Frankfurt)" "Europe (Ireland)" "Middle East (Bahrain)" "South America (Sao Paulo)" "Quit" )
select UserRegion in "${AWSAllowedRegions[@]}"
do
    case $UserRegion in
        "US East (Ohio)")
                AWSRegion="us-east-2"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "US East (N. Virginia)")
                AWSRegion="us-east-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "US West (N. California)")
                AWSRegion="us-west-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "US West (Oregon)")
                AWSRegion="us-west-2"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Canada (Central)")
                AWSRegion="ca-central-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Africa (Cape Town)")
                AWSRegion="af-south-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Asia Pacific (Hong Kong)")
                AWSRegion="ap-east-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "China (Beijing)")
                AWSRegion="cn-north-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Europe (Frankfurt)")
                AWSRegion="eu-central-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Europe (Ireland)")
                AWSRegion="eu-west-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Middle East (Bahrain)")
                AWSRegion="me-south-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "South America (Sao Paulo)")
                AWSRegion="sa-east-1"
                CreateStack $StackName $TemplateFile $WebAppIncNum $AWSRegion
                break
            ;;
        "Quit")
            break
            ;;
        *) echo "Invalid Region  $REPLY";;
    esac
done
