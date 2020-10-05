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

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
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
  name   = "lambda_ec2_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda-ec2.json
}

resource "aws_iam_policy_attachment" "ec2-attachment" {
  name       = "ec2-attachment"
  roles      = [aws_iam_role.iam_for_lambda.name]
  policy_arn = aws_iam_policy.lambda-ec2.arn
}


#lambda-ec2

resource "aws_lambda_function" "lambda_ec2_stop" {
  description   = "lambda-to-stop-ec2"
  filename      = "lambda_ec2_stop.zip"
  function_name = "lambda_ec2_stop"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_ec2_stop.lambda_handler"
  runtime = "python3.8"
  timeout       = 60

  source_code_hash = filebase64sha256("lambda_ec2_stop.zip")


}

#Cloudwatch-lambda


resource "aws_cloudwatch_event_rule" "stop_instances_event_rule" {
  name = "stop_instances_event_rule"
  description = "Stops running EC2 instances"
  schedule_expression = "cron(0 20 ? * * *)"
  depends_on = [aws_lambda_function.lambda_ec2_stop]
}

resource "aws_cloudwatch_event_target" "stop_instances_event_target" {
  target_id = "stop_instances_lambda_target"
  rule = aws_cloudwatch_event_rule.stop_instances_event_rule.name
  arn = aws_lambda_function.lambda_ec2_stop.arn
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_ec2_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances_event_rule.arn
}