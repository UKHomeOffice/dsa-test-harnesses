import json
import os
import random
import signal
import socket
import string
import time
import uuid
from dataclasses import dataclass
from typing import Any, Dict, Optional

from kafka import KafkaProducer
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider


# -----------------------------
# Config
# -----------------------------
TOPIC = os.getenv("TOPIC", "roro_location_cmd")
BOOTSTRAP_SERVERS = os.getenv("BOOTSTRAP_SERVERS")  # comma-separated, include ports
AWS_REGION = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "eu-west-2"

# Message rate controls
MESSAGES_PER_SEC = float(os.getenv("MESSAGES_PER_SEC", "10"))  # total rate
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "1"))  # how many messages per loop iteration
NULL_PROB = float(os.getenv("NULL_PROB", "0.35"))  # probability union fields choose null

# Producer tuning
ACKS = os.getenv("ACKS", "all")
LINGER_MS = int(os.getenv("LINGER_MS", "20"))
RETRIES = int(os.getenv("RETRIES", "10"))
COMPRESSION = os.getenv("COMPRESSION", "snappy")  # snappy|gzip|lz4|zstd|none
MAX_REQUEST_SIZE = int(os.getenv("MAX_REQUEST_SIZE", str(2 * 1024 * 1024)))  # 2MB


if not BOOTSTRAP_SERVERS:
    raise SystemExit(
        "Missing BOOTSTRAP_SERVERS env var (comma-separated, e.g. b-1...:9098,b-2...:9098)."
    )


# -----------------------------
# IAM OAUTHBEARER token provider
# -----------------------------
class MSKOAuthTokenProvider(AbstractTokenProvider):
    """
    kafka-python calls token() to get an OAUTHBEARER token.
    aws-msk-iam-sasl-signer-python generates an IAM auth token for MSK.
    """

    def token(self) -> str:
        # Hostname is required for signing context; AWS examples often use socket.gethostname()
        # but any stable host id works. We'll use hostname.
        token, _expiry_ms = MSKAuthTokenProvider.generate_auth_token(
            region=AWS_REGION, aws_debug_creds=False
        )
        return token


# -----------------------------
# Synthetic data generator (shape matches your Avro schema)
# -----------------------------
CMD_TYPES = [
    "DELETE_LOCATION_CMD",
    "MAP_LOCATION_CMD",
    "MERGE_LOCATION_CMD",
    "MATCH_LOCATION_CMD",
    "MAPABP_LOCATION_CMD",
]

IDENTITY_TYPES = ["UNKNOWN", "P", "O", "L", "E", "S", "R"]
VALUE_TYPE_CODES = ["UNKNOWN", "BYTES", "STRING", "INT", "LONG", "DOUBLE", "FLOAT", "BOOL", "MAP"]


def now_millis() -> int:
    return int(time.time() * 1000)


def rand_str(n: int) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(random.choice(alphabet) for _ in range(n))


def maybe_null(value_fn, p_null: float = NULL_PROB):
    return None if random.random() < p_null else value_fn()


def rand_float(min_v: float, max_v: float) -> float:
    return float(min_v + (max_v - min_v) * random.random())


def rand_postcode_ukish() -> str:
    # Not perfect, just plausible-ish
    return f"{random.choice(string.ascii_uppercase)}{random.randint(1, 9)}{random.choice(string.ascii_uppercase)} {random.randint(1,9)}{random.choice(string.ascii_uppercase)}{random.choice(string.ascii_uppercase)}"


def make_pole_v2_id() -> str:
    # Your doc says format like <data_source>:<P|E|S>=<identifier>,<O|L>=<child_identifier>
    data_source = random.choice(["PCDP", "CRM", "MDM", "LEGACY", "EXT"])
    root_type = random.choice(["P", "E", "S"])
    child_type = random.choice(["O", "L"])
    return f"{data_source}:{root_type}={uuid.uuid4().hex[:12]},{child_type}={uuid.uuid4().hex[:8]}"


def make_identity_record() -> Dict[str, Any]:
    return {
        "poleId": {
            "v2": {"id": make_pole_v2_id()},
            "v1": maybe_null(lambda: {"id": random.randint(1_000_000, 9_999_999)}),
        },
        "type": random.choice(IDENTITY_TYPES),
    }


