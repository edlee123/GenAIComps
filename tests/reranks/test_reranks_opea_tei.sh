#!/bin/bash
# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -x

WORKPATH=$(dirname "$PWD")
ip_address=$(hostname -I | awk '{print $1}')

function build_docker_images() {
    cd $WORKPATH
    docker build --no-cache -t opea/reranking:comps --build-arg https_proxy=$https_proxy --build-arg http_proxy=$http_proxy -f comps/reranks/src/Dockerfile .
    if [ $? -ne 0 ]; then
        echo "opea/reranking built fail"
        exit 1
    else
        echo "opea/reranking built successful"
    fi
}

function start_service() {
    tei_endpoint=5006
    # Remember to set HF_TOKEN before invoking this test!
    export HF_TOKEN=${HF_TOKEN}
    model=BAAI/bge-reranker-base
    revision=refs/pr/4
    volume=$PWD/data
    docker run -d --name="test-comps-reranking-endpoint" -p $tei_endpoint:80 -v $volume:/data -e http_proxy=$http_proxy -e https_proxy=$https_proxy --pull always ghcr.io/huggingface/text-embeddings-inference:cpu-1.5 --model-id $model
    sleep 3m
    export TEI_RERANKING_ENDPOINT="http://${ip_address}:${tei_endpoint}"
    tei_service_port=5007
    unset http_proxy
    docker run -d --name="test-comps-reranking-server" -e LOGFLAG=True  -p ${tei_service_port}:8000 --ipc=host -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e TEI_RERANKING_ENDPOINT=$TEI_RERANKING_ENDPOINT -e HF_TOKEN=$HF_TOKEN -e RERANK_TYPE="tei" opea/reranking:comps
    sleep 15
}

function validate_microservice() {
    tei_service_port=5007
    local CONTENT=$(curl http://${ip_address}:${tei_service_port}/v1/reranking \
        -X POST \
        -d '{"initial_query":"What is Deep Learning?", "retrieved_docs": [{"text":"Deep Learning is not..."}, {"text":"Deep learning is..."}]}' \
        -H 'Content-Type: application/json')

    if echo "$CONTENT" | grep -q "documents"; then
        echo "Content is as expected."
    else
        echo "Content does not match the expected result: $CONTENT"
        docker logs test-comps-reranking-server
        docker logs test-comps-reranking-endpoint
        exit 1
    fi
}

function stop_docker() {
    cid=$(docker ps -aq --filter "name=test-comps-rerank*")
    if [[ ! -z "$cid" ]]; then docker stop $cid && docker rm $cid && sleep 1s; fi
}

function main() {

    stop_docker

    build_docker_images
    start_service

    validate_microservice

    stop_docker
    echo y | docker system prune

}

main
