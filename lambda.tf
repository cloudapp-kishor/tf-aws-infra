# Lambda Function for Email Verification
resource "aws_lambda_function" "email_verification" {
  function_name = "${var.vpc_name}-email-verification"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "serverless-forked/index.handler"
  runtime       = "nodejs18.x"
  timeout       = 120

  # Assuming Lambda code is in a zip file named `lambda_email_verification.zip`
  filename         = "${path.module}/serverless-forked.zip"
  source_code_hash = filebase64sha256("${path.module}/serverless-forked.zip")

  environment {
    variables = {
      SENDGRID_API_KEY = var.sendgrid_api_key
      SNS_TOPIC_ARN    = aws_sns_topic.user_registration_topic.arn
    }
  }
}


# Grant SNS permission to invoke Lambda
resource "aws_lambda_permission" "allow_sns_invoke_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_verification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_registration_topic.arn
}