import json
import os
import socket
import ssl
import sys
import time
from datetime import datetime, timezone

from kafka import KafkaProducer
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import TopicAlreadyExistsError


BOOTSTRAP = os.getenv("BOOTSTRAP_SERVERS")  # Use IAM bootstrap brokers
REGION = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
TOPIC = os.getenv("TOPIC", "events")

INTERVAL_SECONDS = float(os.getenv("PRODUCE_INTERVAL_SECONDS", "1.0"))
ACKS = os.getenv("ACKS", "all")
RETRIES = int(os.getenv("RETRIES", "10"))
LINGER_MS = int(os.getenv("LINGER_MS", "20"))

_running = True


class MSKTokenProvider(AbstractTokenProvider):
    """
    kafka-python will call token() to fetch the OAUTHBEARER token.
    The signer uses the default AWS credential chain (perfect for ECS task roles).
    """
    def token(self) -> str:
        if not REGION:
            raise RuntimeError("AWS_REGION or AWS_DEFAULT_REGION must be set for MSK IAM auth token generation")
        token, _ = MSKAuthTokenProvider.generate_auth_token(REGION)
        return token


def ensure_topic(bootstrap_servers: str, topic: str, partitions: int = 3, replication_factor: int = 2):
    admin = KafkaAdminClient(
        bootstrap_servers=bootstrap_servers,
        security_protocol="SASL_SSL",
        sasl_mechanism="OAUTHBEARER",
        sasl_oauth_token_provider=MSKTokenProvider(),
        client_id="topic-init",
    )
    try:
        new_topic = NewTopic(
            name=topic,
            num_partitions=partitions,
            replication_factor=replication_factor,
        )
        admin.create_topics([new_topic], validate_only=False)
        print(f"Created topic: {topic}")
    except TopicAlreadyExistsError:
        print(f"Topic already exists: {topic}")
    finally:
        admin.close()


def handle_shutdown(signum, frame):
    global _running
    _running = False


def main():
    if not BOOTSTRAP:
        raise RuntimeError("BOOTSTRAP_SERVERS must be set (use IAM bootstrap brokers / port 9098).")

    print(f"MSK_BOOTSTRAP_SERVERS={BOOTSTRAP} ")

    host, port = BOOTSTRAP.split(",")[0].split(":")
    port = int(port)

    print("DNS:", socket.getaddrinfo(host, port))

    ctx = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=5) as sock:
        with ctx.wrap_socket(sock, server_hostname=host) as ssock:
            print("TLS OK:", ssock.version())

    producer = KafkaProducer(
        bootstrap_servers=BOOTSTRAP,
        security_protocol="SASL_SSL",
        sasl_mechanism="OAUTHBEARER",
        sasl_oauth_token_provider=MSKTokenProvider(),

        # Good defaults for producer behavior
        client_id=f"ecs-producer-{socket.gethostname()}",
        acks=ACKS,
        retries=RETRIES,
        linger_ms=LINGER_MS,

        # Serialize JSON payloads
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        key_serializer=lambda k: str(k).encode("utf-8"),
    )

    print(f"CREATED KAFKA PRODUCER ecs-producer-{socket.gethostname()} ")

    print(f"Checking Kafka Topic '${TOPIC}' exists, create if it doesn't ")
    ensure_topic(BOOTSTRAP, TOPIC)

    print(f"Writing to Kafka Topic: {TOPIC} ")

    i = 0
    try:
        while _running:
            payload = {
                "ts": datetime.now(timezone.utc).isoformat(),
                "message_id": i,
                "source": "ecs-fargate",
                "host": socket.gethostname(),
            }

            future = producer.send(TOPIC, key=i, value=payload)

            # Block briefly to surface errors early
            record_metadata = future.get(timeout=10)
            print(
                f"Produced to {record_metadata.topic} "
                f"partition={record_metadata.partition} offset={record_metadata.offset}"
            )

            i += 1
            time.sleep(INTERVAL_SECONDS)

    finally:
        # Flush outstanding messages before exit
        try:
            producer.flush(timeout=10)
        except Exception:
            pass
        producer.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Fatal: {e}", file=sys.stderr)
        sys.exit(1)
