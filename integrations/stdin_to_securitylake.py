#!/usr/bin/env python3

import os
import sys
import argparse
import logging
import time
import json
from datetime import datetime
from pyarrow import parquet, Table, fs

block_ending = { "block_ending": True }

s3 = fs.S3FileSystem()

def map_to_ocsf(alert_dictionary,ocsf_mapping_filename):
  ocsf_alert = {}
  with open(ocsf_mapping_filename) as jsonfile:
    mappings = json.loads(jsonfile.read())
  ### Put constants into the output alert
  ocsf_alert |= mappings['constants']

  for key in mappings['mappings']:
    dotted_destination_field = mappings['mappings'].get(key)
    depth_levels = dotted_destination.split('.')
    current_level = alert_dictionary[depth_levels[0]]
    if len(depth_levels>1):
      for field in depth_levels[1:]:
        current_level = current_level[field]
    ocsf_alert[key] = current_level

def encode_parquet(list,bucket_name,folder):
  ### We can write directly to S3 from pyarrow:
  ### https://arrow.apache.org/docs/python/filesystems.html#s3
  ### https://arrow.apache.org/docs/python/generated/pyarrow.fs.S3FileSystem.html#pyarrow.fs.S3FileSystem.open_output_stream
  ###
  ### Credentials can be stored in ~/.aws/credentials
  ### https://docs.aws.amazon.com/sdk-for-cpp/v1/developer-guide/credentials.html

  table = Table.from_pylist(list)
  parquet.write_to_dataset(table, root_path='s3://{}/{}'.format(bucket_name,folder))

def read_block(fileobject,length):
  output=[]
  for i in range(0,length):
    line = fileobject.readline()
    if line == '':
      output.append(block_ending)
      break 
    output.append(json.loads(line))
  return output

def get_elapsedseconds(reference_timestamp):
  current_time = datetime.now(tz='UTC')  
  return (current_time - reference_timestamp).total_seconds()
  
def parse_arguments():
  parser = argparse.ArgumentParser(description='STDIN to Security Lake pipeline')
  parser.add_argument('-b','--bucketname', action='store', help='Name of the output S3 bucket')
  parser.add_argument('-f','--foldername', action='store', help='Name of the output S3 bucket\'s folder')
  parser.add_argument('-i','--pushinterval', action='store', default=299, help='Time interval for pushing data to Security Lake')
  parser.add_argument('-m','--maxlength', action='store', default=20, help='Event number threshold for submission to Security Lake')
  parser.add_argument('-n','--linebuffer', action='store', default=10, help='stdin line buffer length')
  parser.add_argument('-s','--sleeptime', action='store', default=5, help='Input buffer polling interval')
  parser.add_argument('-x','--mapping', action='store', default='ocsf-mapping.json', help='Location of the Wazuh Alert to OCSF mapping (json formatted)')
  debugging = parser.add_argument_group('debugging')
  debugging.add_argument('-o','--output', type=str, default="/tmp/{}_stdintosecuritylake.txt".format(clockstr), help='File path of the destination file to write to')
  debugging.add_argument('-d','--debug', action='store_true', help='Activate debugging')
  args = parser.parse_args()

if __name__ == "__main__":
  clock = datetime.now(tz='UTC')
  clockstr = clock.strftime('%F_%H.%M.%S')
  parse_arguments()
  logging.basicConfig(format='%(asctime)s %(message)s',filename=args.output, encoding='utf-8', level=logging.DEBUG)
  logging.info('BUFFERING STDIN')
  
  try: 

    with os.fdopen(sys.stdin.fileno(), 'rt', buffering=0) as stdin:
      output_buffer = []
      starttimestamp = datetime.now(tz='UTC')
      
      try:
        while True:
          ### We can possibly replace all the custom code here
          ### and just use Arrow's built-in input and output facilities:
          ### * https://arrow.apache.org/docs/python/memory.html#input-and-output
          ### * https://arrow.apache.org/docs/python/ipc.html#reading-from-stream-and-file-format-for-pandas
          ### * https://stackoverflow.com/questions/52945609/pandas-dataframe-to-parquet-buffer-in-memory

          current_block = read_block(stdin,args.linebuffer)
          if current_block[-1] == block_ending :
            output_buffer +=  current_block[0:current_block.index(block_ending)]
            time.sleep(args.sleeptime)
          if len(output_buffer) > args.maxlength or get_elapsedseconds(starttimestamp) > args.pushinterval:
            encode_parquet(output_buffer,args.bucketname,args.foldername)
            logging.debug(json.dumps(output_buffer))
            starttimestamp = datetime.now(tz='UTC')
            output_buffer = []
          output_buffer.append(current_block)

      except KeyboardInterrupt:
        logging.info("Keyboard Interrupt issued")
        exit(0)

    logging.info('FINISHED RETRIEVING STDIN')

  except Exception as e:
    logging.error("Error running script")
    exit(1)
