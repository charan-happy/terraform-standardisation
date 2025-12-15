# 🔄 CI/CD Integration & PR Approval Workflow

**How to make infrastructure changes easy for approvers to review and approve**

---

## 🎯 **The Approval Challenge**

**Problem:** Approvers need to understand:
- What infrastructure will change?
- Is it safe?
- What's the cost impact?
- Are there security issues?
- Can we rollback if needed?

**Solution:** Automated CI/CD pipeline that shows everything in the PR automatically.

---

## 📊 **What Approvers See in a PR**

When you open a PR, approvers automatically see:

```
Pull Request #123: Add 2 API servers for new microservice
├── ✅ Terraform Format Check      (passed)
├── ✅ Terraform Validation         (passed)
├── ✅ Security Scan (tfsec)        (passed)
├── ✅ Cost Estimation              (+$150/month)
├── 📋 Terraform Plan               (2 to add, 0 to change, 0 to destroy)
├── 📊 Plan Details                 (expandable, formatted)
└── 🔐 Requires Approval            (2/2 approvers needed)
```

**Result:** Approvers can review and approve in 2 minutes without running anything locally! ✅

---

## 🏗️ **Complete CI/CD Architecture**

### **GitHub Actions Example**

```yaml
# .github/workflows/terraform-pr.yml
name: Terraform PR Review

on:
  pull_request:
    branches: [main]
    paths:
      - 'projects/**/*.tf'
      - 'modules/**/*.tf'

permissions:
  contents: read
  pull-requests: write
  id-token: write  # For AWS OIDC

env:
  TF_VERSION: 1.7.0
  AWS_REGION: us-east-1

jobs:
  # Job 1: Validation & Formatting
  validate:
    name: 🔍 Validate & Format
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        id: fmt
        run: terraform fmt -check -recursive
        continue-on-error: true

      - name: Terraform Init
        working-directory: projects/project-charan/dev
        run: terraform init -backend=false

      - name: Terraform Validate
        working-directory: projects/project-charan/dev
        run: terraform validate

      - name: Comment Format Status
        if: steps.fmt.outcome == 'failure'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ **Terraform Format Check Failed**\n\nPlease run `terraform fmt -recursive` to fix formatting.'
            })

  # Job 2: Security Scanning
  security:
    name: 🔐 Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: false
          format: markdown
          working_directory: projects/project-charan/dev

      - name: Run Checkov
        id: checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: projects/project-charan/dev
          framework: terraform
          output_format: github_failed_only
          soft_fail: false

      - name: Comment Security Results
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const tfsec = `${{ steps.tfsec.outputs.markdown }}`;
            const checkov = `${{ steps.checkov.outputs.results }}`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## 🔐 Security Scan Results\n\n### tfsec\n${tfsec}\n\n### Checkov\n${checkov}`
            })

  # Job 3: Cost Estimation
  cost:
    name: 💰 Cost Estimation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: projects/project-charan/dev
        run: terraform init

      - name: Terraform Plan
        working-directory: projects/project-charan/dev
        run: terraform plan -out=tfplan

      - name: Infracost Breakdown
        uses: infracost/actions/breakdown@v2
        with:
          path: projects/project-charan/dev
          terraform_plan_file: tfplan
          
      - name: Post Infracost Comment
        uses: infracost/actions/comment@v2
        with:
          path: /tmp/infracost.json
          behavior: update

  # Job 4: Terraform Plan (Main Job)
  plan:
    name: 📋 Terraform Plan
    runs-on: ubuntu-latest
    needs: [validate, security]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: true

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: projects/project-charan/dev
        run: terraform init

      - name: Terraform Plan
        id: plan
        working-directory: projects/project-charan/dev
        run: |
          terraform plan -out=tfplan -no-color | tee plan-output.txt
          echo "exitcode=$?" >> $GITHUB_OUTPUT

      - name: Generate Plan Summary
        working-directory: projects/project-charan/dev
        run: |
          # Extract summary
          terraform show -json tfplan > plan.json
          
          # Parse with jq
          echo "## 📊 Terraform Plan Summary" > summary.md
          echo "" >> summary.md
          
          # Resource changes
          ADDITIONS=$(jq '[.resource_changes[] | select(.change.actions | contains(["create"]))] | length' plan.json)
          CHANGES=$(jq '[.resource_changes[] | select(.change.actions | contains(["update"]))] | length' plan.json)
          DELETIONS=$(jq '[.resource_changes[] | select(.change.actions | contains(["delete"]))] | length' plan.json)
          
          echo "- **Resources to Add:** $ADDITIONS" >> summary.md
          echo "- **Resources to Change:** $CHANGES" >> summary.md
          echo "- **Resources to Destroy:** $DELETIONS" >> summary.md
          echo "" >> summary.md
          
          # Detailed changes
          echo "<details>" >> summary.md
          echo "<summary>📋 View Detailed Plan Output</summary>" >> summary.md
          echo "" >> summary.md
          echo '```terraform' >> summary.md
          cat plan-output.txt >> summary.md
          echo '```' >> summary.md
          echo "</details>" >> summary.md

      - name: Upload Plan Artifact
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan
          path: projects/project-charan/dev/tfplan
          retention-days: 5

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const summary = fs.readFileSync('projects/project-charan/dev/summary.md', 'utf8');
            
            const comment = `## Terraform Plan Results
            
            **Status:** ${{ steps.plan.outputs.exitcode == 0 && '✅ Success' || '❌ Failed' }}
            
            ${summary}
            
            ---
            
            ### ⚠️ Important Notes:
            - Review the plan carefully before approving
            - Ensure no unexpected deletions
            - Check resource attributes match requirements
            - Verify cost estimation above
            
            ### 🚀 Next Steps:
            1. **Approve this PR** (requires 2 approvals)
            2. **Merge to main** 
            3. **Auto-deploy** will run \`terraform apply\`
            
            <sub>Plan generated at: ${new Date().toISOString()}</sub>
            `;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });

      - name: Update PR Status
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const status = '${{ steps.plan.outputs.exitcode }}' === '0' ? 'success' : 'failure';
            
            github.rest.repos.createCommitStatus({
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.sha,
              state: status,
              target_url: `https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`,
              description: status === 'success' ? 'Terraform plan succeeded' : 'Terraform plan failed',
              context: 'terraform/plan'
            });
