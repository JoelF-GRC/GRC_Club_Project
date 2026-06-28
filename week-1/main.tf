terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region

  # TODO (CM-6): add a default_tags block so every taggable resource carries
  # Project, Environment, ManagedBy, and ComplianceScope automatically.
  # CM-6 Four required tags on every taggable resource: Project, Environment, ManagedBy, ComplianceScope.
  default_tags {
    tags = {
      Project         = var.project_name
      Environment     = var.environment
      ManagedBy       = "terraform"
      ComplianceScope = "NIST-800-53"
    }
  }

}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  primary_name = "${var.project_name}-${var.environment}-data-${random_id.suffix.hex}"
  log_name     = "${var.project_name}-${var.environment}-logs-${random_id.suffix.hex}"
}

# The two base buckets are here so the skeleton validates. The controls are yours.
resource "aws_s3_bucket" "primary" {
  bucket = local.primary_name
}

resource "aws_s3_bucket" "log" {
  bucket = local.log_name
}

#   SC-28   protection of information at rest. Server-side encryption with AES-256
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# SC-28: encryption on the log bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CM-6  turn on versioning
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# AC-3 block public access on the primary bucket
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id
  
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
# AC-3: public access block on the log bucket
resource "aws_s3_bucket_public_access_block" "log" {
  bucket = aws_s3_bucket.log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


#   AU-3  ownership controls on the log bucket
resource "aws_s3_bucket_ownership_controls" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  }  

#  AU-3 allow S3 log delivery to write to log bucket
resource "aws_s3_bucket_acl" "log" {
  bucket = aws_s3_bucket.log.id
  acl = "log-delivery-write"

  depends_on = [ aws_s3_bucket_ownership_controls.log ]
}

# AU-3 point the primary bucket's access logs at the log bucket
resource "aws_s3_bucket_logging" "primary" {
  bucket = aws_s3_bucket.primary.id
  target_bucket = aws_s3_bucket.log.id
  target_prefix = "access-logs/"
}

# ---------------------------------------------------------------------------
# YOUR BUILD: add the controls. Each is one or more resources you write.
#
#   SC-28  encrypt the primary bucket at rest, and the log bucket too.
#   CM-6   turn on versioning for the primary bucket.
#   AC-3   block public access on both buckets. All four flags must be true.
#   AU-3   let the log bucket receive access logs (ownership controls, then a
#          log-delivery-write ACL), and point the primary bucket's logging at it.
#
# Look up the AWS provider resource names in the Terraform registry. The full
# brief on Patreon explains what each control is and how to verify it.
# ---------------------------------------------------------------------------
