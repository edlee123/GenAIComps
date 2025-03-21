#!/bin/bash

# Set up text generation service
# Run the following to set up before running script

# Require defining these environment variables before running the script
# export LLM_MODEL_ID="google/gemini-2.0-pro-exp-02-05:free"
# export OPENAI_API_KEY=""
# export LLM_ENDPOINT=""

WORKPATH=$(dirname "$PWD")
host_ip=$(hostname -I | awk '{print $1}')
TEXTGEN_PORT=9000 # This port is for the textgen service

set -x # Enable tracing

# --- Main script ---

# Check environment variables
if [ -z "${LLM_MODEL_ID:-}" ]; then
  echo "Error: LLM_MODEL_ID environment variable is not set."
  exit 1
fi

if [ -z "${LLM_ENDPOINT:-}" ]; then
  echo "Error: LLM_ENDPOINT environment variable is not set."
  exit 1
fi

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_readme_list>"
  echo "  where <path_to_readme_list> is a text file containing a list of README file paths."
  echo "Environment variables LLM_MODEL_ID and LLM_ENDPOINT must be set."
  exit 1
fi

# Read README file list
readme_files=$(cat "$1")

# Check if any files were found
if [ -z "$readme_files" ]; then
  echo "No README files found in $1. Exiting."
  exit 1
fi

# Create/clear output file
output_file="readme_review_summary.md"
> "$output_file"

# Iterate through README files
while IFS= read -r readme_file; do
  echo "Reviewing: $readme_file"

  # Read file contents
  readme_content=$(cat "$readme_file")

  # Escape special characters
  readme_content=${readme_content//\\/\\\\}
  readme_content=${readme_content//\"/\\\"}

  # Truncate content if it's too long. 10k characters should be enough.
  readme_content=${readme_content:0:10000}

  # Construct prompt - can modify this prompt as needed.
  prompt=$(cat <<-EOF
Please review the following README content for spelling and typo errors.
Summarize any errors found in a concise, bulleted list. If no errors are found, indicate that.

README Content:
$readme_content

EOF
)

  # Send request to text generation service
  response=$(curl -s -X POST http://${host_ip}:${TEXTGEN_PORT}/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer \$OPENAI_API_KEY" \
      -d @- <<EOF
{
  "model": "\$LLM_MODEL_ID",
  "messages": [
      {
          "role": "user",
          "content": "$prompt"
      }
  ],
  "stream": false
}
EOF
)
  # Extract generated text
  generated_text=$(echo "$response" | jq -r '.choices[0].message.content')

  # Write output to markdown file
  echo "## Review of $readme_file\n" >> "$output_file"
  echo "$generated_text\n" >> "$output_file"

  echo "Output written to $output_file"
done <<< "$readme_files"

echo "Review complete. Summary written to $output_file"
exit 0