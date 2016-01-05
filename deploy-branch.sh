echo "Travis Commit: $TRAVIS_COMMIT"
echo "Travis Branch: $TRAVIS_BRANCH"
echo "Travis repo: $TRAVIS_REPO_SLUG"

deployment_id=$(curl -s -H "Authorization: Token $TOKEN" -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"ref": "bas-patch-2","description": "Deploying branch to neverland", "environment": "development"}' https://octodemo.com/api/v3/repos/$TRAVIS_REPO_SLUG/deployments | jq '.id')

curl -H "Authorization: Token $TOKEN" -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"state": "pending","target_url": "https://travis.octodemo.com/$TRAVIS_REPO_SLUG","description": "Pending deployment to neverland"}' https://octodemo.com/api/v3/repos/$TRAVIS_REPO_SLUG/deployments/$deployment_id/statuses

sleep 10

curl -H "Authorization: Token $TOKEN" -s -H "Accept: application/json" -H "Content-type: application/json" -X POST -d '{"state": "success","target_url": "https://travis.octodemo.com/$TRAVIS_REPO_SLUG,"description": "Successful deployment to neverland"}' https://octodemo.com/api/v3/repos/$TRAVIS_REPO_SLUG/deployments/$deployment_id/statuses
