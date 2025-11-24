#!/bin/bash

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
        "text": ("*" + .file + "*\n• Revision: `" + (.revision // "unknown") + "`\n• Architectures: " + ((.architectures // []) | if type == "array" then join(", ") else . end))
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
