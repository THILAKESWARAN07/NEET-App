import re
from datetime import datetime, timezone
from uuid import uuid4

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from ..core.config import settings


def _slugify(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.strip())
    return cleaned.strip("-") or "file"


def _build_object_key(subject: str, original_filename: str) -> str:
    safe_subject = _slugify(subject).lower()
    safe_name = _slugify(original_filename)
    now = datetime.now(timezone.utc)
    date_part = now.strftime("%Y/%m/%d")
    return (
        f"{settings.STORAGE_OBJECT_PREFIX.strip('/')}/{safe_subject}/{date_part}/"
        f"{uuid4().hex}-{safe_name}"
    )


def upload_material_pdf(file_bytes: bytes, subject: str, original_filename: str) -> str:
    provider = settings.STORAGE_PROVIDER.lower().strip()

    if provider != "s3":
        raise ValueError(
            "Cloud storage is not configured. Set STORAGE_PROVIDER=s3 and related vars."
        )

    bucket = settings.STORAGE_BUCKET_NAME.strip()
    if not bucket:
        raise ValueError("Missing STORAGE_BUCKET_NAME for S3 upload.")

    object_key = _build_object_key(subject=subject, original_filename=original_filename)

    client_kwargs = {
        "region_name": settings.STORAGE_REGION.strip() or "us-east-1",
    }
    endpoint = settings.STORAGE_ENDPOINT_URL.strip()
    if endpoint:
        client_kwargs["endpoint_url"] = endpoint

    s3_client = boto3.client("s3", **client_kwargs)

    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=object_key,
            Body=file_bytes,
            ContentType="application/pdf",
        )
    except (BotoCoreError, ClientError) as exc:
        raise RuntimeError(f"Failed to upload file to cloud storage: {exc}") from exc

    if endpoint:
        return f"{endpoint.rstrip('/')}/{bucket}/{object_key}"

    region = settings.STORAGE_REGION.strip() or "us-east-1"
    return f"https://{bucket}.s3.{region}.amazonaws.com/{object_key}"
