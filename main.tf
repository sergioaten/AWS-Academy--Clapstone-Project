terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.60.0"
        }
        ssh = {
            source = "loafoe/ssh"
            version = "2.6.0"
        }
    }
}

provider "aws" {}

resource "aws_eip" "eip" {
    network_border_group    = "us-east-1"
}

resource "aws_nat_gateway" "nat_gw" {
    allocation_id       = aws_eip.eip.id
    connectivity_type   = "public"
    subnet_id           = element(tolist(data.aws_subnets.public_subnet.ids), 0)
}

resource "aws_route" "r" {
    route_table_id            = element(tolist(data.aws_route_tables.private.ids), 0)
    destination_cidr_block    = "0.0.0.0/0"
    nat_gateway_id            = aws_nat_gateway.nat_gw.id
}

resource "aws_db_subnet_group" "db_subnet_group" {
    name            = "mysql-subnetgroup"
    subnet_ids      = data.aws_subnets.private_subnet.ids

    tags = {
        Name = "My DB subnet group"
    }
}

resource "aws_db_instance" "mysql_db" {
    identifier              = "mysql-db"
    allocated_storage       = 10
    db_name                 = "mydb"
    engine                  = "mysql"
    engine_version          = "8.0.32"
    instance_class          = "db.t3.small"
    username                = "admin"
    password                = "admin123"
    skip_final_snapshot     = true
    db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
    vpc_security_group_ids  = data.aws_security_groups.db_sg.ids
    availability_zone       = "us-east-1a"
}

resource "aws_ssm_parameter" "db_parameters" {
    count = length(local.ssm_ps)
    name  = local.ssm_ps[count.index].name
    type  = "String"
    value = local.ssm_ps[count.index].value_dbinstance
}

resource "aws_security_group_rule" "ssh" {
    type                        = "ingress"
    protocol                    = "TCP"
    from_port                   = 22
    to_port                     = 22
    source_security_group_id    = element(tolist(data.aws_security_groups.bastion_sg.ids), 0)
    security_group_id           = element(tolist(data.aws_security_groups.app_sg.ids), 0)
}

resource "ssh_resource" "ssh_agent" {
    when = "create"

    host         = element(tolist(data.aws_instances.client_host.private_ips), 0)
    bastion_host = data.aws_instance.bastion_host.public_ip
    user         = "ec2-user"

    private_key         = file(".ssh/bastionssh.pem")
    bastion_private_key = file(".ssh/bastionssh.pem")

    timeout     = "15m"
    retry_delay = "5s"

    commands = [
        "cd ~",
        format("mysql --host=%s --user=admin --password=admin123 mydb < Countrydatadump.sql",aws_db_instance.mysql_db.address)
    ]

    depends_on = [
        aws_db_instance.mysql_db,
        aws_security_group_rule.ssh
    ]
}

resource "aws_lb" "lb" {
    name               = "lb-webapp"
    internal           = false
    load_balancer_type = "application"
    security_groups    = data.aws_security_groups.lb_sg.ids
    subnets            = data.aws_subnets.public_subnet.ids
}

resource "aws_lb_target_group" "lb_tg" {
    name     = format("%s-tg",aws_lb.lb.name)
    port     = 80
    protocol = "HTTP"
    vpc_id   = element(tolist(data.aws_vpcs.vpc.ids), 0)
}

resource "aws_lb_listener" "lb_listener_http" {
    load_balancer_arn = aws_lb.lb.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.lb_tg.arn
    }
}

resource "aws_autoscaling_group" "asg" {
    name                        = "asg"
    desired_capacity            = 2
    min_size                    = 2
    max_size                    = 4
    vpc_zone_identifier         = data.aws_subnets.private_subnet.ids
    health_check_grace_period   = 90
    health_check_type           = "ELB"
    target_group_arns           = [aws_lb_target_group.lb_tg.arn]
    wait_for_capacity_timeout   = 0

    launch_template {
        id      = data.aws_launch_template.lt.id
        version = "$Latest"
    }
}

# resource "aws_autoscaling_policy" "asg_policy" {
#     name                    = format("%s-policy",aws_autoscaling_group.asg.name)
#     policy_type             = "TargetTrackingScaling"
#     cooldown                = 20
#     autoscaling_group_name  = aws_autoscaling_group.asg.name

#     target_tracking_configuration {
#         predefined_metric_specification {
#             predefined_metric_type = "ASGAverageCPUUtilization"
#         }
#         target_value = 25
#     }
# }

output "public_dns_lb" {
    value = aws_lb.lb.dns_name
}