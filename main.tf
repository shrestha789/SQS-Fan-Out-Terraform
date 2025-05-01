provider "aws" {
  region = var.region
}

# Generate random suffix for bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# S3 Buckets
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "${var.input_bucket_name}-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket" "output_bucket" {
  bucket        = "${var.output_bucket_name}-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

# SNS Topic
resource "aws_sns_topic" "image_upload_topic" {
  name = var.sns_topic_name
}

# SQS Queue
resource "aws_sqs_queue" "image_processing_queue" {
  name                      = var.sqs_queue_name
  visibility_timeout_seconds = 60  # Must exceed Lambda timeout
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Permissions for Lambda image processing"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = [
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.image_processing_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function (using deployment package from Cloud9)
resource "aws_lambda_function" "image_processor" {
  filename      = "lambda_python_thumbnail_deployment_package.zip" # Created in Cloud9
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"  # Must match Cloud9 Python version
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.id
    }
  }
}

# S3 → SNS Notification
resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.image_upload_topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "s3.amazonaws.com" },
      Action    = "sns:Publish",
      Resource  = aws_sns_topic.image_upload_topic.arn,
      Condition = {
        ArnLike = { "aws:SourceArn" = aws_s3_bucket.input_bucket.arn }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  topic {
    topic_arn = aws_sns_topic.image_upload_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.sns_topic_policy]
}

# SNS → SQS Subscription
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.image_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = "*",
      Action    = "sqs:SendMessage",
      Resource  = aws_sqs_queue.image_processing_queue.arn,
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.image_upload_topic.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.image_upload_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.image_processing_queue.arn
}

# SQS → Lambda Trigger
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_processing_queue.arn
  function_name    = aws_lambda_function.image_processor.arn
  batch_size       = 1
}