def make_source_audit() -> Dict[str, Any]:
    return {
        "createdBy": maybe_null(lambda: random.choice(["system", "etl", "user", "ingest"])),
        "createdTimestamp": maybe_null(lambda: now_millis() - random.randint(0, 30) * 86400_000),
        "updatedBy": maybe_null(lambda: random.choice(["system", "etl", "user", "ingest"])),
        "updatedTimestamp": maybe_null(lambda: now_millis() - random.randint(0, 7) * 86400_000),
        "deletedBy": maybe_null(lambda: random.choice(["system", "etl"])),
        "deletedTimestamp": maybe_null(lambda: now_millis() - random.randint(0, 90) * 86400_000),
    }


def make_source_record() -> Dict[str, Any]:
    return {
        "name": random.choice(["PCDP", "CRM", "MDM", "UNKNOWN"]),
        "shortName": maybe_null(lambda: random.choice(["PCDP", "CRM", "MDM"])),
        "location": maybe_null(lambda: random.choice(["s3://bucket/path/file.json", "table://db.schema.table"])),
        "id": maybe_null(lambda: uuid.uuid4().hex),
        "audit": make_source_audit(),
    }


def make_compliance_record() -> Dict[str, Any]:
    return {
        "visibility": random.choice(["UNKNOWN", "INTERNAL", "RESTRICTED", "PUBLIC"]),
        "gscMarker": maybe_null(lambda: random.choice(["OFFICIAL", "OFFICIAL-SENSITIVE"])),
        "retentionMarkerDays": random.choice([-1, 30, 90, 365, 730]),
    }


def make_mapping_record() -> Dict[str, Any]:
    return {
        "name": random.choice(["UNKNOWN", "pole-map", "loc-map", "address-map"]),
        "version": maybe_null(lambda: random.choice(["v1", "v2", "2025.10", "2026.01"])),
    }


def make_metadata_record() -> Dict[str, Any]:
    return {
        "identityRecord": make_identity_record(),
        "sourceRecord": maybe_null(make_source_record),
        "complianceRecord": maybe_null(make_compliance_record),
        "mappingRecord": maybe_null(make_mapping_record),
    }


def make_location_address() -> Dict[str, Any]:
    lat = maybe_null(lambda: rand_float(50.0, 58.5))
    lon = maybe_null(lambda: rand_float(-6.5, 1.8))
    return {
        "type": random.choice(["UNKNOWN", "ADDRESS"]),
        "postCode": maybe_null(rand_postcode_ukish),
        "poBox": maybe_null(lambda: f"PO Box {random.randint(1, 999)}"),
        "fullAddress": maybe_null(lambda: f"{random.randint(1, 200)} {random.choice(['High St','Station Rd','Main St','Church Ln'])}, {random.choice(['London','Manchester','Bristol','Leeds'])}"),
        "name": maybe_null(lambda: random.choice(["The Willows", "Rose Cottage", "Acme HQ"])),
        "siteLocation": maybe_null(lambda: random.choice(["Flat 2", "Floor 3", "Unit 7"])),
        "number": maybe_null(lambda: str(random.randint(1, 250))),
        "street": maybe_null(lambda: random.choice(["High Street", "Station Road", "Kingsway", "Mill Lane"])),
        "town": maybe_null(lambda: random.choice(["London", "Bristol", "Leeds", "Glasgow"])),
        "area": maybe_null(lambda: random.choice(["City Centre", "West End", "Docklands"])),
        "district": maybe_null(lambda: random.choice(["Camden", "Islington", "Southwark"])),
        "county": maybe_null(lambda: random.choice(["Greater London", "West Yorkshire", "Lancashire"])),
        "country": maybe_null(lambda: random.choice(["UK", "GB", "United Kingdom"])),
        "uniquePropertyReferenceNumber": maybe_null(lambda: random.randint(10_000_000, 99_999_999)),
        "latitude": lat,
        "longitude": lon,
    }


def make_location_contact() -> Dict[str, Any]:
    return {
        "type": random.choice(["UNKNOWN", "EMAIL", "PHONE"]),
        "value": maybe_null(lambda: random.choice([f"{rand_str(6).lower()}@example.com", f"+44{random.randint(7000000000, 7999999999)}"])),
    }


def make_location_virtual() -> Dict[str, Any]:
    return {
        "type": random.choice(["UNKNOWN", "IPV4", "URL"]),
        "value": maybe_null(lambda: random.choice([f"{random.randint(1,255)}.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(1,254)}", f"https://{rand_str(8).lower()}.example.com"])),
    }


