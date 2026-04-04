---
name: clubstraylight-lambda
description: Create and deploy a serverless Lambda app behind the clubstraylight.com CloudFront distribution. Covers Terraform, CI/CD, deploy scripts, and CloudFront routing.
disable-model-invocation: true
---

# Clubstraylight Lambda Deployment

Step-by-step guide to adding a new serverless application to the
clubstraylight.com CloudFront distribution, deployed as an AWS Lambda
behind a Function URL.

## Architecture

```text
Browser → CloudFront (clubstraylight.com/app-name*)
       → Lambda Function URL (us-west-1)
       → Sinatra/Node.js handler
```

Infrastructure lives in `form-terra`. Application code lives in its
own repo. CI/CD deploys via GitHub Actions using OIDC for AWS auth.

## Prerequisites

- Terraform access to `form-terra`
- GitHub repo created (public or private)
- `gh` CLI authenticated

## Step 1: Terraform resources in form-terra

Create `app-name.tf` with these resources (follow retirement.tf or
baa-or-not.tf as templates):

### Required resources

1. **S3 deployment bucket** — stores Lambda zip packages

   ```hcl
   resource "aws_s3_bucket" "app_deployments" {
     bucket = "app-name-deployments"
   }
   ```

   Add `aws_s3_bucket_public_access_block` to block all public access.

2. **Placeholder Lambda artifact** — `data "archive_file"` + `aws_s3_object`
   so Terraform can create the Lambda before real code is deployed.

3. **Lambda execution role** — `aws_iam_role` with
   `lambda.amazonaws.com` trust + `AWSLambdaBasicExecutionRole` attachment.

4. **Lambda function** — Ruby 3.3 or Node.js, handler `app.handler`,
   `reserved_concurrent_executions = 10` for cost protection.

5. **Lambda Function URL** — `authorization_type = "NONE"`, CORS
   `allow_origins = ["*"]`, methods `["GET", "POST"]`.

6. **GitHub OIDC role** — trust scoped to `repo:owner/app-name:*`.
   Policies for `lambda:UpdateFunctionCode`,
   `lambda:GetFunction`, `lambda:GetFunctionConfiguration`,
   `s3:PutObject`/`GetObject`/`ListBucket` on deployment bucket,
   and `cloudfront:CreateInvalidation` on the distribution.

### Variables (in variables.tf)

```hcl
variable "app_lambda_s3_key" {
  default = "app-name/placeholder.zip"
}
variable "app_lambda_runtime" {
  default = "ruby3.3"  # or "nodejs24.x"
}
variable "app_lambda_handler" {
  default = "app.handler"
}
```

### Outputs (in outputs.tf)

Function name, Function URL, deployment bucket, OIDC role ARN,
and the `https://clubstraylight.com/app-name` convenience URL.

## Step 2: CloudFront routing in clubstraylight.tf

Add two blocks to `aws_cloudfront_distribution.clubstraylight_distribution`:

### Origin

```hcl
origin {
  domain_name = trim(replace(
    aws_lambda_function_url.app.function_url, "https://", ""), "/")
  origin_id = "Lambda-app-name"

  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}
```

### Cache behavior

```hcl
ordered_cache_behavior {
  path_pattern     = "/app-name*"
  allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  cached_methods   = ["GET", "HEAD"]
  target_origin_id = "Lambda-app-name"

  forwarded_values {
    query_string = true
    cookies { forward = "none" }
  }

  viewer_protocol_policy = "redirect-to-https"
  min_ttl                = 0
  default_ttl            = 0
  max_ttl                = 0
}
```

**Important:** `default_ttl = 0` and `max_ttl = 0` — Sinatra apps
serve dynamic content; caching will break form submissions and state.

## Step 3: Apply Terraform

```sh
cd form-terra
terraform validate
terraform plan
terraform apply
```

Capture the OIDC role ARN from outputs for the next step.

## Step 4: Set GitHub secrets and variables

Do this in the same session — don't defer to a manual step.

```sh
terraform output -raw app_github_oidc_role_arn | \
  gh secret set AWS_ROLE_ARN --repo owner/app-name

gh secret set SOLANA_KEYPAIR --repo owner/app-name \
  < ~/.config/solana/keypair.json

gh variable set S3_COMPLIANCE_BUCKET --repo owner/app-name \
  --body "bucket-name"
```