```

---

### **Deployment Workflow (After PR Merge)**

```yaml
# .github/workflows/terraform-deploy.yml
name: Terraform Deploy

on:
  push:
    branches: [main]
    paths:
      - 'projects/**/*.tf'
      - 'modules/**/*.tf'

permissions:
  contents: read
  id-token: write

env:
  TF_VERSION: 1.7.0
  AWS_REGION: us-east-1

jobs:
  deploy:
    name: 🚀 Deploy to Dev
    runs-on: ubuntu-latest
    environment:
      name: development
      url: https://console.aws.amazon.com
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-terraform
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        working-directory: projects/project-charan/dev
        run: terraform init

      - name: Terraform Plan
        working-directory: projects/project-charan/dev
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        working-directory: projects/project-charan/dev
        run: terraform apply -auto-approve tfplan

      - name: Generate Output Summary
        working-directory: projects/project-charan/dev
        run: |
          echo "## 🎉 Deployment Complete" > $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Outputs:" >> $GITHUB_STEP_SUMMARY
          terraform output -json | jq -r 'to_entries[] | "- **\(.key)**: \(.value.value)"' >> $GITHUB_STEP_SUMMARY

      - name: Notify Success
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            const commit = context.payload.head_commit;
            const message = `✅ **Deployment Successful**
            
            Commit: ${commit.message}
            Author: ${commit.author.name}
            SHA: \`${context.sha.substring(0, 7)}\`
            
            [View Workflow Run](https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId})
            `;
            
            // Post to Slack/Teams/Discord if configured
            console.log(message);

      - name: Rollback on Failure
        if: failure()
        working-directory: projects/project-charan/dev
        run: |
          echo "Deployment failed. Consider manual rollback or revert commit."
          # Optional: Auto-restore previous state version
