resource "aws_iam_policy" "cluster_interaction_policy" {
  path        = "/"
  description = "Miggo read-only integration with AWS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "ecs:List*",
          "ecs:Describe*",
          "ecs:Get*",
          "elasticloadbalancing:Describe*",
          "elasticbeanstalk:List*",
          "elasticbeanstalk:Describe*",
          "lambda:List*",
          "lambda:Get*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cluster_interaction_role" {
  name = "ClusterInteractionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::540030267408:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  managed_policy_arns = [aws_iam_policy.cluster_interaction_policy.arn]
  description         = "Miggo read-only role"

  depends_on = [aws_lambda_invocation.pingback]
}

resource "aws_iam_role" "lambda_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "pingback_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "MiggoPingbackLambdaFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda.handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TENANT_ID    = var.tenant_id
      TENANT_EMAIL = var.tenant_email
      WEBHOOK_URL  = var.webhook_url
    }
  }
}

resource "aws_lambda_invocation" "pingback" {
  function_name = aws_lambda_function.pingback_lambda.function_name

  input = jsonencode({
    StackId           = "terraform-stack"
    LogicalResourceId = "PingbackTerraformResource"
  })

  lifecycle_scope = "CRUD"

  depends_on = [aws_lambda_function.pingback_lambda, aws_iam_role.cluster_interaction_role]
}
