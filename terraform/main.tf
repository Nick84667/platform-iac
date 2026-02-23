locals {
  name   = "eks-lab"
  region = "eu-central-1"

  # For simplicity and reduced costs I use 2 AZ
  azs = ["eu-central-1a", "eu-central-1b"]

  tags = {
    Project = local.name
    Owner   = "Nick84667"
  }
}

# ----------------------------
# VPC (only public subnet, NO NAT Gateway)
# ----------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = "10.10.0.0/16"

  azs            = local.azs
  public_subnets = ["10.10.0.0/24", "10.10.1.0/24"]

  # Cost-saving: no NAT Gateway 
  enable_nat_gateway = false
  single_nat_gateway = false

  tags = local.tags

  # Tags required for Load Balancers on EKS (ALB on Ingress)
  public_subnet_tags = {
    "kubernetes.io/role/elb"               = "1"
    "kubernetes.io/cluster/${local.name}"  = "shared"
  }
}

# ----------------------------
# ECR repository (bingo-socket) + lifecycle policy
# ----------------------------
resource "aws_ecr_repository" "bingo" {
  name = "bingo-socket"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "bingo" {
  repository = aws_ecr_repository.bingo.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ----------------------------
# EKS (public endpoint) + managed node group 3x t3.medium
# ----------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = "1.29"

  # Cluster public endpoint  
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 3
      min_size       = 3
      max_size       = 3
    }
  }

  tags = local.tags
}

# ----------------------------
# Outputs utility
# ----------------------------
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repo_url" {
  value = aws_ecr_repository.bingo.repository_url
}
