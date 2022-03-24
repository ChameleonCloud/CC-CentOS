#!/usr/bin/env python
import argparse
import io
import operator
import os
import requests
import sys

def main():
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument('-n', '--release', type=str, default='8', choices=['7', '8', '8-stream'],
        help='CentOS release')
    parser.add_argument('-v', '--variant', type=str,
        help='Image variant to build.') # extra elements defined in the .sh
    parser.add_argument('-g', '--region', type=str, required=True, help='Region name (for FPGA)')

    args = parser.parse_args()
    
    exec_args = ['create-image.sh', 'create-image.sh', '--release', args.release, '--variant', args.variant, '--region', args.region]
    
    os.execl(*exec_args)

if __name__ == '__main__':
    sys.exit(main())
