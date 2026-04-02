# GitHub Repository Setup Checklist

This checklist covers manual GitHub configuration required to enforce the branch protection and code review policies documented in [CONTRIBUTING.md](../../CONTRIBUTING.md).

**Timeline:** ~15 minutes  
**Required:** Repository admin or owner access  
**Audience:** DevOps / Release Manager

---

## Pre-Setup Verification

Before starting, verify these prerequisites:

- [ ] Repository has admin/owner access (`Settings` visible in top menu)
- [ ] GitHub Actions workflow (`.github/workflows/ci-verification.yml`) is created and has run at least once
- [ ] CODEOWNERS file (`.github/CODEOWNERS`) exists in repository
- [ ] You have a "Product Team" group configured in your GitHub organization (or you'll create one during setup)

---

## Step 1: Create Product Team Group (Organization-Level)

Skip this if your organization already has a "Product Team" group.

1. Navigate to **Organization Settings** (top-right menu → Organization → Settings)
2. Click **Teams** in the left sidebar
3. Click **New Team** (top-right)
4. Enter Team name: `product-team`
5. Set Visibility: **Private**
6. Click **Create team**
7. Add team members:
   - Click **Members** tab
   - Click **Add a member**
   - Search for and add engineers/leads who review compliance and operations changes
8. Click **Save**

---

## Step 2: Enable Branch Protection for `main`

1. Navigate to your repository
2. Click **Settings** (top menu, right side)
3. Click **Branches** in the left sidebar (under "Code and automation")
4. Click **Add rule** under "Branch protection rules"

### Rule Configuration: Main Branch

**Branch name pattern:** `main`

#### Protect matching branches

- [x] **Require a pull request before merging**
  - [x] Require approvals: **1**
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from Code Owners
  - [ ] Require approval of the latest reviewable commit
  - [ ] Require `CODEOWNERS` review (this is the field above — the next checkbox is not needed)

- [x] **Require status checks to pass before merging**
  - Search for and select: **ci-verification / verification**
  - (Wait 10–30 seconds for the CI workflow to appear in the dropdown after first push)

- [x] **Require conversation resolution before merging**

- [x] **Include administrators**
  - (Check this to enforce rules on admin-approved PRs as well)

- [ ] **Restrict who can push to matching branches** (optional, skip unless you need this)

**Save changes** → Click green **Create** button

---

## Step 3: Verify CODEOWNERS Configuration

1. In your repository, click **Settings**
2. Click **Collaborators and teams** in the left sidebar
3. Verify that `product-team` appears in the list
4. If not, add it:
   - Click **Add people**
   - Search for `product-team`
   - Select **Maintain** or **Admin** role (so they can approve PRs)
   - Click **Add**

---

## Step 4: Test Branch Protection

### Create a test PR to verify branch protection enforcement:

1. Create a new branch: `git checkout -b test/branch-protection`
2. Make a trivial change to a protected file (e.g., edit `Package.swift`):
   ```bash
   echo "# Test" >> Package.swift
   git add Package.swift
   git commit -m "test: verify branch protection"
   ```
3. Push: `git push origin test/branch-protection`
4. Open a Pull Request on GitHub:
   - You should see the PR is **blocked** with a message like:
     - "1 of 1 checks failed" (CI is running)
     - "Review from Code Owners" (required, as `Package.swift` is in CODEOWNERS)
5. Wait for CI to complete (~3–5 minutes)
6. Once CI passes, request a review from `@product-team`:
   - Click **Reviewers** (right sidebar)
   - Type `product-team`
   - Click the team
7. Verify that at least 1 member of `product-team` must approve before merge button is enabled
8. Close the PR without merging (or merge if you want to test full workflow)

### Expected state after CI + review:
```
✅ All checks have passed
✅ At least 1 review from Code Owners (@product-team)
→ Merge button is now enabled
```

---

## Step 5: Configure Additional Security Settings (Recommended)

1. In **Settings** → **Code and automation** → **Security and analysis**:
   - [x] Enable **Dependabot alerts** (if private: optional)
   - [x] Enable **Dependabot security updates** (if private: optional)
   - [x] Enable **Secret scanning** (if private: optional, but recommended)

2. In **Settings** → **General**:
   - [x] Require contributors to sign commits (optional, but recommended for compliance)

---

## Step 6: Document Emergency Override Procedure

In case of production incidents requiring immediate merge, document approved escalation:

1. Open and complete: `docs/operations/emergency-merge-procedure.md`
2. Document condition for override: only X-severity incidents blocking production
3. List authorized personnel who can push directly to `main` (requires branch admin flag)
4. Require post-emergency incident review within 24 hours

**Example template:**
```markdown
# Emergency Merge Procedure

**Authorized for:** Only production incidents blocking users/revenue

**Approved personnel:** [List names]

**Steps:**
1. Declare incident in #incidents Slack channel
2. Get approval from on-call manager + 1 code owner
3. Push with `git push --force-with-lease` (after isolating commits)
4. Immediately create follow-up PR reverting if needed
5. Incident review: Within 24 hours, review override in post-mortem
```

---

## Step 7: Verification Checklist

After completing steps 1–6, verify:

- [ ] Branch protection rule exists for `main`
- [ ] Rule requires 1 code review from `product-team`
- [ ] Rule requires CI status check **ci-verification / verification** to pass
- [ ] Rule dismisses stale reviews on new commits
- [ ] Rule is applied to administrators as well (Box is checked)
- [ ] Product team group exists in organization
- [ ] Product team has **Maintain** or **Admin** role in the repository
- [ ] Test PR confirmed merge button blocked until CI + review both pass
- [ ] Emergency procedure documented in `docs/operations/emergency-merge-procedure.md` (optional but recommended)

After checking all items, record final evidence and approvals in:

- `docs/operations/github-setup-signoff.md`

---

## Troubleshooting

### "CI workflow doesn't appear in branch protection dropdown"

**Solution:**
- The workflow must have run at least once on `main` to appear in the dropdown
- Push a commit to `main` (or a PR that has merged) to trigger the workflow
- Wait 2–5 minutes for GitHub to index it
- Return to branch protection settings and refresh the page
- Search for `ci-verification` in the dropdown

### "CODEOWNERS not showing as required reviewer"

**Solution:**
- Verify `.github/CODEOWNERS` file exists and is syntactically correct:
  ```
  # Comments must start with #
  /path/to/file  @org/team-name
  
  # Must have space before @ and correct team reference
  ```
- Verify `product-team` exists in the organization and the repository
- Wait 5–10 minutes for GitHub to sync CODEOWNERS changes
- Refresh branch protection settings page

### "Merge button still enabled with failing checks"

**Solution:**
- Verify "Require status checks to pass" is **checked** in branch protection
- Verify the CI workflow name is correct: `ci-verification / verification`
- Trigger a new commit to the PR to re-run checks
- May take up to 5 minutes for GitHub to enforce the check

---

## Next Steps

Once GitHub is configured:

1. Pin this checklist in your team documentation or Slack
2. Share [CONTRIBUTING.md](../../CONTRIBUTING.md) with all contributors
3. Walk through [deployment-launch-guide.md](deployment-launch-guide.md) with operations team
4. Run full verification suite locally: `python3 scripts/verify_all.py`
5. Execute first production deployment using [deployment-launch-guide.md](deployment-launch-guide.md)

---

## Support & Escalation

- **GitHub branch protection questions:** See [GitHub Docs: Protected Branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-for-safe-collaboration/managing-rulesets/about-rulesets)
- **CODEOWNERS questions:** See [GitHub Docs: CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- **CI workflow issues:** Check [.github/workflows/ci-verification.yml](.github/workflows/ci-verification.yml) syntax and logs in Actions tab
