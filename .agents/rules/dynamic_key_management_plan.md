# Implementation Plan: Serverless Key Manager

Now that we have locked in the architecture (Option 3 with standard Cognito Authentication), we are ready to build the Serverless Web App. Because this is a major addition to your AWS infrastructure, I propose we build it in three distinct phases to ensure everything works perfectly.

## User Review Required

> [!IMPORTANT]  
> This is a massive architectural addition. Review the phases below. If you approve, I will immediately begin executing **Phase 1**.

## Phase 1: AWS Serverless Infrastructure (Terraform)
We will expand our Terraform module to provision the backend services.
- **[NEW] `dynamodb.tf`**: Create the `vpn-clients` DynamoDB table (Partition Key: `PublicKey`).
- **[NEW] `cognito.tf`**: Create an isolated Amazon Cognito User Pool to store your admin credentials securely.
- **[NEW] `lambda.tf`**: Create an AWS Lambda function (Node.js) that will handle the key generation logic and save the public keys to DynamoDB.
- **[NEW] `apigateway.tf`**: Create an HTTP API Gateway to route requests to the Lambda function, secured by a Cognito JWT Authorizer.
- **[NEW] `s3.tf` & `cloudfront.tf`**: Create the S3 bucket to hold our static Web App files, and attach a CloudFront CDN to provide a secure HTTPS URL for your phone.

## Phase 2: EC2 Synchronization
We must update the EC2 server to watch the new DynamoDB table.
- **[MODIFY] `security.tf`**: Grant the EC2 instance's IAM role permission to run `dynamodb:Scan` on the new table.
- **[MODIFY] `userdata.sh`**: Add a lightweight Bash script and a Cron job that runs every 1 minute. The script will pull the latest public keys from DynamoDB, append them to `wg0.conf`, and reload the WireGuard interface dynamically without dropping existing connections.

## Phase 3: The React Web Application
With the infrastructure deployed, we will write the actual software!
- **[NEW] `/webapp`**: Scaffold a modern, beautiful React application (using Vite). We will use the AWS Amplify UI library to drop in a pre-built, highly secure Cognito login screen.
- We will build a dashboard that lists current keys, and a "Generate Key" button that calls your API Gateway endpoint, generates the WireGuard QR code, and lets you download it straight to your phone.
- Once the code is written, we will compile it and sync it to the new S3 bucket!

## Verification Plan
After Phase 1 & 2, we will run `terraform apply` to provision the backend. We will then verify the CloudFront URL is live and the DynamoDB table exists before writing the React code in Phase 3.
