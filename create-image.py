#!/usr/bin/env python
import argparse
import io
import operator
import os
import requests
import sys

def main():
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument('-r', '--revision', type=str,
        help='Revision to build with, usually of the format YYMM')
    parser.add_argument('-n', '--release', type=str, default='8', choices=['7', '8'],
        help='CentOS release')
    parser.add_argument('-v', '--variant', type=str,
        help='Image variant to build.') # extra elements defined in the .sh
    parser.add_argument('-c', '--cuda-version', type=str, default='cuda10',
        help='CUDA version to install. Ignore if the variant is not gpu.')
    parser.add_argument('-g', '--region', type=str, required=True, help='Region name (for FPGA)')
    parser.add_argument('-k', '--kvm', action='store_true', help='Present if build image for KVM site')
    parser.add_argument('-s', '--special', choices=['mpich', 'osg'], help='Special element to install')

    args = parser.parse_args()
    
    exec_args = ['create-image.sh', 'create-image.sh', '--release', args.release, '--variant', args.variant, '--kvm', str(args.kvm).lower()]
    if args.variant == 'gpu':
        exec_args.extend(['--cuda', args.cuda_version])
    else:
        exec_args.extend(['--region', args.region])
        
    if args.special:
        exec_args.extend(['--special', args.special])
    
    os.execl(*exec_args)

if __name__ == '__main__':
    sys.exit(main())
