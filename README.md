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

In Terraform, that looks something like this:

```terraform

resource "aws_iam_role" "ecs_task_role" {
  name = "asdfservice-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_role_assume_policy.json
}

data "aws_iam_policy_document" "ecs_task_role_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com",]
    }
  }
}

data "aws_iam_policy_document" "route53policy" {
  statement {
    effect  = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces", 
      "ecs:DescribeTasks"
    ]
    resources = [ "*" ]
  }

  statement {
    effect  = "Allow"
    actions = [ "route53:ChangeResourceRecordSets" ]
    resources = [ "arn:aws:route53:::hostedzone/${var.prod_zone.zone_id}" ]
  }
}

resource "aws_iam_policy" "ecs_task_role_policy" {
  name   = "asdfservice-task-role-policy"
  policy = data.aws_iam_policy_document.route53policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.id
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}

## finally, the task definition itself

resource "aws_ecs_task_definition" "asdfservice" {
  ...
  task_role_arn = aws_iam_role.ecs_task_role.arn
  ...
}

```

### Environment variables

In your container definition, make sure to set:

* `$R53_HOST` to the hostname you want for the container
* `$R53_ZONEID` to the zone you want to put that hostname in

Your container definition template might look something like this:

```json
    {
        "essential": true,
        "memory": 100,
        "name": "dynroute53n",
        "cpu": 256,
        "image": "alloverse/dynroute53n:latest",
        "environment": [
            { "name": "R53_HOST", "value": "${shortname}.places.alloverse.com" },
            { "name": "R53_ZONEID", "value": "${zoneid}" }
        ],
        "requiresCompatibilities": [
            "FARGATE"
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "asdfservice",
                "awslogs-region": "eu-north-1",
                "awslogs-stream-prefix": "dynroute53n-${shortname}"
            }
        }
    }
```