def make_location_area() -> Dict[str, Any]:
    return {
        "type": random.choice(["UNKNOWN", "AREA"]),
        "name": maybe_null(lambda: random.choice(["corner of A & B", "industrial estate", "near station"])),
        "code": maybe_null(lambda: rand_str(6).upper()),
        "latitude": maybe_null(lambda: rand_float(50.0, 58.5)),
        "longitude": maybe_null(lambda: rand_float(-6.5, 1.8)),
    }


def make_location_place() -> Dict[str, Any]:
    return {
        "type": random.choice(["UNKNOWN", "PLACE"]),
        "name": maybe_null(lambda: random.choice(["Warehouse 12", "Depot", "Head Office"])),
        "code": maybe_null(lambda: rand_str(8).upper()),
        "latitude": maybe_null(lambda: rand_float(50.0, 58.5)),
        "longitude": maybe_null(lambda: rand_float(-6.5, 1.8)),
    }


def make_attributes_record() -> Dict[str, Any]:
    # map<string,string>
    m = {}
    for _ in range(random.randint(1, 6)):
        m[random.choice(["sourceSystem", "confidence", "segment", "category", "note", "flag"]) + "_" + rand_str(3)] = rand_str(
            random.randint(4, 16)
        )
    return {"attrs": m}


def make_matching_record() -> Dict[str, Any]:
    return {
        "svxId": maybe_null(lambda: random.randint(1_000_000, 99_999_999)),
        "matchConfirmed": maybe_null(lambda: random.choice([True, False])),
        "selfScore": maybe_null(lambda: random.randint(0, 100)),
        "matchScore": maybe_null(lambda: random.randint(0, 100)),
        "version": maybe_null(lambda: random.randint(1, 10)),
        "timestamp": maybe_null(lambda: now_millis() - random.randint(0, 30) * 86400_000),
        "matchChangeType": maybe_null(lambda: random.choice(["BXM_SVP_PER", "BXM_SVO_ORG", "LIVE"])),
    }


def make_features_record() -> Dict[str, Any]:
    feats = {}
    for _ in range(random.randint(0, 5)):
        feat_key = random.choice(["risk", "score", "tag", "meta", "quality"]) + "_" + rand_str(4).lower()
        value_type = random.choice(VALUE_TYPE_CODES)
        # Keep "value" aligned with "valueType" loosely
        if value_type == "STRING":
            value = rand_str(random.randint(4, 18))
        elif value_type == "INT":
            value = random.randint(0, 1000)
        elif value_type == "LONG":
            value = random.randint(0, 10_000_000)
        elif value_type == "DOUBLE":
            value = float(random.randint(0, 10000)) / 100.0
        elif value_type == "FLOAT":
            value = rand_float(0.0, 100.0)
        elif value_type == "BOOL":
            value = random.choice([True, False])
        elif value_type == "MAP":
            value = {"k": rand_str(6), "v": rand_str(6)}
        elif value_type == "BYTES":
            # represent bytes as base64-ish string in JSON
            value = rand_str(12)
        else:
            value = None

        feats[feat_key] = {
            "id": maybe_null(lambda: uuid.uuid4().hex),
            "type": maybe_null(lambda: random.choice(["UNKNOWN", "DERIVED", "SOURCE"])),
            "valueType": value_type,
            "value": value,
            "valueList": None,
            "startTimestamp": maybe_null(lambda: now_millis() - random.randint(0, 365) * 86400_000),
            "endTimestamp": maybe_null(lambda: now_millis() + random.randint(0, 365) * 86400_000),
        }

    return {"feats": feats}


def make_location_record() -> Dict[str, Any]:
    # Choose which sub-record is populated based on location "type"
    loc_type = random.choice(["UNKNOWN", "ADDRESS", "CONTACT", "VIRTUAL", "AREA", "PLACE"])

    address = None
    contact = None
    virtual = None
    area = None
    place = None

    if loc_type == "ADDRESS":
        address = make_location_address()
    elif loc_type == "CONTACT":
        contact = make_location_contact()
    elif loc_type == "VIRTUAL":
        virtual = make_location_virtual()
    elif loc_type == "AREA":
        area = make_location_area()
    elif loc_type == "PLACE":
        place = make_location_place()
    else:
        # sometimes still include something
        if random.random() < 0.2:
            address = make_location_address()

    return {
        "metadata": make_metadata_record(),
        "type": loc_type,
        "party": make_identity_record(),  # IdentityRecord reference
        "role": random.choice(["UNKNOWN", "REGISTERED", "BILLING", "PRIMARY"]),
        "startTimestamp": maybe_null(lambda: now_millis() - random.randint(0, 3650) * 86400_000),
        "endTimestamp": maybe_null(lambda: now_millis() + random.randint(0, 3650) * 86400_000),
        "address": address,
        "contact": contact,
        "virtual": virtual,
        "area": area,
        "place": place,
        "attributes": maybe_null(make_attributes_record),
        "matching": maybe_null(make_matching_record),
        "features": maybe_null(make_features_record),
    }