```

---

## 🔧 **GitLab CI/CD Example**

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - plan
  - deploy

variables:
  TF_VERSION: "1.7.0"
  TF_ROOT: projects/project-charan/dev
  TF_ADDRESS: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/dev"

# Use GitLab-managed Terraform state
.terraform:
  image: hashicorp/terraform:${TF_VERSION}
  before_script:
    - cd ${TF_ROOT}
    - terraform init
      -backend-config="address=${TF_ADDRESS}"
      -backend-config="lock_address=${TF_ADDRESS}/lock"
      -backend-config="unlock_address=${TF_ADDRESS}/lock"
      -backend-config="username=gitlab-ci-token"
      -backend-config="password=${CI_JOB_TOKEN}"
      -backend-config="lock_method=POST"
      -backend-config="unlock_method=DELETE"
      -backend-config="retry_wait_min=5"

# Format Check
fmt:
  stage: validate
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform fmt -check -recursive
  allow_failure: false

# Validation
validate:
  extends: .terraform
  stage: validate
  script:
    - terraform validate
  only:
    - merge_requests
    - main

# Security Scan
tfsec:
  stage: validate
  image: aquasec/tfsec:latest
  script:
    - tfsec ${TF_ROOT} --format markdown > tfsec-report.md
  artifacts:
    reports:
      security: tfsec-report.md
    paths:
      - tfsec-report.md
  allow_failure: true
  only:
    - merge_requests

# Terraform Plan (Merge Requests)
plan:
  extends: .terraform
  stage: plan
  script:
    - terraform plan -out=tfplan
    - terraform show -json tfplan > plan.json
    - terraform show tfplan > plan.txt
  artifacts:
    name: plan
    paths:
      - ${TF_ROOT}/tfplan
      - ${TF_ROOT}/plan.json
      - ${TF_ROOT}/plan.txt
    reports:
      terraform: ${TF_ROOT}/plan.json
  only:
    - merge_requests

# Cost Estimation (Merge Requests)
cost:
  stage: plan
  needs: [plan]
  image: infracost/infracost:ci-latest
  variables:
    INFRACOST_API_KEY: ${INFRACOST_API_KEY}
  script:
    - cd ${TF_ROOT}
    - infracost breakdown --path plan.json --format json --out-file /tmp/infracost.json
    - infracost comment gitlab --path /tmp/infracost.json --merge-request ${CI_MERGE_REQUEST_IID}
  only:
    - merge_requests

# Deploy (Main branch only)
deploy:
  extends: .terraform
  stage: deploy
  script:
    - terraform apply -auto-approve
    - terraform output -json > outputs.json
  artifacts:
    paths:
      - ${TF_ROOT}/outputs.json
  environment:
    name: development
    on_stop: destroy
  only:
    - main
  when: manual  # Requires manual approval

# Destroy (Manual trigger only)
destroy:
  extends: .terraform
  stage: deploy
  script:
    - terraform destroy -auto-approve
  environment:
    name: development
    action: stop
  when: manual
  only:
    - main
```

---

## 📋 **Branch Protection & Approval Rules**

### **GitHub Settings**

```yaml
# .github/branch-protection.yml (conceptual)
branches:
  main:
    protection:
      required_status_checks:
        strict: true
        contexts:
          - "validate"
          - "security"
          - "terraform/plan"
      
      required_pull_request_reviews:
        dismiss_stale_reviews: true
        require_code_owner_reviews: true
        required_approving_review_count: 2
        require_last_push_approval: true
      
      restrictions:
        users: []
        teams: ["platform-team", "sre-team"]
      
      enforce_admins: true
      allow_force_pushes: false
      allow_deletions: false
```

**Setup via UI:**
1. Go to Repository → Settings → Branches
2. Add branch protection rule for `main`
3. Enable:
   - ✅ Require status checks (all must pass)
   - ✅ Require 2 approvals
   - ✅ Dismiss stale reviews
   - ✅ Require review from Code Owners
   - ✅ Include administrators

---

### **GitLab Settings**

```yaml
# .gitlab/CODEOWNERS
# Define who can approve changes

# All Terraform files require approval from platform team
*.tf @platform-team @sre-team
projects/** @platform-team
modules/** @sre-team

# Specific environments
projects/**/prod/** @platform-team @security-team
```

**Setup via UI:**
1. Go to Settings → Repository → Protected Branches
2. Protect `main` branch:
   - ✅ Allowed to merge: Maintainers only
   - ✅ Allowed to push: No one
3. Go to Settings → Merge Requests:
   - ✅ Merge request approvals: 2 required
   - ✅ Prevent approval by author
   - ✅ Remove all approvals when commits are added

---

## 🎨 **PR Template for Easy Review**

