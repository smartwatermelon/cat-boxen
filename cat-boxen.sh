#!/bin/bash -eu
set -o pipefail
# Use bash, exit on error or unset variable, and exit if any command in a pipeline fails

###############
## cat-boxen
##
## a tool to enumerate physical machines used by the build-release team
##
## by andrew rich <arich@slack-corp.com> and lydia joslin <ljoslin@slack-corp.com>
## for slack day 2018
##
###############

# Check if authentication tokens are set
if [[ -z "${TOKEN_SMITHERS:-}" || -z "${TOKEN_SMITHERS_STAGING:-}" ]]; then
  # If tokens are not set, try to extract them from a config file
  if [[ -f ~/chef-repo/site-cookbooks/slack-apache/files/default/tsauth/config_smithers.pl ]]; then
    # Extract TOKEN_SMITHERS_STAGING from the config file
    TOKEN_SMITHERS_STAGING=$( grep "'role:staff','token:" ~/chef-repo/site-cookbooks/slack-apache/files/default/tsauth/config_smithers.pl | awk '{ print $3 }' | cut -d ',' -f 2 | cut -d ':' -f 2 | tr -d "'" )
    export TOKEN_SMITHERS_STAGING
    # Extract TOKEN_SMITHERS from the config file
    TOKEN_SMITHERS=$( grep "'role:staff','token:" ~/chef-repo/site-cookbooks/slack-apache/files/default/tsauth/config_smithers.pl | awk '{ print $3 }' | cut -d ',' -f 3 | cut -d ':' -f 2 | tr -d "']" )
    export TOKEN_SMITHERS
  else
    # If tokens can't be found, exit with an error message
    echo "Please export TOKEN_SMITHERS and TOKEN_SMITHERS_STAGING before running this tool. See the README for details."
    exit 1
  fi
fi

# Define URLs for Jenkins instances
SMITHERS="https://smithers.tinyspeck.com"
STAGING="https://smithers-staging.tinyspeck.com"

# Define a Groovy script to get hostname
MASTER_SCRIPT="println 'hostname'.execute().text"

# Get hostnames for both Jenkins instances
SMITHERS_HOSTNAME=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS}" -H "TSAuth-Token: ${TOKEN_SMITHERS}" -d "script=${MASTER_SCRIPT}" "${SMITHERS}/computer/(master)/scriptText" )
STAGING_HOSTNAME=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS_STAGING}" -H "TSAuth-Token: ${TOKEN_SMITHERS_STAGING}" -d "script=${MASTER_SCRIPT}" "${STAGING}/computer/(master)/scriptText" )

# Define scripts to get network information for Linux and Mac nodes
AUI_SCRIPT="println 'ip -o -4 link'.execute().text; println 'ip -o -4 address'.execute().text"
MAC_SCRIPT="println '/usr/local/bin/ip -4 addr show'.execute().text"

# Get list of computers from Smithers
SMITHERS_COMPUTERS=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS}" -H "TSAuth-Token: ${TOKEN_SMITHERS}" "${SMITHERS}/computer/api/json?tree=computer[displayName,offline]" )
SMITHERS_ONLINE_COMPUTERS=$( jq -r '.computer[] | select((.displayName != "master") and .offline == false) | .displayName' <<< "${SMITHERS_COMPUTERS}" )
SMITHERS_AUIS=$( grep 'android-uitest' <<< "${SMITHERS_ONLINE_COMPUTERS}" ) || :
SMITHERS_MACS=$( grep -e 'mac-build' -e 'mac-device-lab' -e 'mcsd' <<< "${SMITHERS_ONLINE_COMPUTERS}" ) || :

# Get list of computers from Staging
STAGING_COMPUTERS=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS_STAGING}" -H "TSAuth-Token: ${TOKEN_SMITHERS_STAGING}" "${STAGING}/computer/api/json?tree=computer[displayName,offline]" )
STAGING_ONLINE_COMPUTERS=$( jq -r '.computer[] | select((.displayName != "master") and .offline == false) | .displayName' <<< "${STAGING_COMPUTERS}" )
STAGING_AUIS=$( grep 'android-uitest' <<< "${STAGING_ONLINE_COMPUTERS}" ) || :
STAGING_MACS=$( grep -e 'mac-build' -e 'mac-device-lab' -e 'mcsd' <<< "${STAGING_ONLINE_COMPUTERS}" ) || :

# Create a temporary directory for output files
OUTDIR=$( mktemp -d )

# Process Android UI test nodes from Smithers
for AUI in ${SMITHERS_AUIS}; do
  echo "${AUI}..."
  ( 
    AUI_IFACES=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS}" -H "TSAuth-Token: ${TOKEN_SMITHERS}" -d "script=${AUI_SCRIPT}" "${SMITHERS}/computer/${AUI}/scriptText" )
    AUI_EN_IFACE=$( awk '!/lo[:]? / && !/tun[0-9]+[:]? / && !/DOWN /' <<< "${AUI_IFACES}" )
    AUI_MAC_ADDR=$( awk '/link\/ether / {print $(NF-2)}' <<< "${AUI_EN_IFACE}" )
    AUI_IP_ADDR=$( awk -F '[/ ]+' -v OFS='\t' -v A="${AUI}" '/inet / {print $4, A, "#"}' <<< "${AUI_EN_IFACE}" )
    AUI_TUN_IFACE=$( awk '/tun[0-9]+[:]?/ && /inet / && !/DOWN /' <<< "${AUI_IFACES}" )
    AUI_TUN_IP_ADDR=$( awk -v OFS='\t' -v A="vpn-${AUI}" -v H="${SMITHERS_HOSTNAME}" '{ print $4, A, "#", H }' <<< "${AUI_TUN_IFACE}" )
    OUTFILE="${OUTDIR}/${AUI}"
    echo -e "${AUI_IP_ADDR}\\t${AUI_MAC_ADDR}" > "${OUTFILE}"
    echo -e "${AUI_TUN_IP_ADDR}" >> "${OUTFILE}"
  ) &
