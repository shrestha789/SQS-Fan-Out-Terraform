variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "input_bucket_name" {
  description = "Base name for the input S3 bucket"
  type        = string
  default     = "image-input-bucket"
}

variable "output_bucket_name" {
  description = "Base name for the output S3 bucket"
  type        = string
  default     = "image-output-bucket"
}

variable "sns_topic_name" {
  description = "Name for the SNS topic"
  type        = string
  default     = "image-upload-topic"
}

variable "sqs_queue_name" {
  description = "Name for the SQS queue"
  type        = string
  default     = "image-processing-queue"
}

variable "lambda_function_name" {
  description = "Name for the Lambda function"
  type        = string
  default     = "image_processor"
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
  default     = "python3.8"
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 30
}

variable "lambda_handler" {
  description = "Handler for the Lambda function"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_filename" {
  description = "Filename of the Lambda deployment package"
  type        = string
  default     = "lambda_function.zip"
}