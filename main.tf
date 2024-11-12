resource "aws_vpc" "craftcms_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.craftcms_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.craftcms_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.craftcms_vpc.id
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.craftcms_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_ecs_cluster" "craftcms_cluster" {
  name = var.cluster_name
}

# Security Group for the ECS Tasks
resource "aws_security_group" "craftcms_sg" {
  name        = "craftcms-sg"
  vpc_id      = aws_vpc.craftcms_vpc.id
  description = "Allow HTTP inbound traffic from the load balancer"

  # Allow inbound traffic on port 80 from the load balancer
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for the Load Balancer
resource "aws_security_group" "load_balancer_sg" {
  name        = "craftcms-lb-sg"
  vpc_id      = aws_vpc.craftcms_vpc.id
  description = "Allow HTTP traffic to the load balancer"

  # Allow inbound traffic on port 80 from any IP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow inbound SSH traffic on port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Replace "0.0.0.0/0" with a more restricted IP range if possible
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ecs_inbound_from_lb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.craftcms_sg.id  # ECS task security group
  source_security_group_id = aws_security_group.load_balancer_sg.id  # Load balancer security group
}


# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Access to CloudWatchLogsFullAccess
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_logs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/craftcms"
  retention_in_days = 7  # Optional: set retention period for log data
}

resource "aws_ecs_service" "craftcms_service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.craftcms_cluster.id
  task_definition = aws_ecs_task_definition.craftcms_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  depends_on = [aws_lb.craftcms_lb, aws_lb_listener.craftcms_listener, aws_lb_target_group.craftcms_target_group]
  network_configuration {
    assign_public_ip = true
    subnets         = aws_subnet.public_subnet[*].id
    security_groups = [aws_security_group.craftcms_sg.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.craftcms_target_group.arn
    container_name   = "craftcms"
    container_port   = var.container_port
  }
}

resource "aws_lb" "craftcms_lb" {
  name               = "craftcms-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = aws_subnet.public_subnet[*].id
}

resource "aws_lb_target_group" "craftcms_target_group" {
  name     = "craftcms-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.craftcms_vpc.id
  target_type = "ip"

  health_check {
    path                = "/index.php"          # Use the correct path that returns a 200 OK response
    protocol            = "HTTP"
    interval            = 30           # Health check interval in seconds
    timeout             = 5            # Health check timeout in seconds
    healthy_threshold   = 2            # Number of successes required to be marked healthy
    unhealthy_threshold = 2            # Number of failures before marked unhealthy
  }
}

resource "aws_lb_listener" "craftcms_listener" {
  load_balancer_arn = aws_lb.craftcms_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.craftcms_target_group.arn
  }
}
