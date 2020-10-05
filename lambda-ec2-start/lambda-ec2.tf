provider "aws" {
  profile = "default"
  region = "ca-central-1"
}

# IAM-Section

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "iam_for_lambda_start" {
  name               = "iam_for_lambda_start"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda_start.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


data "aws_iam_policy_document" "lambda-ec2" {
  statement {
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = [
        "arn:aws:logs:*:*:*",
      ]
    }

  statement {
      actions = [
        "ec2:Describe*",
        "ec2:Stop*",
        "ec2:Start*"
      ]
      resources = [
          "*",
      ]
    }
}

resource "aws_iam_policy" "lambda-ec2" {
  name   = "lambda_ec2_policy_start"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda-ec2.json
}

resource "aws_iam_policy_attachment" "ec2-attachment" {
  name       = "ec2-attachment"
  roles      = [aws_iam_role.iam_for_lambda_start.name]
  policy_arn = aws_iam_policy.lambda-ec2.arn
}


#lambda-ec2

resource "aws_lambda_function" "lambda-ec2-start" {
  description   = "lambda-to-start-ec2"
  filename      = "lambda_ec2_start.zip"
  function_name = "lambda_ec2_start"
  role          = aws_iam_role.iam_for_lambda_start.arn
  handler       = "lambda_ec2_start.lambda_handler"
  runtime = "python3.8"
  timeout       = 60

  source_code_hash = filebase64sha256("lambda_ec2_start.zip")


}

#Cloudwatch-lambda


resource "aws_cloudwatch_event_rule" "start_instances_event_rule" {
  name = "start_instances_event_rule"
  description = "starts stopped EC2 instances"
  schedule_expression = "cron(0 20 ? * * *)"
  depends_on = [aws_lambda_function.lambda-ec2-start]
}

resource "aws_cloudwatch_event_target" "start_instances_event_target" {
  target_id = "start_instances_lambda_target"
  rule = aws_cloudwatch_event_rule.start_instances_event_rule.name
  arn = aws_lambda_function.lambda-ec2-start.arn
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-ec2-start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances_event_rule.arn
}