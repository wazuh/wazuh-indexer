#!/usr/bin/env python3

import os
import sys
import argparse
import logging
import time
from datetime import datetime
from pyarrow import json
import pyarrow.parquet as pq

def encode_parquet(json_list):
  for json in json_list:
    ### read_json is meant for files, need to change it to read from a string
    ### https://arrow.apache.org/docs/python/json.html 
    table = json.read_json(json)
    pq.write_table(table, 'parquet/output.parquet')

def push_to_s3(parquet):
  ## Fill with AWS S3 code
  pass

def read_chunk(fileobject,length):
  output=[]
  for i in range(0,length):
    line = fileobject.readline()
    if line is '':
      output.append(line)
      break 
    output.append(line)
  return output

def get_elapsedtime(reference_timestamp):
  current_time = datetime.now(tz='UTC')  
  return (current_time - reference_timestamp).total_seconds()

if __name__ == "__main__":

  clock = datetime.now(tz='UTC')
  clockstr = clock.strftime('%F_%H:%M:%S')
  
  parser = argparse.ArgumentParser(description='STDIN to Security Lake pipeline')

  parser.add_argument('-n','--linebuffer', action='store', default=10 help='Lines to buffer')
  parser.add_argument('-m','--maxlength', action='store', default=20 help='Lines to buffer')
  parser.add_argument('-s','--sleeptime', action='store', default=5 help='Lines to buffer')
  parser.add_argument('-i','--pushinterval', action='store', default=299 help='Lines to buffer')
  
  debugging = parser.add_argument_group('debugging')
  debugging.add_argument('-o','--output', type=str, default="/tmp/{}_stdintosecuritylake.txt".format(clockstr), help='File path of the destination file to write to')
  debugging.add_argument('-d','--debug', action='store_true', help='Activate debugging')
  
  args = parser.parse_args()
  
  logging.basicConfig(format='%(asctime)s %(message)s',filename=args.output, encoding='utf-8', level=logging.DEBUG)
  logging.debug("Running main()")
  logging.debug("Current time is " + str(clockstr) )

  try: 
    logging.info('BUFFERING STDIN')

    with os.fdopen(sys.stdin.fileno(), 'rt', buffering=0) as stdin:

      output_buffer = []

      starttimestamp = datetime.now(tz='UTC')
      
      try:
        while True:
          output_buffer.append(read_chunk(stdin,args.linebuffer))
          if output_buffer[len(output_buffer)-1] is '':
            time.sleep(args.sleeptime)
          if len(output_buffer) > args.maxlength or get_elapsedtime(starttimestamp) > args.pushinterval:
            encode_parquet(output_buffer)
            logging.debug(output_buffer)
            starttimestamp = datetime.now(tz='UTC')
            output_buffer = []
      except KeyboardInterrupt:
        logging.info("Keyboard Interrupt issued")
        exit(0)
        

    logging.info('FINISHED RETRIEVING STDIN')
  except Exception as e:
    logging.error("Error running script")
    exit(1)
