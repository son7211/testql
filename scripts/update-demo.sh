#!/usr/bin/env bash

# Fail if no token
: ${GITHUB_TOKEN?"Please set environment variable GITHUB_TOKEN to the GitHub access token"}

# Getting the original content
git remote add baseline git@octodemo.com:baseline/reading-time-demo.git
git fetch baseline

# Resting our HEAD to golden repository
git checkout master
git reset --hard baseline/master

# Generating personal travis token
cp templates/.travis.yml ../
travis encrypt TOKEN=$GITHUB_TOKEN --add  -e https://travis.octodemo.com/api --debug
git commit -am "Adding my travis token after demo update"

# Updating master and our baseline to revert to later on
git push origin master:baseline -f
git push origin master -f

bash ./scripts/reset-demo.sh
