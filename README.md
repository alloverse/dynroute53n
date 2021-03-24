# Updating Route53 record with the public IP of an ECS Fargate task/container

So you've deployed a container on AWS ECS+Fargate with a public IP,
and now you want to automatically update a Route53 record to point to
it so you can actually use it. Maybe you're using Terraform, and you
found that `aws_ecs_service` doesn't expose a "public IP" attribute,
because it's only known at runtime (and you might have instance
count > 1).

Well. I found a bunch of different solutions. Here are a few of them:

* https://itnext.io/getting-a-persistant-address-to-a-ecs-fargate-container-3df5689f6e56
* https://medium.com/@andreas.pasch/automatic-public-dns-for-fargate-managed-containers-in-amazon-ecs-f0ca0a0334b5
* https://medium.com/galvanize/static-ip-applications-on-aws-ecs-c7d411421d4f

The first one seems the easiest, but I don't want to modify my container.
Then I noticed in a SO answer that multiple containers in the same task
will run on the same host, so I realized: I could make a container that runs
alongside my main app, whose only purpose is to update Route53.

The script is mostly a copy-paste of Andreas Pasch's script.

## Configuring Terraform

### Permissions

Your ECS Service needs these IAM permissions:

* `ec2:DescribeNetworkInterfaces`
* `ecs:DescribeTasks`
* `route53:ChangeResourceRecordSets`

Luckilly, all of these are included in the [default service-linked IAM 
role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using-service-linked-roles.html).

### Environment variables

In your container description, make sure to set:

* `$R53_HOST` to the hostname you want for the container
* `$R53_ZONEID` to the zone you want to put that hostname in