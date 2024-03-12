#!/env/bin/python3.9
# vim: bkc=yes bk wb

import os
import sys
import argparse
import logging
import time
import json
import datetime
import boto3
import transform
from pyarrow import parquet, Table, fs


logging.basicConfig(format='%(asctime)s %(message)s',
                    encoding='utf-8', level=logging.DEBUG)

BLOCK_ENDING = {"block_ending": True}


def create_arg_parser():
    parser = argparse.ArgumentParser(
        description='STDIN to Security Lake pipeline')
    parser.add_argument('-d', '--debug', action='store_true',
                        help='Activate debugging')
    parser.add_argument('-b', '--bucketname', type=str, action='store',
                        help='S3 bucket name to write parquet files to')
    parser.add_argument('-e', '--s3endpoint', type=str, action='store', default=None,
                        help='Hostname and port of the S3 destination (defaults to AWS\')')
    parser.add_argument('-i', '--pushinterval', type=int, action='store', default=299,
                        help='Time interval in seconds for pushing data to Security Lake')
    parser.add_argument('-l', '--logoutput', type=str, default="/tmp/stdintosecuritylake.txt",
                        help='File path of the destination file to write to')
    parser.add_argument('-m', '--maxlength', type=int, action='store', default=2000,
                        help='Event number threshold for submission to Security Lake')
    parser.add_argument('-n', '--linebuffer', type=int, action='store',
                        default=100, help='stdin line buffer length')
    parser.add_argument('-p', '--s3profile', type=str, action='store',
                        default='default', help='AWS profile as stored in credentials file')
    parser.add_argument('-s', '--sleeptime', type=int, action='store',
                        default=5, help='Input buffer polling interval')
    return parser


def check_fd_open(file):
    return file.closed


def s3authenticate(profile, endpoint=None, scheme='https'):
    session = boto3.session.Session(profile_name=profile)
    credentials = session.get_credentials()

    if endpoint != None:
        scheme = 'http'

    s3fs = fs.S3FileSystem(
        endpoint_override=endpoint,
        access_key=credentials.access_key,
        secret_key=credentials.secret_key,
        scheme=scheme)

    return s3fs


def encode_parquet(list, bucketname, filename, filesystem):
    try:
        table = Table.from_pylist(list)
        parquet.write_table(table, '{}/{}'.format(bucketname,
                            filename), filesystem=filesystem)
    except Exception as e:
        logging.error(e)
        raise


def map_block(fileobject, length):
    output = []
    ocsf_mapped_alert = {}
    for line in range(0, length):
        line = fileobject.readline()
        if line == '':
            output.append(BLOCK_ENDING)
            break
        alert = json.loads(line)
        ocsf_mapped_alert = converter.convert(alert)
        output.append(ocsf_mapped_alert)
    return output


def timedelta(reference_timestamp):
    current_time = datetime.datetime.now(datetime.timezone.utc)
    return (current_time - reference_timestamp).total_seconds()


def utctime():
    return datetime.datetime.now(datetime.timezone.utc)


if __name__ == "__main__":
    try:
        args = create_arg_parser().parse_args()
        logging.info('BUFFERING STDIN')

        with os.fdopen(sys.stdin.fileno(), 'rt') as stdin:
            output_buffer = []
            loop_start_time = utctime()

            try:
                s3fs = s3authenticate(args.s3profile, args.s3endpoint)
                while True:

                    current_block = map_block(stdin, args.linebuffer)

                    if current_block[-1] == BLOCK_ENDING:
                        output_buffer += current_block[0:-1]
                        time.sleep(args.sleeptime)
                    else:
                        output_buffer += current_block

                    buffer_length = len(output_buffer)

                    if buffer_length == 0:
                        continue

                    elapsed_seconds = timedelta(loop_start_time)

                    if buffer_length > args.maxlength or elapsed_seconds > args.pushinterval:
                        logging.info(
                            'Elapsed seconds: {}'.format(elapsed_seconds))
                        loop_start_time = utctime()
                        timestamp = loop_start_time.strftime('%F_%H.%M.%S')
                        filename = 'wazuh-{}.parquet'.format(timestamp)
                        logging.info(
                            'Writing data to s3://{}/{}'.format(args.bucketname, filename))
                        encode_parquet(
                            output_buffer, args.bucketname, filename, s3fs)
                        output_buffer = []

            except KeyboardInterrupt:
                logging.info("Keyboard Interrupt issued")
                exit(0)

        logging.info('FINISHED RETRIEVING STDIN')

    except Exception as e:
        logging.error("Error running script")
        logging.error(e)
        raise


def _test():
    ocsf_event = {}
    with open("./wazuh-event.sample.json", "r") as fd:
        # Load from file descriptor
        raw_event = json.load(fd)
        try:
            event = transform.converter.from_json(raw_event)
            print(event)
            ocsf_event = transform.converter.to_detection_finding(event)
            print("")
            print("--")
            print("")
            print(ocsf_event)

        except KeyError as e:
            raise (e)


if __name__ == '__main__':
    _test()
