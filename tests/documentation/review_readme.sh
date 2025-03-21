#!/bin/bash

# Instructions for use:
# 1. Define list of READMEs to review:
#
#    python3 find_readme.py --dir [path to GenAIComps] > readme_list.txt
#    # Please review this list that you'd like to review
#
#
# 2. Define LLM variables:
#
#    export LLM_ENDPOINT=""  # e.g. https://openrouter.ai/api
#    export OPENAI_API_KEY="" # key associated with LLM_ENDPOINT
#    export LLM_MODEL_ID=""  # e.g., "google/gemini-2.0-pro-exp-02-05:free"
#
# 3. Spin up OPEA Textgen service:
#
#    source start_doc_checking_llm.sh
#
# 4. Execute README Review Script:
#
#    source review_readme.sh readme_list.txt


# Prompt for reviewing README files
prompt=$(cat <<-EOF
Please review the following README content for spelling and typo errors.
Summarize any errors found in a concise, bulleted list. If no errors are found, indicate that.

README Content:
$readme_content

EOF
)


# Set up text generation service
# Run the following to set up before running script

# Require defining these environment variables before running the script
# export LLM_MODEL_ID="google/gemini-2.0-pro-exp-02-05:free"
# export OPENAI_API_KEY=""
# export LLM_ENDPOINT=""

WORKPATH=$(dirname "$PWD")
host_ip=$(hostname -I | awk '{print $1}')
TEXTGEN_PORT=9000 # This port is for the textgen service

# set -x # Enable tracing

# --- Main script ---

# Check environment variables
if [ -z "${LLM_MODEL_ID:-}" ]; then
  echo "Error: LLM_MODEL_ID environment variable is not set."
  exit 0
fi

if [ -z "${LLM_ENDPOINT:-}" ]; then
  echo "Error: LLM_ENDPOINT environment variable is not set."
  exit 0
fi

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path_to_readme_list>"
  echo "  where <path_to_readme_list> is a text file containing a list of README file paths."
  echo "Error: Please provide the &lt;path_to_readme_list&gt; argument."
  echo "Environment variables LLM_MODEL_ID and LLM_ENDPOINT must be set."
  exit 0
fi

# Read README file list
readme_files=$(cat "$1")

# Check if any files were found
if [ -z "$readme_files" ]; then
  echo "No README files found in $1. Exiting."
  exit 0
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

  # Extract token usage
  input_tokens=$(echo "$response" | jq -r '.usage.prompt_tokens')
  output_tokens=$(echo "$response" | jq -r '.usage.completion_tokens')
  total_tokens=$((input_tokens + output_tokens))

  # Write token usage to markdown file
  echo "Input Tokens: $input_tokens" >> "$output_file"
  echo "Output Tokens: $output_tokens" >> "$output_file"
  echo "Total Tokens: $total_tokens" >> "$output_file"
  echo "" >> "$output_file" # Add an empty line for separation

  echo "Output written to $output_file"
done <<< "$readme_files"

echo "Review complete. Summary written to $output_file"