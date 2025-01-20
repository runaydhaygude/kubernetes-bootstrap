resource "aws_s3_bucket" "kops-state-store" {
  provider = aws.mumbai
  bucket = "${random_string.random.result}-kops-state-store"
}


resource "aws_s3_bucket_public_access_block" "kops-state-store" {
  provider = aws.mumbai
  bucket = aws_s3_bucket.kops-state-store.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "kops-state-store" {
  provider = aws.mumbai
    bucket = aws_s3_bucket.kops-state-store.id
    rule {
        object_ownership = "BucketOwnerPreferred"
    }
}

resource "aws_s3_bucket_acl" "kops-state-store" {
  provider = aws.mumbai
  bucket = aws_s3_bucket.kops-state-store.id
  acl = "public-read"

  depends_on = [ 
    aws_s3_bucket_public_access_block.kops-state-store,
    aws_s3_bucket_ownership_controls.kops-state-store
  ]   
}

output "s3-bucket" {
    value = aws_s3_bucket.kops-state-store.id
}