```markdown
# .github/pull_request_template.md

## 📋 Infrastructure Change Request

### Summary
<!-- Brief description of what infrastructure is being changed and why -->

### Resources Changed
<!-- List of resources being added/modified/removed -->
- [ ] VPC
- [ ] EC2 Instances
- [ ] RDS Database
- [ ] Security Groups
- [ ] IAM Roles
- [ ] Other: ___________

### Environment
- [ ] Development
- [ ] Staging
- [ ] Production

### Change Type
- [ ] New infrastructure
- [ ] Update existing infrastructure
- [ ] Remove/destroy infrastructure
- [ ] Configuration change only
- [ ] Emergency fix

### Testing
- [ ] Ran `terraform fmt`
- [ ] Ran `terraform validate`
- [ ] Ran `terraform plan` locally
- [ ] Reviewed plan output (no unexpected changes)
- [ ] Security scan passed (tfsec/checkov)
- [ ] Cost estimation reviewed
- [ ] Tested in development environment

### Rollback Plan
<!-- How to rollback if something goes wrong -->

### Related Issues
<!-- Link to tickets, issues, or documentation -->
Closes #___

### Checklist for Approvers
- [ ] Plan output reviewed - changes match description
- [ ] No unexpected resource deletions
- [ ] Security scan passed
- [ ] Cost impact acceptable
- [ ] Rollback plan documented
- [ ] Production changes have change management ticket

### Additional Notes
<!-- Any special considerations, dependencies, or follow-up tasks -->

---

<!-- DO NOT EDIT BELOW - Auto-generated by CI/CD -->
<!-- Terraform plan output will be posted here automatically -->
```

---

## 📊 **Example PR Comment (What Approvers See)**

```markdown
## 🤖 Terraform Plan Results

**Status:** ✅ Success
**Environment:** Development
**Branch:** feature/add-api-servers
**Commit:** abc123d

---

### 📊 Terraform Plan Summary

- **Resources to Add:** 4
- **Resources to Change:** 0
- **Resources to Destroy:** 0

#### Resources Being Created:
- `module.api_server_1.aws_instance.main` - t3.small EC2 instance
- `module.api_server_2.aws_instance.main` - t3.small EC2 instance
- `aws_security_group.api_servers` - Security group for API
- `aws_lb_target_group_attachment.api_1` - ALB attachment

---

### 💰 Cost Estimation

| Resource | Monthly Cost | Change |
|----------|-------------|--------|
| EC2 (t3.small x2) | $30.40 | +$30.40 |
| ALB (existing) | $16.20 | $0.00 |
| **Total** | **$46.60** | **+$30.40** |

---

### 🔐 Security Scan Results

✅ **tfsec:** No issues found  
✅ **Checkov:** All checks passed  
✅ **No high-severity vulnerabilities**

<details>
<summary>View Security Details</summary>

```
tfsec scan completed
- 0 high severity issues
- 0 medium severity issues
- 0 low severity issues

All security best practices followed ✅
```
</details>

---

### 📋 Detailed Plan Output

<details>
<summary>Click to expand terraform plan output</summary>

```terraform
Terraform will perform the following actions:

  # module.api_server_1.aws_instance.main will be created
  + resource "aws_instance" "main" {
      + ami                          = "ami-0c55b159cbfafe1f0"
      + instance_type                = "t3.small"
      + subnet_id                    = "subnet-abc123"
      + vpc_security_group_ids       = [
          + (known after apply),
        ]
      + tags                         = {
          + "Name"        = "api-server-1"
          + "Environment" = "dev"
          + "Role"        = "api"
        }
    }

  # module.api_server_2.aws_instance.main will be created
  + resource "aws_instance" "main" {
      + ami                          = "ami-0c55b159cbfafe1f0"
      + instance_type                = "t3.small"
      + subnet_id                    = "subnet-def456"
      + vpc_security_group_ids       = [
          + (known after apply),
        ]
      + tags                         = {
          + "Name"        = "api-server-2"
          + "Environment" = "dev"
          + "Role"        = "api"
        }
    }

Plan: 4 to add, 0 to change, 0 to destroy.
```
</details>

---

### ⚠️ Important Notes for Reviewers:

✅ **Safe Changes:**
- Only adding new resources (no modifications or deletions)
- Existing infrastructure unaffected
- All resources properly tagged

✅ **Security:**
- Security groups restrict access appropriately
- No public exposure except via ALB
- IAM roles follow least privilege

✅ **Cost:**
- Monthly increase: $30.40 (within budget)
- Auto-scaling not enabled (can add later)

---

### 🚀 Next Steps:

1. **Review the plan above carefully**
2. **Approve this PR** (2 approvals required)
3. **Merge to main** → Auto-deployment will trigger
4. **Monitor deployment** in Actions tab

---

### 📈 CI/CD Status:

| Check | Status | Details |
|-------|--------|---------|
| Format | ✅ Passed | Code formatted correctly |
| Validate | ✅ Passed | Configuration valid |
| Security | ✅ Passed | No vulnerabilities |
| Plan | ✅ Passed | Plan generated successfully |
| Cost | ✅ Passed | +$30.40/month |

---

<sub>Plan generated at: 2025-12-15T10:30:00Z | [View Workflow](https://github.com/org/repo/actions/runs/123456)</sub>
```

---

