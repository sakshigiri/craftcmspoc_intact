resource "aws_ecs_task_definition" "craftcms_task" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "craftcms"
      image     = "craftcms/php-fpm:7.4"
      cpu       = var.task_cpu
      memory    = var.task_memory
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
      environment = [
        { name = "DB_DRIVER", value = "pgsql" },
        { name = "DB_SERVER", value = aws_rds_cluster.aurora_postgres_cluster.endpoint },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_DATABASE", value = "craftcms_db" },
        { name = "DB_USER", value = "craftcmspoc" },
        { name = "DB_PASSWORD", value = "intact1234!" }
      ]
    }
  ])
}
