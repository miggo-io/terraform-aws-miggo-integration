resource "aws_iam_policy" "cluster_interaction_policy" {
  path        = "/"
  description = "Miggo read-only integration with AWS"
  tags        = var.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MiggoReadOnly"
        Effect = "Allow"
        Action = [
          "organizations:DescribeAccount",
          "ec2:DescribeRegions",

          # Elastic Beanstalk inventory. DescribeConfigurationSettings is left out: it returns environment option values.
          "elasticbeanstalk:List*",
          "elasticbeanstalk:DescribeAccountAttributes",
          "elasticbeanstalk:DescribeApplicationVersions",
          "elasticbeanstalk:DescribeApplications",
          "elasticbeanstalk:DescribeConfigurationOptions",
          "elasticbeanstalk:DescribeEnvironmentHealth",
          "elasticbeanstalk:DescribeEnvironmentManagedActionHistory",
          "elasticbeanstalk:DescribeEnvironmentManagedActions",
          "elasticbeanstalk:DescribeEnvironmentResources",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:DescribeEvents",
          "elasticbeanstalk:DescribeInstancesHealth",
          "elasticbeanstalk:DescribePlatformVersion",

          # DNS enrichment: hosted zones and records behind domain and internet-facing discovery.
          "route53:List*",
          "route53:Get*",

          # WAF coverage: Web ACLs, what each protects (one action per attachment type), and per-rule traffic.
          "waf:List*",
          "waf:Get*",
          "wafv2:List*",
          "wafv2:Get*",
          "wafv2:Describe*",
          "wafv2:CheckCapacity",
          "elasticloadbalancing:Describe*",
          "appsync:ListResourcesForWebACL",
          "cognito-idp:ListResourcesForWebACL",
          "apprunner:ListAssociatedServicesForWebAcl",
          "ec2:DescribeVerifiedAccessInstanceWebAclAssociations",
          "bedrock-agentcore:GatewayListResourcesForWebACL",
          "amplify:ListResourcesForWebACL",
          "cloudfront:List*",
          "cloudfront:Get*",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",

          # WAF logs: these two actions don't support resource scoping.
          "logs:DescribeLogGroups",
          "logs:StopQuery",

          "fms:List*",
          "fms:Get*",
          "shield:Describe*",
          "shield:Get*",
          "shield:List*"
        ]
        Resource = "*"
      },
      {
        # API and custom-domain listings only. Keys, stage variables and integrations stay unreadable.
        Sid    = "ApiGatewayInventory"
        Effect = "Allow"
        Action = "apigateway:GET"
        Resource = [
          "arn:aws:apigateway:*::/restapis",
          "arn:aws:apigateway:*::/apis",
          "arn:aws:apigateway:*::/apis/*/routes",
          "arn:aws:apigateway:*::/domainnames",
          "arn:aws:apigateway:*::/domainnames/*"
        ]
      },
      {
        # WAF only writes to log groups, buckets and streams named aws-waf-logs-*.
        Sid    = "WafLogsCloudWatch"
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:DescribeLogStreams",
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = "arn:aws:logs:*:*:log-group:aws-waf-logs-*"
      },
      {
        Sid      = "WafLogsS3Buckets"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::aws-waf-logs-*"
      },
      {
        Sid      = "WafLogsS3Objects"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::aws-waf-logs-*/*AWSLogs/*/WAFLogs/*"
      },
      {
        # SSE-KMS encrypted WAF log objects, decrypted only through S3 for those buckets.
        Sid      = "WafLogsS3Decrypt"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService"                   = "s3.*.amazonaws.com"
            "kms:EncryptionContext:aws:s3:arn" = "arn:aws:s3:::aws-waf-logs-*"
          }
        }
      },
      {
        Sid      = "WafLogsFirehoseDiscovery"
        Effect   = "Allow"
        Action   = "firehose:DescribeDeliveryStream"
        Resource = "arn:aws:firehose:*:*:deliverystream/aws-waf-logs-*"
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
  tags                = var.tags
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
  tags = var.tags
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
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.pingback_lambda.function_name}",
          "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.pingback_lambda.function_name}:*"
        ]
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
  runtime          = "python3.12"
  timeout          = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TENANT_ID    = var.tenant_id
      PROJECT_ID   = var.project_id
      TENANT_EMAIL = var.tenant_email
      WEBHOOK_URL  = var.webhook_url
    }
  }

  tags = var.tags
}

resource "aws_lambda_invocation" "pingback" {
  function_name = aws_lambda_function.pingback_lambda.function_name

  triggers = {
    tenant_id    = var.tenant_id
    tenant_email = var.tenant_email
    webhook_url  = var.webhook_url
    project_id   = var.project_id
  }

  input = jsonencode({
    StackId           = "terraform-stack"
    LogicalResourceId = "PingbackTerraformResource"
  })

  lifecycle_scope = "CRUD"

  depends_on = [aws_lambda_function.pingback_lambda, aws_iam_role.cluster_interaction_role, aws_iam_role_policy.lambda_policy]
}
