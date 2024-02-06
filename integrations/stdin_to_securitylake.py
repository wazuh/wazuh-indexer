#!/usr/bin/env python3

import os
import sys
import argparse
import logging
import time
import json
from datetime import datetime
from pyarrow import parquet, Table

block_ending = { "block_ending": True }

def map_to_ocsf():
  ## Code that translates fields to OCSF

def encode_parquet(list):
  table = Table.from_pylist(list)
  parquet.write_table(table, '/tmp/{}.parquet'.format(clockstr))

def push_to_s3(parquet):
  ## Fill with AWS S3 code
  pass

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
  parser.add_argument('-n','--linebuffer', action='store', default=10 help='stdin line buffer length')
  parser.add_argument('-m','--maxlength', action='store', default=20 help='Event number threshold for submission to Security Lake')
  parser.add_argument('-s','--sleeptime', action='store', default=5 help='Input buffer polling interval')
  parser.add_argument('-i','--pushinterval', action='store', default=299 help='Time interval for pushing data to Security Lake')
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
          current_block = read_block(stdin,args.linebuffer)
          if current_block[-1] == block_ending :
            output_buffer +=  current_block[0:current_block.index(block_ending)]
            time.sleep(args.sleeptime)
          if len(output_buffer) > args.maxlength or get_elapsedseconds(starttimestamp) > args.pushinterval:
            push_to_s3(encode_parquet(output_buffer))
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
