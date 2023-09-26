#!/bin/bash

GREEN_SUCCESS_COLOR='\033[0;32m'
RED_ERROR_COLOR='\033[0;31m'
RESET='\033[0m' # Reset text color to white
SKY_BLUE_PROMPT_COLOR='\033[1;36m'
YELLOW_INFO_COLOR='\033[1;33m'

# TODO: Seems like there could be a problem if the user has a branch named master-alakazam-review... nah, that's probably fine
# TODO: I could make it so that if we're on master, assume that the user wants to compare their version of master to the remote master HEAD
# TODO: I could also make it so that the user can provide two different branches, one as the base, and one as the branch to compare to the base

# TODO: It seems like I could really benefit from simplifying my logic.
#   I could require a branch name. Considering the use case, this could be the best option.
#     Users don't necesarrily want the branch locally, they may just want to review the PR locally and be done with it
#   I could also allow for a branch that is not yet local, but exists on the remote, this goes with the observation that users may not want the branch locally

# This script is designed to inspect the diff between your current branch and master (or any-other-branch-supplied-as-an-argument with master)
# It is especially useful for reviewing pull requests

# This script assumes:
# 1. That you're working on a local github repository with a master branch named 'master'
# 2. That normal git commands like 'git push' and 'git pull' are configuRED_ERROR_COLOR to an upstream remote (a github repo online)
# 3. That you're on a branch other than master (if no arguments are supplied)
# 4. That you're on a clean branch (no uncommitted changes) (we check for this below)
# 5. That if you supply an argument, it's a valid branch name (we check for this below)

# The following are reasons this script won't work, they explain the next four guard clauses
# 1. Not in a git repo
# 2. On a detached head
# 3. On a dirty branch (you have uncommitted changes that you should either commit stash, or revert)
# 4. On master (and no arguments were supplied, so nothing to compare)
# 5. An argument was supplied, but it's not a valid branch name

# 1. Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo -e "${RED_ERROR_COLOR}Error: You need to be in a git repository to use this script.${RESET}"
  exit 1
fi

# 2. Ensure we're not on a detached head
if git symbolic-ref -q HEAD > /dev/null 2>&1; then
  # We're on a branch
  :
else
  # We're on a detached head
  echo -e "${RED_ERROR_COLOR}Error: You need to be on a branch to use this script.${RESET}"
  exit 1
fi

# 3. Ensure we're not on a dirty branch (uncommitted changes)
if ! git diff-index --quiet HEAD -- > /dev/null 2>&1; then
  echo -e "${RED_ERROR_COLOR}Error: You need to be on a clean branch to use this script.${RESET}"
  exit 1
fi

# 4. Ensure we're not on master (if no arguments were supplied)
if [ $# -eq 0 ]; then
  # No arguments supplied
  current_branch=$(git symbolic-ref --short HEAD)
  if [ "$current_branch" == "master" ]; then
    # I used the variable $current_branch to make the code more readable, you're welcome
    echo -e "${RED_ERROR_COLOR}Error: You need to be on the branch you want to inspect (you're on $current_branch) or supply a branch to inspect its diff from master.${RESET}"
    exit 1
  fi
fi

# 5. If arguments were supplied, ensure the first argument is a valid branch name
if [ $# -gt 0 ]; then
  # Make sure the argument is a valid branch name
  if ! git show-ref --verify --quiet "refs/heads/$1"; then
    echo -e "${RED_ERROR_COLOR}Error: '$1' is not a valid branch name.${RESET}"
    exit 1
  fi
fi

# Now that we're reasonably sure the script will work, we can start doing things

# Store the current branch so we can return to it later
initial_branch=$(git symbolic-ref --short HEAD)

# Check for the case where there is at least one argument (it's fine if there are none, we checked for the case where the user is on master above).
# In the case that there was an argument provided, we assume it's a branch
# We want to checkout that branch, pull the latest changes from the remote, and then checkout master and pull the latest changes from the remote.
# This puts us in a state where we can perform a diff between the two branches (the one we provided as an argument and master).
if [ $# -gt 0 ]; then
  # An argument was supplied (its valid, we checked above)

  # checkout the branch we provided as an argument without console output and into a branch named $1-alakazam-review instead of $1
  echo -e "${YELLOW_INFO_COLOR} checking out $1 > $1-alakazam-review and pulling latest changes from remote${RESET}"
  git checkout $1 --quiet 2> /dev/null
  git pull 2> --quiet /dev/null
  git checkout $1 --quiet 2> /dev/null -b $1-alakazam-review
  git pull --quiet 2> /dev/null

  echo -e "${YELLOW_INFO_COLOR} checking out master HEAD as branch -> master-alakazam-review and pulling latest changes from remote${RESET}"
  # checkout master without console output and into a branch named master-alakazam-review instead of master
  git checkout master --quiet 2> /dev/null -b master-alakazam-review
  git pull --quiet 2> /dev/null

  echo -e "${YELLOW_INFO_COLOR} checking out $1 as branch -> $1-alakazam-review and pulling latest changes from remote${RESET}"
  git checkout $1 2> /dev/null && git checkout $(git symbolic-ref --short HEAD) 2> /dev/null -b "$1-alakazam-review" && git pull 2> /dev/null

else # No arguments were supplied, so we'll compare the current (clean, we're sure) branch to master

  echo -e "${YELLOW_INFO_COLOR} checking out master HEAD from remote as branch -> master-alakazam-review and pulling latest changes from remote${RESET}"
  # checkout master without console output and into a branch named master-alakazam-review instead of master
  git checkout master 2> /dev/null -b master-alakazam-review

  echo -e "${YELLOW_INFO_COLOR} checking out $initial_branch as branch -> $initial_branch-alakazam-review and pulling latest changes from remote${RESET}"
  git checkout $initial_branch 2> /dev/null --quiet -b "$initial_branch-alakazam-review"
fi

# Perform git reset --soft with the master branch
# This is the magic part, what we've done all this work to get to... I hope you're excited
git reset --soft master-alakazam-review 2> /dev/null

# Wait for user input to pause the script (because all thats left is cleanup)
echo -e "${SKY_BLUE_PROMPT_COLOR}Press Enter when done reviewing the diff: ${RESET}"
read

git checkout --quiet $initial_branch 2> /dev/null
git branch -D --quiet "$initial_branch-alakazam-review" 2> /dev/null
git branch -D --quiet master-alakazam-review 2> /dev/null
git stash push -m alakazamage --quiet 2> /dev/null
# git stash drop alakazamage --quiet 2> /dev/null

echo -e "${GREEN_SUCCESS_COLOR}kazam!${RESET}"