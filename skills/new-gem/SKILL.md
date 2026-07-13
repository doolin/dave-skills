---
name: new-gem
description: Bootstrap a new Ruby gem with RSpec, RuboCop, rubocop-rspec, SimpleCov, CI, and standard metadata.
---

Bootstrap a new Ruby gem using the arguments provided: $ARGUMENTS

The arguments should be parsed as: GEM_NAME followed by an optional summary in quotes.
Example: `/new-gem my_gem "A short description of the gem"`

## Autonomy

All file edits, file creation, shell commands (`bundle gem`, `bundle install`,
`bundle exec rspec`, `bundle exec rubocop`, `rubocop -A`), and generated-file
modifications described in the steps below are pre-authorized by the user.
Proceed through every step without pausing for confirmation. Only stop to ask
if something fails unexpectedly or falls outside the scope of these steps.

## Steps

1. **Scaffold with `bundle gem`** using these flags:
   - `--test=rspec`
   - `--ci=github`
   - `--changelog`
   - `--linter=rubocop`
   - `--mit`
   - `--no-git` (we manage git separately)
   - Do NOT use `--rubocop` (removed; `--linter=rubocop` covers it).
   - Do NOT use `--ext` unless the user explicitly requests a C extension.

2. **Add `rubocop-rspec`, `rubocop-performance`, and `simplecov`** to the Gemfile and update `.rubocop.yml` to load the RuboCop plugins (not `require`, which is deprecated in newer RuboCop):

   Add to the Gemfile:
   ```ruby
   gem "simplecov", require: false
   ```

   Update `.rubocop.yml`:
   ```yaml
   plugins:
     - rubocop-rspec
     - rubocop-performance

   AllCops:
     NewCops: enable
     TargetRubyVersion: 3.2
   ```

   Add SimpleCov to the top of `spec/spec_helper.rb` (before any other requires):
   ```ruby
   require "simplecov"
   SimpleCov.start
   ```

3. **Fill in gemspec metadata**:
   - Set `spec.summary` to the provided summary (or a sensible placeholder).
   - Set `spec.description` to a longer form of the summary.
   - Remove or fill in any `TODO` strings so the gemspec is immediately valid.
   - Set `spec.homepage`, `spec.metadata["source_code_uri"]`, and `spec.metadata["changelog_uri"]` to placeholder URLs the user can update later.
   - Ensure `spec.required_ruby_version` is set to `>= 3.2`.

4. **Create a smoke spec** at `spec/<gem_name>_spec.rb`:
   ```ruby
   # frozen_string_literal: true

   RSpec.describe <GemModule> do
     it "has a version number" do
       expect(<GemModule>::VERSION).not_to be_nil
     end
   end
   ```

5. **Create `.rspec`** with:
   ```
   --require spec_helper
   --format documentation
   --color
   ```

6. **Create `.gitignore`** (`bundle gem` omits it under `--no-git`) with the standard gem ignores — the generated artifacts (`coverage/` from SimpleCov, `.rspec_status`, build output) plus `Gemfile.lock`, which a gem ignores because it is a library, not an app:
   ```
   /.bundle/
   /.yardoc
   /_yardoc/
   /coverage/
   /doc/
   /pkg/
   /spec/reports/
   /tmp/

   # rspec failure tracking
   .rspec_status

   # a gem is a library; lock the app that consumes it, not the gem itself
   Gemfile.lock
   ```

7. **Run validation**:
   - `bundle install`
   - `bundle exec rspec` — confirm specs pass.
   - `bundle exec rubocop` — fix any auto-correctable offenses with `rubocop -A`, then report remaining issues.

8. **Report results** to the user: list created files, test results, and any RuboCop issues that need manual attention.

## Optional: Create the GitHub repo and push

Run this section only when the user asks to push the gem to GitHub. These steps were proven out on the `polysemic` gem.

1. **Confirm visibility** with the user (public vs private) — this is a hard-to-reverse choice for anything sensitive, so ask before creating.

2. **Update gemspec URLs** from the placeholders to the real repo:
   - `spec.homepage = "https://github.com/<owner>/<gem>"`
   - `spec.metadata["source_code_uri"] = "https://github.com/<owner>/<gem>"`
   - `spec.metadata["changelog_uri"] = "https://github.com/<owner>/<gem>/blob/main/CHANGELOG.md"`

3. **Replace placeholders in generated files**:
   - `LICENSE.txt` — replace `Copyright (c) <YEAR> TODO: Write your name` with the real author.
   - Author/email in the gemspec, if still `TODO`.

4. **Confirm `.gitignore` covers build artifacts** — `coverage/`, `pkg/`, `.rspec_status` are already in the step 6 set, so nothing SimpleCov or `gem build` produces gets committed. (The gemspec's `git ls-files` file list also needs a real git repo — this section's `git init` is what makes `spec.files` populate.)

5. **Init and commit**:
   ```bash
   git init -b main
   git add <explicit list of files — do NOT use "git add ." since coverage/ may exist>
   git commit -m "Initial commit: scaffold <gem> gem"
   ```

6. **Create the repo and push**:
   ```bash
   gh repo create <owner>/<gem> \
     --private \                        # or --public per user choice
     --description "<gem summary>" \
     --source=. --remote=origin --push
   ```

7. **If the push fails**, diagnose and recover:
   - **`Permission denied (publickey)`** — the default SSH config can't reach GitHub for this account. Ask the user how they'd like to authenticate (e.g. a per-account SSH host alias they've configured locally). Do not guess the alias. Once they supply it, `git remote set-url origin <their-url>` and `git push -u origin main`.
   - **`refusing to allow an OAuth App to create or update workflow ... without 'workflow' scope`** — the gh token lacks the `workflow` scope needed to push `.github/workflows/main.yml`. Either switch to SSH or ask the user to run `gh auth refresh -s workflow`.

## Constraints

- Do not create unnecessary files beyond what `bundle gem` and the steps above produce.
- Prefer editing generated files over creating new ones.
- Do not commit unless the user asks. The user has a separate `/tasteful-commits` command for that.

## Future extensions

- Prompt the user for author name, email, and GitHub username instead of placeholders.
- Automate publishing to RubyGems.org (`gem build` + `gem push`).
