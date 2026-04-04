# TODO: Configure S3 backend for remote state. The S3 bucket exists
#   but is not yet wired up for this repository. Add a backend "s3"
#   block with bucket, key, region, and dynamo table for locking.
#
# TODO: Configure GitHub provider authentication. The provider block
#   needs a token — decide whether to use GITHUB_TOKEN env var, a
#   GitHub App installation token, or another mechanism. Branch
#   protection with enforce_admins requires admin-level access.
#
# TODO: Import existing resources before first apply. The repo and
#   default branch already exist, so terraform apply will fail
#   without importing first:
#     terraform import github_repository.dave_skills dave-skills
#     terraform import github_branch_default.master dave-skills
#
# TODO: Decide whether attest CI job belongs in required_status_checks.
#   Currently only markdown-lint is required. The attest job runs only
#   on master pushes (not PRs), so it probably should not be required,
#   but document the decision.

terraform {
  required_version = ">= 1.5"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "doolin"
}

resource "github_repository" "dave_skills" {
  name        = "dave-skills"
  description = "Reusable Claude Code skills"
  visibility  = "public"

  has_issues   = true
  has_projects = false
  has_wiki     = false

  # Merge settings — squash only, linear history
  allow_merge_commit = false
  allow_squash_merge = true
  allow_rebase_merge = false
  allow_auto_merge   = true

  # Squash merge uses PR title + body
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  # Clean up branches after merge
  delete_branch_on_merge = true

  # Vulnerability alerts
  vulnerability_alerts = true
}

resource "github_branch_default" "master" {
  repository = github_repository.dave_skills.name
  branch     = "master"
}

resource "github_branch_protection" "master" {
  repository_id = github_repository.dave_skills.node_id
  pattern       = "master"

  # Require PRs — no direct pushes to master
  required_pull_request_reviews {
    required_approving_review_count = 0
    dismiss_stale_reviews           = true
    require_last_push_approval      = false
  }

  # Require CI to pass before merge
  required_status_checks {
    strict   = true
    contexts = ["markdown-lint"]
  }

  # Linear history — no merge commits on master
  required_linear_history = true

  # No force pushes, no deletions
  allows_force_pushes = false
  allows_deletions    = false

  # Enforce rules for admins too
  enforce_admins = true

  # Block direct pushes — all changes via PR
  restrict_pushes {
    blocks_creations = true
  }
}
