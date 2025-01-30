import os
import json
import gzip
import boto3
import botocore
import pytest
import pyarrow as pa
import pyarrow.parquet as pq
from unittest.mock import patch
from moto import mock_aws
from botocore.exceptions import ClientError
from lambda_function import (
    lambda_handler,
    assume_role,
    get_s3_client,
    get_events,
    write_parquet_file,
    upload_to_s3,
    get_full_key,
)

# Set up test environment variables
os.environ["AWS_BUCKET"] = "destination-bucket"
os.environ["SOURCE_LOCATION"] = "test-source"
os.environ["ACCOUNT_ID"] = "123456789012"
os.environ["REGION"] = "us-east-1"
os.environ["ROLE_ARN"] = "arn:aws:iam::123456789012:role/test-role"
os.environ["EXTERNAL_ID"] = "test-external-id"
os.environ["S3_BUCKET_OCSF"] = "source-bucket"
os.environ["OCSF_CLASS"] = "SECURITY_FINDING"


@pytest.fixture
def aws_setup():
    """Sets up fake AWS services using moto."""
    with mock_aws():
        s3_client = boto3.client("s3")
        sts_client = boto3.client("sts")

        # Create test S3 buckets
        s3_client.create_bucket(Bucket="source-bucket")
        s3_client.create_bucket(Bucket="destination-bucket")

        # Create and upload a gzipped test file to S3
        log_data = json.dumps([{"event": "test log"}])
        with gzip.open("/tmp/test-file.gz", "wb") as f:
            f.write(log_data.encode())

        s3_client.upload_file("/tmp/test-file.gz", "source-bucket", "0.0.name-of-file.gz")

        yield s3_client, sts_client  # Return mocked clients for additional tests


@mock_aws
@patch("lambda_function.wazuh_ocsf_converter.transform_events", return_value=[{"mocked": "event"}])
def test_lambda_handler(mock_transform_events, aws_setup):
    s3_client, _ = aws_setup
    event = {
        "Records": [
            {
                "s3": {
                    "bucket": {"name": "source-bucket"},
                    "object": {"key": "0.0.name-of-file.gz"},
                }
            }
        ]
    }

    response = lambda_handler(event, None)
    print(response)
    response_json = json.loads(response)

    assert response_json["size"] == 1
    assert response_json["upload_success"] is True
    assert response_json["ocsf_upload_success"] is True
    mock_transform_events.assert_called_once()


def test_assume_role(aws_setup):
    """Test assume_role() using a mocked STS client."""
    response = assume_role(
        arn="arn:aws:iam::123456789012:role/test-role",
        external_id="test-external-id",
        session_name="test-session"
    )

    assert response is not None
    assert "AccessKeyId" in response
    assert "SecretAccessKey" in response
    assert "SessionToken" in response


def test_get_s3_client(aws_setup):
    """Test get_s3_client() with and without credentials."""
    default_client = get_s3_client()
    assert isinstance(default_client, botocore.client.BaseClient)

    fake_credentials = {
        "AccessKeyId": "test-key",
        "SecretAccessKey": "test-secret",
        "SessionToken": "test-token"
    }
    session_client = get_s3_client(fake_credentials)
    assert isinstance(session_client, botocore.client.BaseClient)


def test_get_events(aws_setup):
    """Test get_events() retrieves and decompresses S3 data."""
    s3_client, _ = aws_setup
    events = get_events("source-bucket", "0.0.name-of-file.gz", s3_client)

    assert isinstance(events, list)
    assert len(events) > 0
    assert json.loads(events[0]) == [{"event": "test log"}]


def test_write_parquet_file():
    """Test write_parquet_file() writes a valid Parquet file."""
    events = [{"event": "test log"}]
    filename = "/tmp/test.parquet"

    write_parquet_file(events, filename)

    table = pq.read_table(filename)
    assert table.num_rows == 1
    assert table.column_names == ["event"]


def test_upload_to_s3(aws_setup):
    """Test upload_to_s3() uploads files to an S3 bucket."""
    s3_client, _ = aws_setup

    filename = "/tmp/upload_test.txt"
    with open(filename, "w") as f:
        f.write("This is a test upload.")

    success = upload_to_s3("destination-bucket",
                           "test/upload_test.txt", filename, s3_client)
    assert success

    response = s3_client.get_object(
        Bucket="destination-bucket", Key="test/upload_test.txt")
    content = response["Body"].read().decode("utf-8")
    assert content == "This is a test upload."


def test_get_full_key():
    """
    Test the get_full_key() function to ensure it correctly constructs the full S3 key.
    """

    # Define the input parameters for the test
    src_location = "test-source"
    account_id = "123456789012"
    region = "us-east-1"
    key = "20230101.12345678.name-of-file.ijklmnop"
    format = "parquet"

    # Call the function with the test inputs
    full_key = get_full_key(src_location, account_id, region, key, format)

    # Define the expected output
    expected_key = 'ext/test-source/region=us-east-1/accountId=123456789012/eventDay=20230101/nameoffile.parquet'

    # Assert that the constructed key matches the expected key
    assert full_key == expected_key
