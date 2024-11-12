# Security group for Aurora to allow access from ECS
resource "aws_security_group" "aurora_sg" {
  name        = "aurora-sg"
  description = "Allow ECS tasks to access Aurora PostgreSQL"
  vpc_id      = aws_vpc.craftcms_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.craftcms_sg.id]  # Allow access from ECS tasks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "aurora_subnet_group" {
    name       = "aurora-subnet-group"
    subnet_ids = aws_subnet.public_subnet[*].id  # Use the same subnets as ECS
    description = "Subnet group for Aurora PostgreSQL"
  }
  

# Create an Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "aurora_postgres_cluster" {
  cluster_identifier      = "craftcms-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "16.3"  # Adjust to desired version
  database_name           = "craftcms_db"
  master_username         = "craftcmspoc"
  master_password         = "intact1234!"
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  skip_final_snapshot     = true
  storage_encrypted       = true
  db_subnet_group_name    = aws_db_subnet_group.aurora_subnet_group.name
}

# Create an Aurora Cluster Instance
resource "aws_rds_cluster_instance" "aurora_postgres_instance" {
  identifier          = "craftcms-aurora-instance-1"
  cluster_identifier  = aws_rds_cluster.aurora_postgres_cluster.id
  instance_class      = "db.r5.large"  # Adjust based on performance requirements
  engine              = aws_rds_cluster.aurora_postgres_cluster.engine
  publicly_accessible = false
}

output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.aurora_postgres_cluster.endpoint
}
