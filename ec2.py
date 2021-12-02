import boto3
client = boto3.client('ec2', 'us-east-1')

results = []
token = None

#Fecthing default VPCid by doing describe call
response = client.describe_vpcs(
        Filters=[
            {
                'Name': 'is-default',
                'Values': [
                    'true'
                ]
            },
        ]
    )
for vpcid in response['Vpcs']:
    vpcid = str(vpcid['VpcId'])        

#fetching instance name and id based on instance type and default vpc that is being passed from above api call        
while True:
    if token:
        kwargs = {'NextPageToken': token}
    else:
        kwargs = {}
        
    data = client.describe_instances(
        Filters=[
            {
                'Name': 'instance-type',
                'Values': [
                    'm5.large'
                ]
            },
            {
                'Name': 'vpc-id',
                'Values': [
                    vpcid
                ]
            }
        ]
    )
    
    results += data['Reservations']

    token = data.get('NextPageToken')
    if not token:
        break

for result in results:
    for group in result['Instances']:
         instanceid = group['InstanceId']
         #print(instanceid)
         for tags in group['Tags']:
             if tags['Key'] == "Name":
                 #name = (tags['Value'] + ".usw2.aws.example.com")
                 name = (tags['Value'])
                 print(name, instanceid)
         



