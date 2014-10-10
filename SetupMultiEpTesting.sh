#!/bin/bash -x 
# This script configures the pki directories for a secondary imsapp instance
# on a lab machine.

# What imsapp instance# (2-999) are we configuring?
INST=$1
if [ $# -lt 1 ] || [ $INST -lt 2 ] || [ $INST -gt 999 ]; then
    echo "Usage: $0 <instance>   where instance is 002-999"
    exit 1
fi

# Make sure it's a 3-digit number
case "${#INST}" in
    1) INST="00"$INST ;;
    2) INST="0"$INST ;;
    3) ;;
    *) echo "***ERROR: <instance> too long (3-digit max)"; exit 1 ;;
esac
#Drop the zero if applicable
ABSINST=$(echo $INST | sed 's/^00//')
ABSINST=$(echo $ABSINST | sed 's/^0//')

#Add the instance number to set the ports for each node/endpoint
GUIPORT=$((9001+$ABSINST))
CLIPORT=$((9090+$ABSINST))
SIPPORT=$((5060+$ABSINST))

MACHNAME=`/bin/hostname | awk -F'.' '{print $1}'`
MACADDR=`/sbin/ifconfig eth0 | sed -n 's/.*HWaddr \([0-9a-fA-F:]\)/\1/p' | tr -d ' '`
NAMEROOT=`echo $MACADDR | tr -d ':'`
#NAMEROOT=$NAMEROOT"-"$INST
#Made this change due to a javascript error
NAMEROOT=$NAMEROOT"_"$INST

PKIDIR=/etc/pki/app$INST/tls
CERTDIR=$PKIDIR/certs
PHYSKEY=$PKIDIR/private/$NAMEROOT.key
CSR=$CERTDIR/$NAMEROOT.csr
CERT=$CERTDIR/$NAMEROOT.pem

CFGDIR=/etc/mutualink/app$INST

echo "==> Configuring serial# $NAMEROOT in $CFGDIR and $PKIDIR..."

mkdir -p $CERTDIR
mkdir -p $CFGDIR

# Install the Root CA and Manufacturing CA certs into our local keystore
../installcacert ../rootca/mlinkroot.pem $CERTDIR
../installcacert ../mfgca/mlinkmfgca1.pem $CERTDIR
../installcacert ../engca/mlinkengca1.pem $CERTDIR

# Make sure the mutualink key directories are not currently symlinked
if [ -L $CFGDIR/privkeys ]; then
    rm -f $CFGDIR/privkeys
fi
if [ -L $CFGDIR/pubkeys ]; then
    rm -f $CFGDIR/pubkeys
fi

# Make sure the mutualink key directories exist
mkdir -p $CFGDIR/privkeys
mkdir -p $CFGDIR/pubkeys

# Create appropriate links for physical certificates
ln -sf $PKIDIR/certs $CFGDIR/certs 
ln -sf /etc/pki/tls/certs/ca-bundle.crt $PKIDIR/certs 

echo

if [ -e $PHYSKEY ] || [ -e $CSR ] || [ -e $CERT ]; then
    echo "***ERROR: This endpoint already has a physical key, csr, or cert"
    exit 1
fi

# Generate our physical keys and create a CSR (Cert Signing Request)
genphyscsr $PKIDIR $NAMEROOT

echo

# Have the Engineering CA sign our CSR and install our physical cert
cd ca
mfgsigncsr $CSR

echo

if [ -e $PHYSKEY ] && [ -e $CSR ] && [ -e $CERT ]; then
    echo "Physical keys & certificate created successfully!"
    echo "   Key  = $PHYSKEY"
    echo "   CSR  = $CSR"
    echo "   Cert = $CERT"
else
    echo "***Setup failed - check $PKIDIR for clues...  :-("
fi

#Create config file
touch $CFGDIR/app$INST.cfg

#Assign the variable for the node config file
NODECONFIG=$CFGDIR/app$INST.cfg
#Write to the config file
echo "#------------------------------------------------------------------------------" >> $NODECONFIG 
echo "#   Mutualink configuration file" >>  $NODECONFIG
echo "#" >> $NODECONFIG
echo "#   If a parameter is not specified, the default value is used." >> $NODECONFIG
echo "#------------------------------------------------------------------------------" >> $NODECONFIG
echo "[Include]" >> $NODECONFIG
echo "Common = /etc/mutualink/common.cfg" >>  $NODECONFIG
echo "" >> $NODECONFIG
echo "[General]" >>  $NODECONFIG
echo "OurIdentity = IWS/FairviewPSAP/${MACHNAME}-${INST}" >> $NODECONFIG
echo "" >>  $NODECONFIG
echo "SipPort = $SIPPORT " >>  $NODECONFIG
echo "CliPort = $CLIPORT" >>  $NODECONFIG
echo "GuiPort = $GUIPORT" >>  $NODECONFIG
echo "EnableVoice = false" >>  $NODECONFIG
echo "[KDS]" >>  $NODECONFIG
echo "#KdsRemoteAddress = 192.168.35.6" >>  $NODECONFIG
echo "" >>  $NODECONFIG
echo "#KdsPkiPhysicalDirPath = /etc/pki/app$INST/tls" >>  $NODECONFIG
echo "#KdsPkiLogicalDirPath = /etc/mutualink/app$INST" >>  $NODECONFIG
echo "" >>  $NODECONFIG
echo "[NMS]" >>  $NODECONFIG
echo "#NmsIpAddress = 192.168.35.6" >>  $NODECONFIG
echo "" >>  $NODECONFIG
echo "[TraceFlags]" >>  $NODECONFIG
echo "" >>  $NODECONFIG
#echo "KDS =5" >>  $NODECONFIG
#echo "NMS =5" >>  $NODECONFIG
