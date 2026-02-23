terraform {
  backend "s3" {
    bucket         = "tfstate-eks-lab-nick84667-eu-central-1"
    key            = "eks-lab/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks-eks-lab"
    encrypt        = true
  }
}
