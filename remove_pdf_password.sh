#!/bin/sh

# $1 Source PDF file name
# $2 Destination PDF file name
# $3 Password for the source PDF file name

# For this to work, you need to install QPDF from homebrew
# brew install qpdf

qpdf --decrypt --password=$3 $1 $2
