# Facilitator notes

Notes for running the one-hour Git session. Not rendered on the site.

## Before the session

| When | Task |
|---|---|
| 1 week before | Send the prerequisites email (below). Collect GitHub usernames. |
| 1 week before | Add each username as a collaborator with **Write** access: *Settings → Collaborators → Add people*. |
| 2-3 days before | Check who has accepted their invitation (*Settings → Collaborators* shows "Pending"). Chase the rest. |
| Day before | Check the latest **Render and publish** run on `main` is green and the site is live. |
| 30 min before | Run `bash facilitator/stage-conflict.sh` and open a pull request for each `demo/insight-*` branch. |
| 30 min before | Open in tabs: the site, the repository, *Pull requests*, *Actions*, the slides PDF. |

### Repository settings (one-off)

- *Settings → Pages → Build and deployment → Source*: **GitHub Actions**
- *Settings → Branches → Add branch ruleset* (or classic protection rule) for `main`:
  - Require a pull request before merging (1 approval)
  - Require status checks to pass: **render**
  - Block force pushes

## Run sheet (60 minutes)

| Time | Segment | Notes |
|---|---|---|
| 0-5 | Why version control | Slides 1-3. Ask who has a `_final_v3` file. |
| 5-15 | Mental model, what belongs in Git | Slides 4-7. Stress: the repo is public, history is permanent. |
| 15-25 | Live demo of the full loop | In RStudio: branch `facilitator/demo`, change the reference line colour in `R/charts.R`, diff, commit, push, open a PR, show the check running, merge, show Pages update. Mention the Positron equivalents on slides 8-12. |
| 25-45 | Hands-on: Exercise 1, Exercise 2 as stretch | Circulate. Merge Exercise 1 PRs as they go green (approve, then merge). Don't merge Exercise 2 PRs. |
| 45-52 | Merge conflict demo | Merge `demo/insight-a`. Show `demo/insight-b` now says "This branch has conflicts". Resolve live (see below). |
| 52-57 | Undoing, reproducibility, CI | Slides on undoing, renv, CI. Open the workflow run log. |
| 57-60 | Cheat sheet, next steps | Point to Exercises 3-5 as take-home. |

### Resolving the conflict live

```bash
git switch demo/insight-b
git pull
git merge origin/main        # CONFLICT in bowel-cancer.qmd
```

Open `bowel-cancer.qmd` in RStudio, find the markers, write the combined sentence, delete the three marker lines, stage, commit, push. The PR updates, the check reruns, and it can be merged. Optionally repeat the resolution in Positron with **Accept Both** to show the merge editor.

## Prerequisites email

> **Subject:** Git training: setup before the session
>
> Hi all,
>
> Ahead of the Git session on [date], please complete the setup steps here (20-30 minutes, mostly installs):
> https://harmonicr.github.io/acpcc_git_training/exercises/00-setup.html
>
> 1. Install Git, R and RStudio or Positron.
> 2. Create a GitHub account (or use your existing one) and **reply with your GitHub username** so I can add you to the repository.
> 3. Accept the invitation email from GitHub when it arrives.
> 4. Finish the remaining steps on the setup page: connect R to GitHub, clone the repository and render one page.
>
> If you get stuck, reply with a screenshot of the error and I'll help before the day.

## Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| Push asks for a password, or `Authentication failed` | No token stored, or it expired | `usethis::create_github_token()` then `gitcreds::gitcreds_set()` |
| `remote: Permission to ... denied` / 403 | Invitation not accepted | Accept it at github.com/harmonicr/acpcc_git_training/invitations |
| `Please tell me who you are` on commit | Git identity not set | `usethis::use_git_config(user.name = , user.email = )` |
| RStudio has no Git tab | Project not opened, or Git not found | Open the `.Rproj` file; *Tools → Global Options → Git/SVN* → set the Git executable, restart RStudio |
| Push rejected: `fetch first` / `non-fast-forward` | Someone else pushed to the same branch | Pull, then push |
| Accidentally committed to `main` (push is rejected by protection) | Forgot to branch | `git switch -c name/fix` (keeps the commit), push that branch, then `git switch main` and `git reset --hard origin/main` |
| `renv::restore()` fails on one package | Network or proxy | Retry; on a corporate proxy set `options(repos = c(CRAN = "https://cloud.r-project.org"))` and retry |
| `quarto: command not found` in the terminal | Quarto not on PATH | Use the IDE's **Render** button instead, or install Quarto from quarto.org |
| Check fails on a learner PR | Usually an R syntax error | Open *Details* on the check, scroll to the first red line |
