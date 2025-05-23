# Copyright (C) 2024 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import asyncio
import os
from collections import defaultdict, deque
from enum import Enum
from typing import Any, List, Optional, Type

from ..proto.docarray import TextDoc
from .constants import ServiceRoleType, ServiceType
from .http_service import HTTPService
from .logger import CustomLogger
from .utils import check_ports_availability

opea_microservices = {}

logger = CustomLogger("micro_service")
logflag = os.getenv("LOGFLAG", False)


class MicroService(HTTPService):
    """MicroService class to create a microservice."""

    def __init__(
        self,
        name: str = "",
        service_role: ServiceRoleType = ServiceRoleType.MICROSERVICE,
        service_type: ServiceType = ServiceType.LLM,
        protocol: str = "http",
        host: str = "localhost",
        port: int = 8080,
        api_key: str = None,
        ssl_keyfile: Optional[str] = None,
        ssl_certfile: Optional[str] = None,
        endpoint: Optional[str] = "/",
        input_datatype: Type[Any] = TextDoc,
        output_datatype: Type[Any] = TextDoc,
        provider: Optional[str] = None,
        provider_endpoint: Optional[str] = None,
        use_remote_service: Optional[bool] = False,
        description: Optional[str] = None,
        dynamic_batching: bool = False,
        dynamic_batching_timeout: int = 1,
        dynamic_batching_max_batch_size: int = 32,
    ):
        """Init the microservice."""
        self.service_role = service_role
        self.service_type = service_type
        self.protocol = protocol
        self.host = host
        self.port = port
        self.api_key = api_key
        self.endpoint = endpoint
        self.input_datatype = input_datatype
        self.output_datatype = output_datatype
        self.use_remote_service = use_remote_service
        self.description = description
        self.dynamic_batching = dynamic_batching
        self.dynamic_batching_timeout = dynamic_batching_timeout
        self.dynamic_batching_max_batch_size = dynamic_batching_max_batch_size
        self.uvicorn_kwargs = {}

        if ssl_keyfile:
            self.uvicorn_kwargs["ssl_keyfile"] = ssl_keyfile

        if ssl_certfile:
            self.uvicorn_kwargs["ssl_certfile"] = ssl_certfile

        if not use_remote_service:

            if self.protocol.lower() == "http":
                if not (check_ports_availability(self.host, self.port)):
                    raise RuntimeError(f"port:{self.port}")

            self.provider = provider
            self.provider_endpoint = provider_endpoint
            self.endpoints = []

            runtime_args = {
                "protocol": self.protocol,
                "host": self.host,
                "port": self.port,
                "title": name,
                "description": "OPEA Microservice Infrastructure",
            }

            super().__init__(uvicorn_kwargs=self.uvicorn_kwargs, runtime_args=runtime_args)

            # create a batch request processor loop if using dynamic batching
            if self.dynamic_batching:
                self.buffer_lock = asyncio.Lock()
                self.request_buffer = defaultdict(deque)
                self.add_startup_event(self._dynamic_batch_processor())

            self._async_setup()

        # overwrite name
        self.name = f"{name}/{self.__class__.__name__}" if name else self.__class__.__name__

    async def _dynamic_batch_processor(self):
        if logflag:
            logger.info("dynamic batch processor looping...")
        while True:
            await asyncio.sleep(self.dynamic_batching_timeout)
            runtime_batch: dict[Enum, list[dict]] = {}  # {ServiceType.Embedding: [{"request": xx, "response": yy}, {}]}

            async with self.buffer_lock:
                # prepare the runtime batch, access to buffer is locked
                if self.request_buffer:
                    for service_type, request_lst in self.request_buffer.items():
                        batch = []
                        # grab min(MAX_BATCH_SIZE, REQUEST_SIZE) requests from buffer
                        for _ in range(min(self.dynamic_batching_max_batch_size, len(request_lst))):
                            batch.append(request_lst.popleft())

                        runtime_batch[service_type] = batch

            # Run batched inference on the batch and set results
            for service_type, batch in runtime_batch.items():
                if not batch:
                    continue
                results = await self.dynamic_batching_infer(service_type, batch)

                for req, result in zip(batch, results):
                    req["response"].set_result(result)

    async def dynamic_batching_infer(self, service_type: Enum, batch: list[dict]):
        """Need to implement."""
        raise NotImplementedError("Unimplemented dynamic batching inference!")

    def _validate_env(self):
        """Check whether to use the microservice locally."""
        if self.use_remote_service:
            raise Exception(
                "Method not allowed for a remote service, please "
                "set use_remote_service to False if you want to use a local micro service!"
            )

    @property
    def endpoint_path(self):
        if self.api_key:
            return f"{self.host}{self.endpoint}"
        else:
            return f"{self.protocol}://{self.host}:{self.port}{self.endpoint}"

    @property
    def api_key_value(self):
        return self.api_key


def register_microservice(
    name: str,
    service_role: ServiceRoleType = ServiceRoleType.MICROSERVICE,
    service_type: ServiceType = ServiceType.UNDEFINED,
    protocol: str = "http",
    host: str = "localhost",
    port: int = 8080,
    ssl_keyfile: Optional[str] = None,
    ssl_certfile: Optional[str] = None,
    endpoint: Optional[str] = "/",
    input_datatype: Type[Any] = TextDoc,
    output_datatype: Type[Any] = TextDoc,
    provider: Optional[str] = None,
    provider_endpoint: Optional[str] = None,
    methods: List[str] = ["POST"],
    dynamic_batching: bool = False,
    dynamic_batching_timeout: int = 1,
    dynamic_batching_max_batch_size: int = 32,
):
    def decorator(func):
        if name not in opea_microservices:
            micro_service = MicroService(
                name=name,
                service_role=service_role,
                service_type=service_type,
                protocol=protocol,
                host=host,
                port=port,
                ssl_keyfile=ssl_keyfile,
                ssl_certfile=ssl_certfile,
                endpoint=endpoint,
                input_datatype=input_datatype,
                output_datatype=output_datatype,
                provider=provider,
                provider_endpoint=provider_endpoint,
                dynamic_batching=dynamic_batching,
                dynamic_batching_timeout=dynamic_batching_timeout,
                dynamic_batching_max_batch_size=dynamic_batching_max_batch_size,
            )
            opea_microservices[name] = micro_service
        opea_microservices[name].app.router.add_api_route(endpoint, func, methods=methods)

        return func

    return decorator
