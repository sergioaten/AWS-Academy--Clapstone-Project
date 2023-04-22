data "aws_vpcs" "vpc" {
    tags = {
        Name = "Example VPC"
    }
}

data "aws_subnets" "private_subnet" {
    filter {
        name   = "tag:Name"
        values = ["Private*"]
    }
}

data "aws_subnets" "public_subnet" {
    filter {
        name   = "tag:Name"
        values = ["Public*"]
    }
}

data "aws_security_groups" "db_sg" {
    filter {
        name   = "group-name"
        values = ["Example-DB"]
    }
}

data "aws_security_groups" "lb_sg" {
    filter {
        name   = "group-name"
        values = ["ALBSG"]
    }
}

data "aws_security_groups" "app_sg" {
    filter {
        name   = "group-name"
        values = ["Inventory-*"]
    }
}

data "aws_security_groups" "bastion_sg" {
    filter {
        name   = "group-name"
        values = ["Bastion-*"]
    }
}

data "aws_instance" "bastion_host" {
    filter {
        name   = "tag:Name"
        values = ["Bastion"]
    }
    
    filter {
        name    = "instance-state-name"
        values   = ["running"]
    }
}

resource "time_sleep" "sixty_seconds" {
    create_duration = "60s"

    depends_on = [
        aws_autoscaling_group.asg
    ]
}

data "aws_instances" "client_host" {
    filter {
        name   = "tag:Name"
        values = ["ExampleAPP"]
    }
    depends_on = [
        time_sleep.sixty_seconds
    ]
}

data "aws_launch_template" "lt" {
    filter {
        name   = "launch-template-name"
        values = ["Example*"]
    }
}

data "aws_route_tables" "private" {
    vpc_id   = element(tolist(data.aws_vpcs.vpc.ids), 0)

    filter {
        name   = "tag:Name"
        values = ["Private*"]
    }
}