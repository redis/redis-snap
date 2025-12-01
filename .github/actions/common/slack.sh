#!/bin/bash


# Send a Slack message using Bot Token API
# Reads JSON message from stdin, sends to Slack API
# Usage: slack_send_with_token "$SLACK_BOT_TOKEN" < message.json
slack_send_with_token() {
  set -x
  local token="$1"
  local curl_stderr=$(mktemp)

  # Run curl with verbose output, stderr to curl_stderr
  if ! curl --fail-with-body -v -X POST https://api.slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d @- 2>"$curl_stderr"; then
    # If curl failed, output the error log
    echo "curl command failed. Error log:" >&2
    cat "$curl_stderr" >&2
    rm -f "$curl_stderr"
    return 1
  fi

  rm -f "$curl_stderr"
  return 0
}

# Handle Slack API response and extract message metadata
# Reads JSON response from stdin
# If GITHUB_OUTPUT is set, writes slack_ts and slack_url to it
# Usage: slack_handle_message_result "$SLACK_CHANNEL_ID" < response.json
slack_handle_message_result() {
  set -x
  local channel_id="$1"
  local message="$2"
  local response=$(cat)

  echo "Slack API Response:"

  # Check if successful
  if echo "$response" | jq -e '.ok == true' > /dev/null; then
    local slack_ts=$(echo "$response" | jq -r '.ts')
    local slack_channel=$(echo "$response" | jq -r '.channel')

    # Convert timestamp to URL format (remove dot)
    local ts_for_url=$(echo "$slack_ts" | tr -d '.')
    local slack_url="https://redis.slack.com/archives/${slack_channel}/p${ts_for_url}"

    # Write to GITHUB_OUTPUT if available
    if [ -n "$GITHUB_OUTPUT" ]; then
      echo "slack_ts=$slack_ts" >> "$GITHUB_OUTPUT"
      echo "slack_url=$slack_url" >> "$GITHUB_OUTPUT"
    fi

    echo "✅ Message sent successfully!"
    echo "Message URL: $slack_url"
    return 0
  else
    local error=$(echo "$response" | jq -r '.error // "unknown"')
    echo "❌ Failed to send Slack message: $error" >&2
    echo "$response" | jq '.'
    echo "Message content: $message" >&2
    return 1
  fi
}

slack_format_success_message() {
jq --arg channel "$1" --arg release_tag "$2" --arg footer "$3" --arg env "$4" '
{
  "channel": $channel,
  "icon_emoji": ":redis-circle:",
  "text": (":ubuntu: SNAP Packages Published for Redis: " + $release_tag + " (" + $env + ")"),
  "blocks": (
    [
      {
        "type": "header",
        "text": { "type": "plain_text", "text": (":ubuntu: SNAP Packages Published for Release " + $release_tag + " (" + $env + ")") }
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "The following packages have been published to https://snapcraft.io/redis"
        }
      }
    ] +
    map({
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": ("*" + .file + "* (revision: " + .revision + ")")
      }
    }) +
    [
      {
        "type": "context",
        "elements": [
          { "type": "mrkdwn", "text": $footer }
        ]
      }
    ]
  )
}'
}

slack_format_failure_message() {
    channel=$1
    header=$2
    workflow_url=$3
    footer=$4
    if [ -z "$header" ]; then
        header=" "
    fi
    if [ -z "$footer" ]; then
        footer=" "
    fi

# Create Slack message payload
    cat << EOF
{
"channel": "$channel",
"icon_emoji": ":redis-circle:",
"text": "$header",
"blocks": [
    {
    "type": "header",
    "text": {
        "type": "plain_text",
        "text": "❌  $header"
    }
    },
    {
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": "Workflow run: $workflow_url"
    }
    },
    {
    "type": "context",
    "elements": [
        {
        "type": "mrkdwn",
        "text": "$footer"
        }
    ]
    }
]
}
EOF
}
