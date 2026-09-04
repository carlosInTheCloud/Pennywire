---
name: aws_setup_guide
description: Guide for setting up AWS IAM Identity Center and SSO
trigger: always_on
---

# AWS Account Authentication Setup Guide

This project relies on **IAM Identity Center (formerly AWS SSO)** to securely authenticate Terraform and the AWS CLI without using long-lived, permanent access keys. 

Follow these steps to configure your AWS environment.

## Step 1: Secure the Root Account
Before doing anything else, secure your primary AWS account.
1. Log into the [AWS Management Console](https://console.aws.amazon.com/) using your root email address.
2. Go to the **IAM Dashboard**.
3. Under "Security recommendations," enable Multi-Factor Authentication (MFA) for the root user.

## Step 2: Enable IAM Identity Center
1. Search for **IAM Identity Center** in the AWS Console search bar.
2. Click **Enable**. (Choose the default AWS organization option if prompted).

## Step 3: Create an Administrative Permission Set
We need to define what permissions our non-root user will have.
1. In the IAM Identity Center left-hand menu, click **Permission sets**.
2. Click **Create permission set**.
3. Choose **Predefined permission set**.
4. Select **AdministratorAccess** and click Next.
5. Review and click **Create**.

## Step 4: Create a User
1. In the IAM Identity Center left-hand menu, click **Users**.
2. Click **Add user**.
3. Fill in your details (Username, Email, First/Last name).
4. Complete the user creation process. You will receive an email with an invitation link. Click it to set your password.

## Step 5: Assign the User to the AWS Account
You have a user and a permission set, now you must link them to your AWS account.
1. In the IAM Identity Center left-hand menu, click **AWS accounts**.
2. Select your AWS account checkbox and click **Assign users or groups**.
3. Select the **Users** tab and select the user you just created. Click Next.
4. Select the **AdministratorAccess** permission set you created in Step 3. Click Next.
5. Review and click **Submit**.

## Step 6: Configure the AWS CLI Locally
Now that AWS is configured, you need to link your local terminal to the Identity Center.
1. Find your **AWS access portal URL** on the IAM Identity Center dashboard (it looks like `https://d-xxxxxxxxx.awsapps.com/start`).
2. Open your terminal and run:
   ```bash
   aws configure sso
   ```
3. Follow the prompts:
   - **SSO session name:** `vpn-sso` (or any name you prefer)
   - **SSO start URL:** Paste your AWS access portal URL here.
   - **SSO region:** The region where you enabled IAM Identity Center (e.g., `us-east-1`).
   - **SSO registration scopes:** Leave blank (press Enter).
4. Your browser will open. Log in using the username and password you created in Step 4. Click **Allow**.
5. Return to the terminal. It will list the AWS account and ask you to select a default region (e.g., `us-east-1`) and default output format (e.g., `json`).
6. **CLI default profile name:** Press Enter to accept the default, or name it `vpn-admin`.

## Step 7: Authenticate Daily
Whenever you start working on this project (or if your temporary credentials expire), simply run:
```bash
aws sso login --profile <your-profile-name>
```
Terraform will automatically detect these credentials and execute your infrastructure changes securely!
