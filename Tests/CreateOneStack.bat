set commonCFparms=--disable-rollback --capabilities CAPABILITY_IAM --template-url https://s3-ap-southeast-2.amazonaws.com/lansa/templates/support/L4W14100_scalable/lansa-win-custom.cfn.template --parameters ParameterKey=04DBPassword,ParameterValue=Pcxuser122 ParameterKey=06WebPassword,ParameterValue=Pcxuser@122rob ParameterKey=07KeyName,ParameterValue=RobG_id_rsa ParameterKey=08RemoteAccessLocation,ParameterValue=103.231.169.65/32
call aws --region ap-southeast-2  cloudformation create-stack --stack-name Sydney %commonCFparms%