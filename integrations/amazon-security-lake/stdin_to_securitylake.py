#!/env/bin/python3

import os
import sys
import argparse
import logging
import time
import json
import datetime
import boto3
from pyarrow import parquet, Table, fs
from ocsf import converter

block_ending = { "block_ending": True }


def s3authenticate(profile, endpoint=None, scheme='https'):
  session = boto3.session.Session(profile_name=profile)
  credentials = session.get_credentials()

  if endpoint != None:
    scheme='http'

  s3fs = fs.S3FileSystem(
    endpoint_override=endpoint,
    access_key=credentials.access_key,
    secret_key=credentials.secret_key,
    scheme=scheme)
  
  return s3fs
  




def encode_parquet(list,foldername,filename):
  try:
    table = Table.from_pylist(list)
    parquet.write_table(table, '{}.parquet'.format(filename), filesystem=localS3)
  except Exception as e:
    logging.error(e)
    raise

def map_block(fileobject, length):
  output=[]
  ocsf_mapped_alert = {}
  for line in range(0, length):
    line = fileobject.readline()
    if line == '':
      output.append(block_ending)
      break 
    alert = json.loads(line)
    ocsf_mapped_alert = converter.convert(alert)
    output.append(ocsf_mapped_alert)
  return output

def get_elapsedseconds(reference_timestamp):
  current_time = datetime.datetime.now(datetime.timezone.utc)  
  return (current_time - reference_timestamp).total_seconds()

if __name__ == "__main__":
  date = datetime.datetime.now(datetime.timezone.utc).strftime('%F_%H.%M.%S')
  parser = argparse.ArgumentParser(description='STDIN to Security Lake pipeline')
  parser.add_argument('-d','--debug', action='store_true', help='Activate debugging')
  parser.add_argument('-e','--s3endpoint', type=str, action='store', default=None, help='Hostname and port of the S3 destination (defaults to AWS\')')
  parser.add_argument('-i','--pushinterval', type=int, action='store', default=299, help='Time interval in seconds for pushing data to Security Lake')
  parser.add_argument('-l','--logoutput', type=str, default="/tmp/stdintosecuritylake.txt", help='File path of the destination file to write to')
  parser.add_argument('-m','--maxlength', type=int, action='store', default=2000, help='Event number threshold for submission to Security Lake')
  parser.add_argument('-n','--linebuffer', type=int, action='store', default=100, help='stdin line buffer length')
  parser.add_argument('-o','--outputfolder', type=str, action='store', help='Folder or S3 bucket URL to dump parquet files to')
  parser.add_argument('-p','--s3profile', type=str, action='store', default='default', help='AWS profile as stored in credentials file')
  parser.add_argument('-s','--sleeptime', type=int, action='store', default=5, help='Input buffer polling interval')
  args = parser.parse_args()
  #logging.basicConfig(format='%(asctime)s %(message)s', filename=args.logoutput, encoding='utf-8', level=logging.DEBUG)
  logging.basicConfig(format='%(asctime)s %(message)s', encoding='utf-8', level=logging.DEBUG)
  logging.info('BUFFERING STDIN')
  
  try: 

    with os.fdopen(sys.stdin.fileno(), 'rt') as stdin:
      output_buffer = []
      starttimestamp = datetime.datetime.now(datetime.timezone.utc)
      
      try:
        while True:

          current_block = map_block( stdin, args.linebuffer )

          if current_block[-1] == block_ending:
            output_buffer +=  current_block[0:-1]
            time.sleep(args.sleeptime)
          else:
            output_buffer +=  current_block

          if len(output_buffer) == 0:
            continue

          if len(output_buffer) > args.maxlength or get_elapsedseconds(starttimestamp) > args.pushinterval:
            logging.info('Writing data to parquet file')
            s3fs = s3authenticate(args.s3profile,args.s3endpoint)
            encode_parquet(output_buffer,args.outputfolder,'wazuh-{}'.format(date))
            starttimestamp = datetime.datetime.now(datetime.timezone.utc)
            output_buffer = []

      except KeyboardInterrupt:
        logging.info("Keyboard Interrupt issued")
        exit(0)

    logging.info('FINISHED RETRIEVING STDIN')

  except Exception as e:
    logging.error("Error running script")
    logging.error(e)
    raise


