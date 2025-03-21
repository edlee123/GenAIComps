#!/bin/bash

# Set up text generation service

WORKPATH=$(git rev-parse --show-toplevel)
host_ip=$(hostname -I | awk '{print $1}')
TEXTGEN_PORT=9000 # This port is for the textgen service

set -x # Enable tracing

# Check environment variables
if [ -z "${LLM_MODEL_ID:-}" ]; then
  echo "Error: LLM_MODEL_ID environment variable is not set."
  exit 1
fi

if [ -z "${LLM_ENDPOINT:-}" ]; then
  echo "Error: LLM_ENDPOINT environment variable is not set."
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "Error: OPENAI_API_KEY environment variable is not set."
  exit 1
fi

# Start text generation service (adapted from the example script)
# We will NOT start a textgen service, but instead use environment variables
# to point to an existing one.
function start_textgen() {
    export service_name="textgen-service-endpoint-openai" # Use the vLLM-based service
    export LOGFLAG=True

    docker compose -f $WORKPATH/comps/llms/deployment/docker_compose/compose_text-generation.yaml up ${service_name} -d

    if [ ! -f "compose_text-generation.yaml" ]; then
        echo "Error: compose_text-generation.yaml not found in $PWD"
        exit 1
    fi

}

set +x # Disable tracing
start_textgen
