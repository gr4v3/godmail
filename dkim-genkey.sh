#!/bin/sh
##
## $Id: dkim-genkey.sh,v 1.3 2008/01/09 21:45:54 msk Exp $
##
## Copyright (c) 2005-2008 Sendmail, Inc. and its suppliers.
## All rights reserved.
##
## dkim-genkey -- generate a key and/or TXT record for DKIM service
##
## Usage: dkim-genkey [options]
## 	-b bits		key size (default = 1024)
##  	-d domain	signing domain (default = "example.com")
## 	-D dir		output directory (default = ".")
## 	-g gran		key granularity (default = "*")
## 	-h algs		list of allowed hash algorithms (default = unspecified)
## 	-n text		include "text" as a note in the output key record
## 	-r		restrict this key to e-mail use only
## 	-s name		selector name (default = "default")
## 	-S		disallow subdomain signing with this key
##  	-t		set the "test mode" bit in the TXT record
##
## The output of this script includes two files based on the
## selector name:
##
## 	<selector>.private	PEM-formatted private key, for use by
## 				dkim-filter when signing messages
##
## 	<selector>.txt		A DNS TXT record suitable for insertion
## 				into or inclusion by a DNS zone file
## 				in order to publish the public key
## 				for retrieval by verifiers


## Set up defaults
bits="1024"
domain="example.com"
outdir="."
nosubdomains=0
hashalgs=""
keygran="*"
note=""
selector="default"
restrict=0
testmode=0
verbose=0

progname=`basename $0`

## Argument processing
while [ $# -gt 0 ]
do
	case $1 in
	-b)	if [ $# -eq 1 ]
		then
			echo $progname: -b requires a value
			exit 1
		fi

		shift
		bits=$1
		;;

	-d)	if [ $# -eq 1 ]
		then
			echo $progname: -d requires a value
			exit 1
		fi

		shift
		domain=$1
		;;

	-D)	if [ $# -eq 1 ]
		then
			echo $progname: -D requires a value
			exit 1
		fi

		shift
		outdir=$1
		;;

	-g)	if [ $# -eq 1 ]
		then
			echo $progname: -g requires a value
			exit 1
		fi

		shift
		keygran=$1
		;;

	-h)	if [ $# -eq 1 ]
		then
			echo $progname: -h requires a value
			exit 1
		fi

		shift
		hashalgs=$1
		;;

	-n)	if [ $# -eq 1 ]
		then
			echo $progname: -h requires a value
			exit 1
		fi

		shift
		note=$1
		;;

	-r)	restrict=1
		;;

	-s)	if [ $# -eq 1 ]
		then
			echo $progname: -h requires a value
			exit 1
		fi

		shift
		selector=$1
		;;

	-S)	nosubdomains=1
		;;

	-t)	testmode=1
		;;

	-v)	verbose=1
		;;

	*)	echo $progname: unknown flag $1
		exit 1
		;;
	esac

	shift
done

## do this securely and in the right place
cd $outdir
umask 077

## generate a private key
if [ $verbose -eq 1 ]
then
	echo $progname: generating private key
fi

openssl genrsa -out ${selector}.private $bits > /dev/null 2>&1

if [ $verbose -eq 1 ]
then
	echo $progname: private key written to ${selector}.private
fi

## generate a public key based on the private key
if [ $verbose -eq 1 ]
then
	echo $progname: extracting public key
fi

openssl rsa -in ${selector}.private -pubout -out ${selector}.public -outform PEM > /dev/null 2>&1

keydata=`grep -v '^-' ${selector}.public`
pubkey=`echo $keydata | sed 's/ //g'`

## output the record
flags=""
if [ $testmode -eq 1 ]
then
	flags=" t=y"
fi
if [ $nosubdomains -eq 1 ]
then
	if [ "$flags" != "" ]
	then
		flags=${flags}:s
	else
		flags=" t=s"
	fi
fi
if [ "$flags" != "" ]
then
	flags=${flags}\;
fi

hashout=""
if [ "$hashalgs" != "" ]
then
	hashout=" h=$hashalgs\;"
fi

noteout=""
if [ "$note" != "" ]
then
	noteout=" n=\"%s\"\;"
fi

if [ "$domain" != "" ]
then
	comment=" ; ----- DKIM $selector for $domain"
else
	comment=""
fi

echo ${selector}._domainkey   IN   TXT  '"'v=DKIM1\;$noteout$hashalgs g=$keygran\; k=rsa\;$flags p=$pubkey'"' $comment > ${selector}.txt

if [ $verbose -eq 1 ]
then
	echo $progname: DNS TXT record written to ${selector}.txt
fi

## all done!
rm -f ${selector}.public
exit 0
