import logging
import os
import urllib.parse
import json
import boto3
import pyarrow as pa
import pyarrow.parquet as pq
from botocore.exceptions import ClientError
from transform import converter

# Initialize boto3 client outside the handler
s3_client = boto3.client(
    service_name='s3',
    aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
    region_name=os.environ['AWS_REGION'],
    endpoint_url='http://s3.ninja:9000',
)

def get_events(bucket: str, key: str) -> list:
    """
    Retrieve events from S3 object.
    """
    logging.info(f"Reading {key}.")
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        data = response['Body'].read().decode('utf-8')
        return data.splitlines()
    except ClientError as e:
        logging.error(f"Failed to read S3 object {key} from bucket {bucket}: {e}")
        return []

def transform_events_to_ocsf(events: list) -> list:
    """
    Transform Wazuh security events to OCSF format.
    """
    logging.info("Transforming Wazuh security events to OCSF.")
    ocsf_events = []
    for line in events:
        try:
            event = converter.from_json(line)  # Assuming this function exists
            ocsf_event = converter.to_detection_finding(event).model_dump()
            ocsf_events.append(ocsf_event)
        except (AttributeError, json.JSONDecodeError) as e:
            logging.error(f"Error transforming line to OCSF: {e}")
    return ocsf_events

def write_parquet_file(ocsf_events: list, filename: str) -> None:
    """
    Write OCSF events to a Parquet file.
    """
    table = pa.Table.from_pydict({'events': ocsf_events})
    pq.write_table(table, filename, compression='ZSTD')

def upload_to_s3(bucket: str, key: str, filename: str) -> bool:
    """
    Upload a file to S3 bucket.
    """
    logging.info(f"Uploading data to {bucket}.")
    try:
        with open(filename, 'rb') as data:
            s3_client.put_object(Bucket=bucket, Key=key, Body=data)
        return True
    except ClientError as e:
        logging.error(f"Failed to upload file {filename} to bucket {bucket}: {e}")
        return False

def lambda_handler(event, context):
    logging.basicConfig(filename='/tmp/lambda.log', encoding='utf-8', level=logging.DEBUG)

    # Extract bucket and key from S3 event
    src_bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    dst_bucket = os.environ['AWS_BUCKET']
    logging.info(f"Lambda function invoked due to {key}.")
    logging.info(f"Source bucket name is {src_bucket}. Destination bucket is {dst_bucket}.")

    # Read events from source S3 bucket
    raw_events = get_events(src_bucket, key)

    # Transform events to OCSF format
    ocsf_events = transform_events_to_ocsf(raw_events)

    # Write OCSF events to Parquet file
    tmp_filename = '/tmp/tmp.parquet'
    write_parquet_file(ocsf_events, tmp_filename)

    # Upload Parquet file to destination S3 bucket
    parquet_key = key.replace('.txt', '.parquet')
    upload_success = upload_to_s3(dst_bucket, parquet_key, tmp_filename)

    # Clean up temporary file
    os.remove(tmp_filename)

    # Prepare response
    response = {
        'size': len(raw_events),
        'upload_success': upload_success
    }
    return json.dumps(response)