done  # for AUI
# Process Android UI test nodes from Staging (similar to Smithers)
for AUI in  ${STAGING_AUIS}; do
  echo "${AUI}..."
  ( 
    AUI_IFACES=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS_STAGING}" -H "TSAuth-Token: ${TOKEN_SMITHERS_STAGING}" -d "script=${AUI_SCRIPT}" "${STAGING}/computer/${AUI}/scriptText" )
    AUI_EN_IFACE=$( awk '!/lo[:]? / && !/tun[0-9]+[:]? / && !/DOWN /' <<< "${AUI_IFACES}" )
    AUI_MAC_ADDR=$( awk '/link\/ether / {print $(NF-2)}' <<< "${AUI_EN_IFACE}" )
    AUI_IP_ADDR=$( awk -F '[/ ]+' -v OFS='\t' -v A="${AUI}" '/inet / {print $4, A, "#"}' <<< "${AUI_EN_IFACE}" )
    AUI_TUN_IFACE=$( awk '/tun[0-9]+[:]?/ && /inet / && !/DOWN /' <<< "${AUI_IFACES}" )
    AUI_TUN_IP_ADDR=$( awk -v OFS='\t' -v A="vpn-${AUI}" -v H="${STAGING_HOSTNAME}" '{ print $4, A, "#", H }' <<< "${AUI_TUN_IFACE}" )
    OUTFILE="${OUTDIR}/${AUI}"
    echo -e "${AUI_IP_ADDR}\\t${AUI_MAC_ADDR}" > "${OUTFILE}"
    echo -e "${AUI_TUN_IP_ADDR}" >> "${OUTFILE}"
  ) &
done  # for AUI

# Process Mac build nodes from Smithers
for MAC in ${SMITHERS_MACS}; do
  echo "${MAC}..."
  (
    MAC_IFACES=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS}" -H "TSAuth-Token: ${TOKEN_SMITHERS}" -d "script=${MAC_SCRIPT}" "${SMITHERS}/computer/${MAC}/scriptText" )
    MAC_EN_IFACE=$( ( grep -B 1 -e 'inet 10' -e 'inet 207' | tr -d '\n' | awk '{$1=$1};1' ) <<< "${MAC_IFACES}" )
    MAC_IP_MAC_ADDR=$( awk -F '[ /]' -v OFS='\t' -v M="${MAC}" '{print $4, M, "#", $2 }' <<< "${MAC_EN_IFACE}" )
    MAC_TUN_IFACE=$( (awk '/utun[0-9]+[:]?/ && !/DOWN /' <<< "${MAC_IFACES}") | tr -d '\n' )
    MAC_TUN_IP_ADDR=$( awk -v OFS='\t' -v M="vpn-${MAC}" -v H="${SMITHERS_HOSTNAME}" '{print $6, M, "#", H}' <<< "${MAC_TUN_IFACE}" )
    OUTFILE="${OUTDIR}/${MAC}"
    echo -e "${MAC_IP_MAC_ADDR}" > "${OUTFILE}"
    echo -e "${MAC_TUN_IP_ADDR}" >> "${OUTFILE}"
  ) &
done  # for MAC
# Process Mac build nodes from Staging (similar to Smithers)
for MAC in ${STAGING_MACS}; do
  echo "${MAC}..."
  (
    MAC_IFACES=$( curl -f --silent -g -H "Token: ${TOKEN_SMITHERS_STAGING}" -H "TSAuth-Token: ${TOKEN_SMITHERS_STAGING}" -d "script=${MAC_SCRIPT}" "${STAGING}/computer/${MAC}/scriptText" )
    MAC_EN_IFACE=$( ( grep -B 1 -e 'inet 10' -e 'inet 207' | tr -d '\n' | awk '{$1=$1};1' ) <<< "${MAC_IFACES}" )
    MAC_IP_MAC_ADDR=$( awk -F '[ /]' -v OFS='\t' -v M="${MAC}" '{print $4, M, "#", $2 }' <<< "${MAC_EN_IFACE}" )
    MAC_TUN_IFACE=$( (awk '/utun[0-9]+[:]?/ && !/DOWN /' <<< "${MAC_IFACES}") | tr -d '\n' )
    MAC_TUN_IP_ADDR=$( awk -v OFS='\t' -v M="vpn-${MAC}" -v H="${STAGING_HOSTNAME}" '{print $6, M, "#", H}' <<< "${MAC_TUN_IFACE}" )
    OUTFILE="${OUTDIR}/${MAC}"
    echo -e "${MAC_IP_MAC_ADDR}" > "${OUTFILE}"
    echo -e "${MAC_TUN_IP_ADDR}" >> "${OUTFILE}"
  ) &
done  # for MAC

echo "Waiting for all cats to finish..."
wait

# Combine all temporary files into one output file
echo "Con-Cat-enating output..."
OUTFILE="$( mktemp )"
find "${OUTDIR}" -type f -print0 | xargs -0 cat >> "${OUTFILE}"
echo
# Sort the output and display it
sed -e 's/offline/#offline/g' < "${OUTFILE}" | sort -V -k 2
echo
echo "All processes are finished meow."
