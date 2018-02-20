set -e

# Performs a GitHub API call
#
# The first argument is the method to use, the second is the URI (like
# /repos"). The third argument is optional and it should contain a GitHub OAuth
# token if auth is needed by the request. Alternatively the token will be taken
# from the environment variable "$GITHUB_OAUTH_TOKEN" if not present as an
# argument.
#
# If there is input in stdin, then it will be sent as HTTP payload in the
# request.
github_api()
{
    method=$1
    uri=$2
    token=${3:-${GITHUB_OAUTH_TOKEN}}

    # Use \n as argument separator to avoid problems with spaces
    curl_args="-X\n$method\n-H\nContent-Type:application/json"

    # If we have a token, use it
    if test -n "${token:-}"
    then
        curl_args="$curl_args\n-H\nAuthorization: token $token"
    fi

    # If we have data via stdin, send it as the request data
    data_file=$(mktemp)
    cat > "$data_file"
    if test -s "$data_file"
    then
        curl_args="$curl_args\n-d\n@$data_file"
        ( set -x; cat "$data_file" )
    fi

    curl_args="$curl_args\nhttps://api.github.com$uri"

    # Send the request
    printf -- "$curl_args" | xargs -d'\n' curl

    # Remove temporary data file
    rm -f "$data_file"
}

# Commit the changes and tag
git config user.name "$(git for-each-ref --format="%(taggername)" \
        refs/tags/$CIRCLE_TAG)"
git config user.email "$(git for-each-ref --format="%(taggeremail)" \
        refs/tags/$CIRCLE_TAG)"
git commit --no-verify -a -m 'Auto-convert to D2'

# Convert git-based repo url into org/proj string
PROJECT=$(echo $CIRCLE_REPOSITORY_URL | sed -n 's|git@github.com:\(.\+\).git$|\1|p')
PROJECT_URL="https://github.com/$PROJECT"

# Create the new tag
d2tag="$CIRCLE_TAG+d2"
cat <<EOM | git tag -F- "$d2tag"
$CIRCLE_TAG auto-converted to D2

See $PROJECT_URL/releases/tag/$CIRCLE_TAG for
a complete changelog.
EOM

# Push (making sure the credentials are not leaked and using a helper
# to get the password)
git push -q "https://$GITHUB_OAUTH_TOKEN@github.com/$PROJECT.git" "$d2tag"

# Create GitHub release
cat <<EOT | github_api POST "/repos/$PROJECT/releases"
{
  "tag_name": "${d2tag}",
  "name": "$CIRCLE_TAG auto-converted to D2",
  "body": "See $PROJECT_URL/releases/tag/$CIRCLE_TAG",
  "draft": false,
  "prerelease": $(if echo "$CIRCLE_TAG" | grep -q -- '-'; then
                    echo true; else echo false; fi)
}
EOT
