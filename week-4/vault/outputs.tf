output "vault_bucket_name" {
  description = "Name of the Object Lock evidence vault bucket."
  value       = aws_s3_bucket.vault.id
}

output "vault_bucket_arn" {
  description = "ARN of the Object Lock evidence vault bucket."
  value       = aws_s3_bucket.vault.arn
}