def make_cmd_location_pole_record() -> Dict[str, Any]:
    return {
        "cmdType": random.choice(CMD_TYPES),
        "cmdCreationTimestamp": now_millis(),
        "adaptorName": random.choice(["roro-adaptor", "location-adaptor", "cmd-gen"]),
        "adaptorVersion": random.choice(["1.0.0", "1.1.0", "2.0.3", "2026.01"]),
        "locationRecord": maybe_null(make_location_record),
        "matchingRecord": maybe_null(make_matching_record),
    }


# -----------------------------
# Producer loop
# -----------------------------
RUNNING = True


def handle_stop(_signum, _frame):
    global RUNNING
    RUNNING = False


signal.signal(signal.SIGINT, handle_stop)
signal.signal(signal.SIGTERM, handle_stop)


def build_producer() -> KafkaProducer:
    # kafka-python IAM config per AWS docs uses SASL_SSL + OAUTHBEARER token provider :contentReference[oaicite:2]{index=2}
    return KafkaProducer(
        bootstrap_servers=[s.strip() for s in BOOTSTRAP_SERVERS.split(",") if s.strip()],
        security_protocol="SASL_SSL",
        sasl_mechanism="OAUTHBEARER",
        sasl_oauth_token_provider=MSKOAuthTokenProvider(),
        client_id=os.getenv("CLIENT_ID", f"cmd-location-gen-{socket.gethostname()}"),
        acks=ACKS,
        linger_ms=LINGER_MS,
        retries=RETRIES,
        compression_type=None if COMPRESSION.lower() == "none" else COMPRESSION,
        max_request_size=MAX_REQUEST_SIZE,
        value_serializer=lambda v: json.dumps(v, separators=(",", ":"), ensure_ascii=False).encode("utf-8"),
        key_serializer=lambda k: k.encode("utf-8") if isinstance(k, str) else k,
    )


def main():
    producer = build_producer()

    # Rate limiting
    interval = 1.0 / MESSAGES_PER_SEC if MESSAGES_PER_SEC > 0 else 0.0
    last_log = time.time()
    sent = 0

    while RUNNING:
        loop_start = time.time()

        for _ in range(BATCH_SIZE):
            record = make_cmd_location_pole_record()

            # Keying: use pole v2 id when available; otherwise random uuid
            key = None
            try:
                if record.get("locationRecord") and record["locationRecord"]["metadata"]["identityRecord"]["poleId"]["v2"]["id"]:
                    key = record["locationRecord"]["metadata"]["identityRecord"]["poleId"]["v2"]["id"]
            except Exception:
                key = None
            if not key:
                key = uuid.uuid4().hex

            producer.send(TOPIC, key=key, value=record)
            sent += 1

        # Serve delivery callbacks / IO
        producer.poll(0)

        # Simple periodic flush to keep memory bounded (tune/disable for higher throughput)
        if sent % 5000 == 0:
            producer.flush(timeout=10)

        # Log every ~5s
        now = time.time()
        if now - last_log >= 5:
            print(
                json.dumps(
                    {
                        "ts": int(now),
                        "topic": TOPIC,
                        "sent_total": sent,
                        "rate_target_mps": MESSAGES_PER_SEC,
                        "batch_size": BATCH_SIZE,
                    }
                )
            )
            last_log = now

        # sleep to meet target rate (roughly)
        if interval > 0:
            elapsed = time.time() - loop_start
            sleep_for = max(0.0, (interval * BATCH_SIZE) - elapsed)
            if sleep_for > 0:
                time.sleep(sleep_for)

    print("Stopping: flushing producer...")
    producer.flush(timeout=30)
    producer.close()
    print("Stopped.")


if __name__ == "__main__":
    main()
