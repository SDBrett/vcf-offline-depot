# VCF Bundle Cache and Search

This project provides the capability to download VCF Bundle manifest information as an offline cache and perform searches against that data. The goal of this utility is to simplify finding new bundles and information required to perform an offline download where the VCF download tool is not suitable for your needs.

## Usage

The VCF bundle depot requires authentication, you will need to provide valid `my.vmware.com` credentials for this utility to function.

You will need to provide a file path of a new or existing cache file for data to be written. If the file does not exist the utility will create it when initialized.