
#!/usr/bin/env bash

comment_issue() {

  local BODY="$1"

  gh issue comment "$ISSUE_NUMBER" \
    --body "$BODY"
}
