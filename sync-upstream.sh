#!/bin/bash
# sync-upstream.sh
# Script to sync a fork of vyos-build with upstream VyOS repository

set -e

# Text formatting
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== VyOS Build Upstream Sync Script =====${NC}"
echo -e "${BLUE}This script will sync your fork with the upstream VyOS repository${NC}"
echo

# Ensure we're in the right directory
if [ ! -d ".git" ]; then
  echo -e "${RED}Error: Not in a git repository. Please run this script from the root of your vyos-build repository.${NC}"
  exit 1
fi

# Check if we're on the branch we want to update (default: current)
TARGET_BRANCH=${1:-current}
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  echo -e "${YELLOW}You are not on the '$TARGET_BRANCH' branch. Current branch: $CURRENT_BRANCH${NC}"
  read -p "Do you want to checkout the '$TARGET_BRANCH' branch? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git checkout "$TARGET_BRANCH"
  else
    echo -e "${YELLOW}Continuing with branch '$CURRENT_BRANCH'...${NC}"
    TARGET_BRANCH=$CURRENT_BRANCH
  fi
fi

# Save any uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo -e "${YELLOW}You have uncommitted changes.${NC}"
  read -p "Do you want to stash these changes before proceeding? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git stash save "Auto-stashed before running sync-upstream.sh"
    STASHED=true
  else
    echo -e "${YELLOW}Continuing with uncommitted changes. This may cause conflicts.${NC}"
  fi
fi

# Check if upstream remote exists, add it if not
if ! git remote | grep -q "upstream"; then
  echo -e "${GREEN}Adding upstream remote...${NC}"
  git remote add upstream https://github.com/vyos/vyos-build.git
else
  echo -e "${GREEN}Upstream remote already exists.${NC}"
fi

# Fetch the latest changes from upstream
echo -e "${GREEN}Fetching upstream changes...${NC}"
git fetch upstream

# Check if there are any upstream changes
LOCAL_COMMIT=$(git rev-parse HEAD)
UPSTREAM_COMMIT=$(git rev-parse upstream/$TARGET_BRANCH)

if [ "$LOCAL_COMMIT" == "$UPSTREAM_COMMIT" ]; then
  echo -e "${GREEN}Your branch is already up to date with upstream/$TARGET_BRANCH!${NC}"
else
  echo -e "${GREEN}New changes are available from upstream.${NC}"
  
  # Ask if user wants to review changes before merging
  read -p "Do you want to see what changes will be merged? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git log --oneline --graph --date=short --pretty=format:"%C(auto)%h%d %s %C(green)(%cr) %C(bold blue)<%an>" HEAD..upstream/$TARGET_BRANCH
    echo
  fi
  
  # Ask if user wants to merge with a chance to review
  read -p "Would you like to merge with manual review (y) or auto-commit (n)? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Merging upstream changes without committing (for review)...${NC}"
    git merge upstream/$TARGET_BRANCH --no-commit
    
    echo -e "${YELLOW}Changes have been merged but not committed.${NC}"
    echo -e "${YELLOW}Review the changes with 'git status' and then commit with:${NC}"
    echo -e "${YELLOW}git commit -m \"Merge upstream changes from vyos/vyos-build $TARGET_BRANCH branch\"${NC}"
  else
    echo -e "${GREEN}Auto-merging and committing upstream changes...${NC}"
    git merge upstream/$TARGET_BRANCH -m "Merge upstream changes from vyos/vyos-build $TARGET_BRANCH branch"
    echo -e "${GREEN}Changes have been merged and committed.${NC}"
  fi
fi

# Restore stashed changes if we stashed them
if [ "${STASHED:-false}" == "true" ]; then
  echo -e "${GREEN}Restoring your stashed changes...${NC}"
  git stash pop
fi

echo
echo -e "${BLUE}===== Sync Complete =====${NC}"
echo -e "${GREEN}You may want to push these changes to your origin remote with:${NC}"
echo -e "${YELLOW}git push origin $TARGET_BRANCH${NC}"
