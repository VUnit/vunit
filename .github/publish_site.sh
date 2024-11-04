#!/usr/bin/env sh
#
# Usage: publish_site.sh [github.repository]
# If the repository is 'VUnit/vunit', GH_DEPKEY is required.
# Otherwise, the default token is used.

set -e

[ "x$1" = 'xVUnit/vunit' ] && isVUnit=1 || unset isVUnit

echo "isVUnit: $isVUnit"

cd $(dirname "$0")/../.tox/py313-docs/tmp/docsbuild/
touch .nojekyll
git init

if [ -z "${isVUnit+x}" ]; then
  cp ../../../../.git/config ./.git/config
fi

git add .
git config --local user.email "Pages@GitHubActions"
git config --local user.name "GitHub Actions"
git commit -a -m "update $GITHUB_SHA"

if [ -z "${isVUnit+x}" ]; then
  git push -u origin +HEAD:gh-pages
fi

if [ -n "${isVUnit+x}" ]; then
  git remote add origin git@github.com:VUnit/VUnit.github.io
  eval `ssh-agent -t 60 -s`
  echo "$GH_DEPKEY" | ssh-add -
  mkdir -p ~/.ssh/
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  git push -u origin +master
  ssh-agent -k
fi