## 🎯 **Approval Workflow Summary**

### **For PR Author:**
1. Create branch: `git checkout -b feature/my-change`
2. Make infrastructure changes in Terraform
3. Commit: `git commit -m "Add API servers for microservice"`
4. Push: `git push origin feature/my-change`
5. Create PR on GitHub/GitLab
6. **CI/CD automatically:**
   - ✅ Runs format check
   - ✅ Validates configuration
   - ✅ Runs security scan
   - ✅ Generates plan
   - ✅ Estimates cost
   - ✅ Posts all results as PR comment
7. Wait for approvals (2 required)
8. Merge PR
9. **Auto-deploy runs** (or manual trigger)

### **For Approvers:**
1. Open PR
2. **Read PR description** (what and why)
3. **Review auto-generated comment:**
   - Check resource changes (add/modify/delete)
   - Review cost impact
   - Verify security scan passed
   - Expand detailed plan if needed
4. **Approve if satisfied**
5. Done! (2 minutes max)

**No need to run terraform locally!** ✅

---

## 🛡️ **Production Deployment Protection**

For production deployments, add extra gates:

```yaml
# .github/workflows/terraform-prod.yml
deploy-prod:
  name: 🚀 Deploy to Production
  runs-on: ubuntu-latest
  environment:
    name: production
    url: https://console.aws.amazon.com
  needs: [deploy-staging]
  steps:
    # ... deployment steps ...
  
  # Manual approval required
  # Configured in GitHub Settings → Environments → production
  #  - Required reviewers: @platform-lead, @cto
  #  - Wait timer: 30 minutes minimum
  #  - Protection rules: Only main branch
```

**GitHub Environment Protection:**
- Require 2+ approvers (senior team members)
- 30-minute wait time before deployment
- Only from `main` branch
- Change management ticket required
- Automated rollback on failure

---

## 📧 **Notification Integration**

Add Slack/Teams notifications:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "${{ job.status == 'success' && '✅' || '❌' }} Terraform ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*PR #${{ github.event.number }}*: ${{ github.event.pull_request.title }}\n*Status:* ${{ job.status }}\n*Author:* ${{ github.actor }}\n<${{ github.event.pull_request.html_url }}|View PR>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 📋 **Complete Setup Checklist**

### **One-Time Setup:**
- [ ] Create GitHub/GitLab workflow files
- [ ] Configure AWS OIDC for GitHub Actions (no access keys!)
- [ ] Set up branch protection rules (main branch)
- [ ] Configure required approvers (2 minimum)
- [ ] Add CODEOWNERS file
- [ ] Create PR template
- [ ] Set up Slack/Teams webhooks (optional)
- [ ] Configure Infracost API key (optional)
- [ ] Create production environment with protection

### **Per-Project Setup:**
- [ ] Copy workflow files to project
- [ ] Update working directories in workflows
- [ ] Configure environment-specific variables
- [ ] Test workflow with sample PR
- [ ] Document approval process for team

---

## 🚀 **Quick Start: Add CI/CD to Your POC**

```bash
# 1. Create workflow directory
mkdir -p .github/workflows

# 2. Create workflow files (copy from examples above)
touch .github/workflows/terraform-pr.yml
touch .github/workflows/terraform-deploy.yml

# 3. Create PR template
touch .github/pull_request_template.md

# 4. Create CODEOWNERS
touch .github/CODEOWNERS

# 5. Commit and push
git add .github/
git commit -m "Add CI/CD pipelines for Terraform"
git push origin main

# 6. Configure branch protection in GitHub UI

# 7. Test with a PR!
git checkout -b test/cicd
echo "# test" >> README.md
git commit -am "Test CI/CD"
git push origin test/cicd
# Create PR and watch automation run! 🎉
```

---

## ✅ **Benefits Summary**

| Benefit | Impact |
|---------|--------|
| **Faster Reviews** | 10 min → 2 min |
| **No Local Setup** | Approvers don't need Terraform installed |
| **Consistent Checks** | Every PR gets same validation |
| **Cost Visibility** | Know cost before deploying |
| **Security Gates** | Auto-block vulnerable configs |
| **Audit Trail** | Every change tracked in Git + CI logs |
| **Rollback Ready** | Plan artifacts saved for recovery |
| **Team Confidence** | See exactly what changes before approval |

---

**This makes your infrastructure changes as easy to review as code PRs!** 🚀

**Next:** See [MANAGER_DEMO_SCRIPT.md](MANAGER_DEMO_SCRIPT.md) to demonstrate this workflow to stakeholders.
