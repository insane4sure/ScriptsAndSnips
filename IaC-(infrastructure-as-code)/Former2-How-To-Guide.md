# Using Former2 for AWS Account Snapshots and Infrastructure as Code (IaC)

## Overview

**Former2** is an open-source tool by Ian McKay that scans your AWS account and generates Infrastructure as Code (IaC) templates (CloudFormation, Terraform, etc.) for your existing resources. This enables you to snapshot, document, and recreate entire AWS accounts or environments—perfect for cost optimization, disaster recovery, or migrating toward 100% IaC.

---

## Why Use Former2?

- **Cost Savings:** Identify and safely decommission unused AWS accounts while preserving all configurations as code.
- **Security:** Run Former2 locally; your credentials and data never leave your machine.
- **IaC Adoption:** Accelerate your journey to 100% Infrastructure as Code.
- **Documentation:** Automatically generate architecture diagrams and resource inventories.

---

## Prerequisites

- **AWS IAM User** with at least `ReadOnlyAccess` and any additional permissions for new services (see below).
- **Node.js** (for running a local static server) or **Python** (for a simple HTTP server).
- **AWS CLI** (optional, for testing permissions).

---

## Step-by-Step Guide

### 1. Create a Temporary Read-Only IAM User

```bash
# Set variables
USER_NAME="former2-readonly"
POLICY_ARN="arn:aws:iam::aws:policy/ReadOnlyAccess"

# Create the user
aws iam create-user --user-name $USER_NAME

# Attach ReadOnlyAccess policy
aws iam attach-user-policy --user-name $USER_NAME --policy-arn $POLICY_ARN

# (Optional) Add missing permissions for new AWS services
cat <<EOF > former2-customerprofiles-readonly.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "profile:List*",
                "profile:Get*",
                "profile:Search*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name Former2CustomerProfilesReadOnly \
    --policy-document file://former2-customerprofiles-readonly.json

aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn arn:aws:iam::<your-account-id>:policy/Former2CustomerProfilesReadOnly

# Create access keys (save these securely!)
aws iam create-access-key --user-name $USER_NAME
```
### 2. Clone and Run Former2 Locally

```bash
git clone https://github.com/iann0036/former2.git
cd former2
```
#### Option A: Serve with Node.js
```
npm install -g http-server
http-server -p 8000
```

#### Option B: Serve with Python
```
python3 -m http.server 8000
```
# Now open http://localhost:8000 in your browser.

### 3. Scan Your AWS Account

1.  Enter your temporary IAM Access Key and Secret Key into Former2.
2.  Select the AWS region(s) you want to scan.
3.  Click **Scan**.
4.  Use the **Search** or **Browse** features to find and select resources.
5.  To snapshot the entire account, use **Select All** for each region and global resources.

* * *

### 4. Generate and Download IaC Templates

*   Click **Generate Template** or **Generate**.
*   Choose your desired format (CloudFormation, Terraform, etc.).
*   Download the generated files.
*   Optionally, download architecture diagrams.

* * *

### 5. Cleanup: Delete Temporary IAM User

```
USER_NAME="former2-readonly"

# Delete all access keys
for key in $(aws iam list-access-keys --user-name $USER_NAME --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam delete-access-key --user-name $USER_NAME --access-key-id $key
done

# Detach all policies
for policy_arn in $(aws iam list-attached-user-policies --user-name $USER_NAME --query 'AttachedPolicies[].PolicyArn' --output text); do
  aws iam detach-user-policy --user-name $USER_NAME --policy-arn $policy_arn
done

# Delete inline policies
for policy_name in $(aws iam list-user-policies --user-name $USER_NAME --query 'PolicyNames[]' --output text); do
  aws iam delete-user-policy --user-name $USER_NAME --policy-name $policy_name
done

# Delete the user
aws iam delete-user --user-name $USER_NAME
```

* * *

Security Best Practices
-----------------------

*   **Always use a temporary IAM user with minimal permissions.**
*   **Delete credentials immediately after use.**
*   **Review Former2’s code if you have security concerns.** It is a static site and does not send your credentials or data to any backend by default.
*   **Never share your IAM credentials.**

* * *

Troubleshooting
---------------

*   **Missing Resources:**  
    Ensure you have selected the correct region and your IAM user has all necessary permissions.
*   **API Errors:**  
    Some AWS services may require additional permissions not included in `ReadOnlyAccess`. Add custom policies as needed.
*   **No Output:**  
    Check browser console for errors, and verify resources exist in your AWS account.

* * *

Supporting Former2
------------------

If you find Former2 valuable, consider supporting its creator, Ian McKay:
*   [GitHub Sponsors](https://github.com/sponsors/iann0036)
*   [Buy Me a Coffee](https://www.buymeacoffee.com/iann0036)
*   [Patreon](https://www.patreon.com/iann0036)

* * *

References
----------

*   [Former2 Website](https://former2.com/)
*   [Former2 GitHub](https://github.com/iann0036/former2)
*   [AWS Free Tier](https://aws.amazon.com/free/)
*   [AWS IAM Documentation](https://docs.aws.amazon.com/iam/latest/UserGuide/introduction.html)

* * *

Example Workflow
----------------

1.  **Clone Former2**
2.  **Host it locally**
3.  **Create a temporary IAM credential**
4.  **Scan your AWS account**
5.  **Select all resources and generate IaC**
6.  **Delete the temporary IAM credential**
7.  **Download and store your templates/diagrams**

* * *

Tags
----

`#AWS #IaC #DevOps #Security #OpenSource #CostOptimization #Former2 #CloudFormation #Terraform`