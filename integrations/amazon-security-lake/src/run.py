#!/env/bin/python3
# vim: bkc=yes bk wb

import sys
import os
import datetime
import transform
import pyarrow as pa
import pyarrow.parquet as pq
import logging
import boto3
from botocore.exceptions import ClientError
import urllib.parse
import json

# NOTE work in progress
def upload_file(table, file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param table: PyArrow table with events data
    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then file_name is used
    :return: True if file was uploaded, else False
    """

    client = boto3.client(
        service_name='s3',
        aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
        region_name=os.environ['AWS_REGION'],
        endpoint_url='http://s3.ninja:9000',
    )

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = os.path.basename(file_name)

    # Upload the file
    try:
        client.put_object(Bucket=bucket, Key=file_name, Body=open(file_name, 'rb'))
    except ClientError as e:
        logging.error(e)
        return False
    return True


def main():
    '''Main function'''
    # Get current timestamp
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

    # Generate filenames
    filename_raw = f"/tmp/integrator-raw-{timestamp}.json"
    filename_ocsf = f"/tmp/integrator-ocsf-{timestamp}.json"
    filename_parquet = f"/tmp/integrator-ocsf-{timestamp}.parquet"

    # 1. Extract data
    #    ================
    raw_data = []
    for line in sys.stdin:
        raw_data.append(line)

        # Echo piped data
        with open(filename_raw, "a") as fd:
            fd.write(line)

    # 2. Transform data
    #    ================
    # a. Transform to OCSF
    ocsf_data = []
    for line in raw_data:
        try:
            event = transform.converter.from_json(line)
            ocsf_event = transform.converter.to_detection_finding(event)
            ocsf_data.append(ocsf_event.model_dump())

            # Temporal disk storage
            with open(filename_ocsf, "a") as fd:
                fd.write(str(ocsf_event) + "\n")
        except AttributeError as e:
            print("Error transforming line to OCSF")
            print(event)
            print(e)

    # b. Encode as Parquet
    try:
        table = pa.Table.from_pylist(ocsf_data)
        pq.write_table(table, filename_parquet)
    except AttributeError as e:
        print("Error encoding data to parquet")
        print(e)

    # 3. Load data (upload to S3)
    #    ================
    if upload_file(table, filename_parquet, os.environ['AWS_BUCKET']):
        # Remove /tmp files
        pass


def _test():
    ocsf_event = {}
    with open("./wazuh-event.sample.json", "r") as fd:
        # Load from file descriptor
        for raw_event in fd:
            try:
                event = transform.converter.from_json(raw_event)
                print("")
                print("-- Wazuh event Pydantic model")
                print("")
                print(event.model_dump())
                ocsf_event = transform.converter.to_detection_finding(event)
                print("")
                print("-- Converted to OCSF")
                print("")
                print(ocsf_event.model_dump())

            except KeyError as e:
                raise (e)


if __name__ == '__main__':
    main()
    # _test()

# ================================================ #
#   AWS LAMBDA method
# ================================================ #

def init_aws_client():
    '''
    boto3 client setup
    '''
    logging.info("Initializing boto3 client.")
    client = boto3.client(
        service_name='s3',
        aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
        region_name=os.environ['AWS_REGION'],
        endpoint_url='http://s3.ninja:9000',
    )
    logging.info("boto3 client initialized.")
    return client


def get_events(bucket: str, key: str):
    '''
    '''
    logging.info(f"Reading {key}.")
    response = client.get_object(
        Bucket=bucket,
        Key=key
    )
    data = response['Body'].read().decode('utf-8')
    return data.splitlines()


def transform_events_to_ocsf(events):
    '''
    '''
    logging.info("Transforming Wazuh security events to OCSF.")
    ocsf_events = []
    for line in events:
        try:
            # Validate event using a model
            event = transform.converter.from_json(line)
            # Transform to OCSF
            ocsf_event = transform.converter.to_detection_finding(event).model_dump()
            # Append
            ocsf_events.append(ocsf_event)
        except AttributeError as e:
            logging.error("Error transforming line to OCSF")
            logging.error(event)
            logging.error(e)
    return ocsf_events


def to_parquet(ocsf_events):
    '''

    '''
    table = pa.Table.from_pylist(ocsf_events)

    # Write to file.
    to_parquet_file(table)


def to_parquet_file(pa_table, filename='tmp'):
    '''
    Write data to file.
    '''
    pq.write_table(pa_table, f'{filename}.parquet', compression='ZSTD')

    
# "Initialize SDK clients and database connections outside of the function handler"
client = init_aws_client() 

def lambda_handler(event, context):
    logging.basicConfig(filename='lambda.log', encoding='utf-8', level=logging.DEBUG)

    # Variables: get the object name and bucket name from the event 
    # - From https://docs.aws.amazon.com/lambda/latest/dg/with-s3-example.html#with-s3-example-create-function
    src_bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    dst_bucket = os.environ['AWS_BUCKET']
    logging.info(f"Lambda function invoked due to {key}.")
    logging.info(f"Source bucket name is {src_bucket}. Destination bucket is {dst_bucket}.")
   
    # Read events from the source (aux) bucket 
    raw_events = get_events(src_bucket, key)

    # Transform data
    ocsf_events = transform_events_to_ocsf(raw_events)

    # Encode events as parquet
    to_parquet(ocsf_events)

    # Upload to destination bucket B
    logging.info(f"Uploading data to {dst_bucket}.")
    response = client.put_object(
        Bucket=dst_bucket, 
        Key=key.replace('.txt', '.parquet'), 
        Body=open('tmp.parquet', 'rb')
    )

    return json.dumps({ 'size': len(raw_events), 'response': response})
