#!/bin/bash

# Set up text generation service
# Run the following to set up before running script
# export LLM_MODEL_ID="google/gemini-2.0-pro-exp-02-05:free"
# export OPENAI_API_KEY=""
# export LLM_ENDPOINT=""

WORKPATH=$(dirname "$PWD")
host_ip=$(hostname -I | awk '{print $1}')
TEXTGEN_PORT=9000 # This port is for the textgen service

set -x # Enable tracing

# Start text generation service (adapted from the example script)
# We will NOT start a textgen service, but instead use environment variables
# to point to an existing one.
function start_textgen() {
    export service_name="textgen-service-endpoint-openai" # Use the vLLM-based service
    export LOGFLAG=True

    cd $WORKPATH/GenAIComps/comps/llms/deployment/docker_compose
    docker compose -f compose_text-generation.yaml up ${service_name} -d

    if [ ! -f "compose_text-generation.yaml" ]; then
        echo "Error: compose_text-generation.yaml not found in $PWD"
        exit 1
    fi

    sleep 30 # Wait for textgen service to start (increased from 20)
}