## Step 5: Application deploy script

`bin/deploy` must:

1. Write REVISION file (`git rev-parse --short HEAD`)
2. Copy source to a temp build directory
3. Bundle gems for production (`bundle config set --local without "development test"`)
4. Zip everything including `vendor/bundle`
5. Upload to S3
6. `aws lambda update-function-code`
7. `aws lambda wait function-updated`
8. `aws cloudfront create-invalidation --paths '/app-name*'`

The CloudFront distribution ID for clubstraylight is `ERIW60YQ29CKU`.

### Gemfile.lock must be committed

Lambda deployment requires a lockfile for reproducible gem installs.
Remove `Gemfile.lock` from `.gitignore` if it was added by a gem
scaffold template.

## Step 6: GitHub Actions CI/CD

Workflow needs `permissions: id-token: write` at the top level for
OIDC to work. Two jobs:

- **check** — runs tests, lint, security scans, attestation
- **deploy** — runs only on main push after check passes

The deploy job assumes the OIDC role and runs `./bin/deploy`.

## Step 7: Sinatra app structure (Ruby)

```text
app.rb          # Lambda handler: Lamby.handler(App::Web, event, context)
config.rb       # require_relative "lib/app"
config.ru       # require_relative "lib/app"; run App::Web
lib/app.rb      # top-level module with REVISION constant
lib/app/web.rb  # Sinatra::Base subclass
lib/app/views/  # ERB templates
```

**Critical:** `config.ru` and `config.rb` must require the top-level
module (`lib/app.rb`), not `lib/app/web.rb` directly. Otherwise
constants like `REVISION` defined in the parent module won't be loaded,
causing `NameError` at runtime.

## Pitfalls

### Memo program version (Solana attestation)

Use Memo v2 (`MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`). Memo v1
no longer exists on devnet. See `solana-cicd-hash` skill for details.

### libyear-bundler in CI

`ruby/setup-ruby` with `bundler-cache: true` sets deployment mode.
`libyear-bundler` runs `bundle outdated` which fails in deployment
mode. Fix: `bundle config unset deployment` before running libyear.

### Lambda waiter permissions

`aws lambda wait function-updated` calls `GetFunctionConfiguration`,
not just `GetFunction`. The OIDC role policy needs both actions or
the deploy script will succeed but the waiter will fail with
`AccessDeniedException`.

### Ruby 4.0 stdlib changes

`Time#iso8601` moved to `require "time"` in Ruby 4.0. If your deploy
or attest scripts use `iso8601`, add the explicit require or you'll
get `NoMethodError` in CI (which runs the .ruby-version, not the
system Ruby).

### Content-Type on Lambda Function URL

Lambda Function URLs pass the raw path to the handler. Sinatra routes
must match the CloudFront path pattern (e.g., `get %r{/(app-name)?}`).
Test both the root path and the prefixed path.

### CloudFront invalidation after deploy

Always invalidate `/app-name*` after updating the Lambda. CloudFront
may cache responses even with `default_ttl = 0` if the origin returns
cache headers.

## TECH DEBT: OIDC role sharing (revisit required)

**Current state:** baa-or-not reuses the slacronym OIDC role because
it has `repo:*` trust. This means:

- Any GitHub repo can assume it
- Lambda deploy, S3 artifact write, and CloudFront invalidation
  permissions are all piled onto one role
- CI attestation artifacts land in `slacronym-artifacts` bucket
  regardless of which app produced them

**When fixed:** each app should have its own OIDC role scoped to
`repo:owner/app-name:*` with least-privilege policies. The scoped
role terraform already exists in `baa-or-not.tf` but is not wired
to the GitHub secret. See `clubstraylight-tech-debt` skill for the
full remediation plan.

## Reference implementations

| App | Language | Terraform | Deploy |
| ----- | ---------- | ----------- | -------- |
| slacronym | Node.js | slacronym.tf | deploy.sh (zip + aws lambda update) |
| retirement | Ruby/Sinatra | retirement.tf | bin/deploy (SAM build + zip) |
| baa-or-not | Ruby/Sinatra | baa-or-not.tf | bin/deploy (bundle + zip) |
