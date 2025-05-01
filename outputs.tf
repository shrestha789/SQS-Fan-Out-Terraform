# outputs.tf (complete version)
output "input_bucket_name" {
  description = "Name of the input S3 bucket"
  value       = aws_s3_bucket.input_bucket.id
}

output "output_bucket_name" {
  description = "Name of the output S3 bucket"
  value       = aws_s3_bucket.output_bucket.id
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.image_processor.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.image_upload_topic.arn
}