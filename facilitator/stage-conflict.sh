#!/usr/bin/env bash
# Create the two branches for the live merge-conflict demo (session 45-52 min).
# Both edit the same sentence in bowel-cancer.qmd, so whichever is merged
# second conflicts.
#
#   bash facilitator/stage-conflict.sh
#
# Run from the repository root with a clean working tree, shortly before the
# session (so the branches start from the current main).
set -euo pipefail

file=bowel-cancer.qmd
line='^Participation rises steadily with age: .*$'

git fetch origin
git diff --quiet || { echo "Working tree has changes; commit or stash them first." >&2; exit 1; }
grep -q "$line" "$file" || { echo "Can't find the interpretation line in $file." >&2; exit 1; }

make_branch() {
  local branch=$1 text=$2 message=$3
  git switch --quiet -C "$branch" origin/main
  sed -i "s/$line/$text/" "$file"
  git commit --quiet -am "$message"
  git push --quiet --force-with-lease -u origin "$branch"
  echo "Pushed $branch"
}

make_branch demo/insight-a \
  'Participation is highest among people aged 70-74 and lowest among people aged 50-54. Women participate at a higher rate than men in every age group. Regional LGAs tend to sit above the Victorian rate.' \
  'Lead the interpretation with the age gap'

make_branch demo/insight-b \
  'Participation rises steadily with age, from under 40% at 50-54 to almost half of people aged 70-74. Women participate at a higher rate than men in every age group. Regional LGAs tend to sit above the Victorian rate.' \
  'Quote the age-group rates in the interpretation'

git switch --quiet main
echo "Open a pull request for each branch. Merge demo/insight-a first; demo/insight-b will then show a conflict."
