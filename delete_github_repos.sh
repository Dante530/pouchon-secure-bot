#!/bin/bash

# Make sure gh CLI is installed and authenticated
if ! command -v gh &> /dev/null
then
    echo "GitHub CLI not found. Please install with 'pkg install gh -y' and run 'gh auth login'"
    exit 1
fi

echo "Fetching your GitHub repositories..."
repos=$(gh repo list $(gh auth status -t | grep 'Logged in to github.com as' | awk '{print $6}') --limit 100 --json name -q '.[].name')

if [ -z "$repos" ]; then
    echo "No repositories found."
    exit 0
fi

echo "Repositories to be deleted:"
echo "$repos"

# Confirm before deleting
read -p "Are you sure you want to delete ALL these repositories? Type YES to confirm: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Aborted."
    exit 0
fi

# Loop and delete each repository
for repo in $repos; do
    echo "Deleting $repo..."
    gh repo delete $(gh auth status -t | grep 'Logged in to github.com as' | awk '{print $6}')/$repo --confirm
done

echo "All repositories deleted. Local files remain untouched."
