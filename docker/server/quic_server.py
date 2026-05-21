#!/usr/bin/env python3
"""
QUIC Echo Server for E2E Testing

A simple QUIC server using aioquic that:
- Accepts QUIC connections
- Handles stream data by echoing it back
- Supports ALPN negotiation (h3, hq-interop)
- Logs all events for debugging
"""

import argparse
import asyncio
import logging
from typing import Dict, Optional

from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import QuicConnection
from aioquic.quic.events import (
    ConnectionTerminated,
    HandshakeCompleted,
    StreamDataReceived,
    StreamReset,
)
from aioquic.quic.logger import QuicFileLogger

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class EchoServerProtocol(QuicConnectionProtocol):
    """QUIC protocol handler that echoes stream data back to the client."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._stream_buffers: Dict[int, bytes] = {}

    def quic_event_received(self, event) -> None:
        """Handle QUIC events."""
        if isinstance(event, HandshakeCompleted):
            logger.info(
                f"Handshake completed: alpn={event.alpn_protocol}, "
                f"early_data={event.early_data_accepted}"
            )

        elif isinstance(event, StreamDataReceived):
            stream_id = event.stream_id
            data = event.data
            end_stream = event.end_stream

            logger.info(
                f"Stream {stream_id}: received {len(data)} bytes, "
                f"end_stream={end_stream}"
            )

            # Accumulate data for this stream
            if stream_id not in self._stream_buffers:
                self._stream_buffers[stream_id] = b""
            self._stream_buffers[stream_id] += data

            # Echo back the data
            if end_stream or len(data) > 0:
                echo_data = self._stream_buffers.get(stream_id, b"")
                if echo_data:
                    logger.info(f"Stream {stream_id}: echoing {len(echo_data)} bytes")
                    self._quic.send_stream_data(stream_id, echo_data, end_stream=end_stream)
                    self._stream_buffers[stream_id] = b""

        elif isinstance(event, StreamReset):
            logger.info(f"Stream {event.stream_id} reset with error code {event.error_code}")
            # Clean up buffer for this stream
            self._stream_buffers.pop(event.stream_id, None)

        elif isinstance(event, ConnectionTerminated):
            logger.info(
                f"Connection terminated: error_code={event.error_code}, "
                f"frame_type={event.frame_type}, reason={event.reason_phrase}"
            )


async def main(
    host: str,
    port: int,
    certificate: str,
    private_key: str,
    secrets_log: Optional[str] = None,
    quic_log: Optional[str] = None,
) -> None:
    """Run the QUIC echo server."""

    # Configure QUIC
    configuration = QuicConfiguration(
        alpn_protocols=["h3", "hq-interop", "echo"],
        is_client=False,
        max_datagram_frame_size=65536,
    )

    # Load certificate and key
    configuration.load_cert_chain(certificate, private_key)

    # Optional: secrets log for Wireshark
    if secrets_log:
        configuration.secrets_log_file = open(secrets_log, "a")

    # Optional: QUIC event logger
    quic_logger = None
    if quic_log:
        quic_logger = QuicFileLogger(quic_log)

    logger.info(f"Starting QUIC server on {host}:{port}")
    logger.info(f"ALPN protocols: {configuration.alpn_protocols}")
    logger.info(f"Certificate: {certificate}")

    await serve(
        host,
        port,
        configuration=configuration,
        create_protocol=EchoServerProtocol,
        retry=False,  # Disabled for testing
    )

    logger.info("Server is running. Press Ctrl+C to stop.")
    await asyncio.Future()  # Run forever


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="QUIC Echo Server")
    parser.add_argument(
        "--host",
        type=str,
        default="0.0.0.0",
        help="Host to bind to (default: 0.0.0.0)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=4433,
        help="Port to bind to (default: 4433)",
    )
    parser.add_argument(
        "--cert",
        type=str,
        required=True,
        help="Path to TLS certificate",
    )
    parser.add_argument(
        "--key",
        type=str,
        required=True,
        help="Path to TLS private key",
    )
    parser.add_argument(
        "--secrets-log",
        type=str,
        help="Path to secrets log file (for Wireshark)",
    )
    parser.add_argument(
        "--quic-log",
        type=str,
        help="Path to QUIC event log directory",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        asyncio.run(
            main(
                host=args.host,
                port=args.port,
                certificate=args.cert,
                private_key=args.key,
                secrets_log=args.secrets_log,
                quic_log=args.quic_log,
            )
        )
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
