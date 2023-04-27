
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}



data "archive_file" "create_obituary_zip" {
  type        = "zip"
  source_dir  = "../functions/create-obituary/packages"
  output_path = "../functions/create-obituary/create_obituary_artifact.zip"
}

data "archive_file" "get_obituaries_zip" {
  type        = "zip"
  source_file = "../functions/get-obituaries/main.py"
  output_path = "../functions/get-obituaries/get_obituaries_artifact.zip"
}


#                         Dynamodb Table                                #
resource "aws_dynamodb_table" "obituaries" {
  name           = "Obituaries-30133072"
  hash_key       = "name"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "name"
    type = "S"
  }
  
}




#                        Secret Parameters                              #
resource "aws_ssm_parameter" "cloudinary_api_key" {
  name  = "/cloudinary/api_key"
  type  = "SecureString"
  value = "238696736182839"
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "cloudinary_api_secret" {
  name  = "/cloudinary/api_secret"
  type  = "SecureString"
  value = "lLi6JKiQ6REIpsjkLZiqqTJ0uBM"
  tags  = local.common_tags
}

resource "aws_ssm_parameter" "chatgpt_api_key" {
  name  = "/chatgpt/api_key"
  type  = "SecureString"
  value = "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"
  tags  = local.common_tags
}

locals {
  common_tags = {
    Terraform   = "true"
    Environment = "dev"
  }

  function_get_obituaries= "get-obituaries-30162797"
  function_create_obituaries  = "create-obituaries-30162797"
  create_handler_name  = "main.create_handler"
  get_handler_name  = "main.get_handler"
  artifact_name = "artifact.zip"
}

#                           Iam Roles                            #


resource "aws_iam_role" "get-lambda" {
  name                = "iam-for-lambda-${local.get_handler_name}"
  assume_role_policy  = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
  }
EOF
}

resource "aws_iam_role" "create-lambda" {
  name                = "iam-for-lambda-${local.create_handler_name}"
  assume_role_policy  = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
  }
EOF
}


resource "aws_iam_policy" "dynamo" {
  name = "obituary_dynamo"
  description = "Interaction with lambda and dynamo"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
				"dynamodb:GetItem",
				"dynamodb:Query",
				"dynamodb:Scan",
				"dynamodb:BatchWriteItem",
				"dynamodb:PutItem",
				"dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ca-central-1:087760734084:table/Obituaries-30133072"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "logs" {
  name        = "obituary-logging"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ssm" {
  name        = "ssm-lambda"
  description = "For accessing ssm parameters"

  policy = <<EOF
{
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        "Resource" : "*"
      }
    ]
  }
  EOF
}
#                  attach the above policy to the function role                     #


resource "aws_iam_role_policy_attachment" "get-lambda_logs" {
  role       = aws_iam_role.get-lambda.name
  policy_arn = aws_iam_policy.logs.arn
}

resource "aws_iam_role_policy_attachment" "create-lambda_logs" {
  role       = aws_iam_role.create-lambda.name
  policy_arn = aws_iam_policy.logs.arn
}

resource "aws_iam_role_policy_attachment" "create-lambda_dynamo" {
  role       = aws_iam_role.create-lambda.name
  policy_arn = aws_iam_policy.dynamo.arn
}

resource "aws_iam_role_policy_attachment" "get-lambda_dynamo" {
  role       = aws_iam_role.get-lambda.name
  policy_arn = aws_iam_policy.dynamo.arn
}

resource "aws_iam_role_policy_attachment" "create-lambda_ssm" {
  role       = aws_iam_role.create-lambda.name
  policy_arn = aws_iam_policy.ssm.arn
}

resource "aws_iam_role_policy_attachment" "create-lambda_polly" {
  role       = aws_iam_role.create-lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPollyFullAccess"
}

#                            Lambda Functions                                       #
resource "aws_lambda_function" "create_obituary" {
  role = aws_iam_role.create-lambda.arn
  function_name = local.function_create_obituaries
  handler = local.create_handler_name
  filename         = data.archive_file.create_obituary_zip.output_path
  source_code_hash = data.archive_file.create_obituary_zip.output_base64sha256
  timeout       = 300
  
  
  runtime       = "python3.9"
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.obituaries.name,
      CLOUDINARY_API_KEY = aws_ssm_parameter.cloudinary_api_key.value,
      CLOUDINARY_API_SECRET = aws_ssm_parameter.cloudinary_api_secret.value,
      CHATGPT_API_KEY = aws_ssm_parameter.chatgpt_api_key.value
    }
  }
}

resource "aws_lambda_function" "get_obituaries" {
  role = aws_iam_role.get-lambda.arn
  function_name = local.function_get_obituaries
  handler = local.get_handler_name
  filename         = data.archive_file.get_obituaries_zip.output_path
  source_code_hash = data.archive_file.get_obituaries_zip.output_base64sha256
  
  
  runtime       = "python3.9"
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.obituaries.name
    }
  }
}


#                                      Lambda function URL                                        #


resource "aws_lambda_function_url" "create_obituary_url" {
  function_name      = aws_lambda_function.create_obituary.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST", "PUT"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

resource "aws_lambda_function_url" "get_obituaries_url" {
  function_name      = aws_lambda_function.get_obituaries.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["*"]
    expose_headers    = ["keep-alive", "date"]
  }
}

output "create_obituary_api_url" {
  value = aws_lambda_function_url.create_obituary_url.function_url
}

output "get_obituaries_api_url" {
  value = aws_lambda_function_url.get_obituaries_url.function_url
}