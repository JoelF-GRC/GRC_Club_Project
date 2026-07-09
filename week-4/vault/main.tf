terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region

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
  vault_name = "${var.project_name}-${var.environment}-evidence-vault-${random_id.suffix.hex}"
}

# Object Lock must be turned on when the bucket is created. There is no way
# to enable it on an existing bucket, which is why this is a separate,
# throwaway bucket rather than reusing anything from week 1.
resource "aws_s3_bucket" "vault" {
  bucket              = local.vault_name
  object_lock_enabled = true
}

# Object Lock requires versioning; retention is enforced per object version.
resource "aws_s3_bucket_versioning" "vault" {
  bucket = aws_s3_bucket.vault.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SC-28: encrypt evidence bundles at rest, same as week 1's buckets.
resource "aws_s3_bucket_server_side_encryption_configuration" "vault" {
  bucket = aws_s3_bucket.vault.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# AC-3: this bucket holds evidence, never a public artifact.
resource "aws_s3_bucket_public_access_block" "vault" {
  bucket = aws_s3_bucket.vault.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# GOVERNANCE mode, not COMPLIANCE. COMPLIANCE-mode retention cannot be
# shortened or bypassed by anyone, including the account root, until the
# retention window ends. GOVERNANCE still blocks casual overwrite or delete,
# but a caller holding s3:BypassGovernanceRetention can remove an object
# early. Chosen specifically so this vault can be demonstrated and torn down
# the same day, per the week 4 brief.
resource "aws_s3_bucket_object_lock_configuration" "vault" {
  bucket = aws_s3_bucket.vault.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.vault]
}
