#!/bin/bash

############################################################
#    _____ ____  ____     _____           _       __
#   / ___// __ \/ __ \   / ___/__________(_)___  / /______
#   \__ \/ /_/ / / / /   \__ \/ ___/ ___/ / __ \/ __/ ___/
#  ___/ / ____/ /_/ /   ___/ / /__/ /  / / /_/ / /_(__  )
# /____/_/    \____/   /____/\___/_/  /_/ .___/\__/____/
#                                    /_/
#
# Scripts are brought to you by Martin L. (ATADA Stakepool)
# Telegram: @atada_stakepool   Github: github.com/gitmachtl
#
############################################################

#load variables and functions from common.sh
. "$(dirname "$0")"/00_common.sh


if [[ $# -gt 0 && ! $1 == "" ]]; then poolFile="$(dirname $1)/$(basename $(basename $1 .json) .pool)"; poolFile=${poolFile/#.\//}; else echo "ERROR - Usage: $(basename $0) <PoolNodeName> (pointing to the PoolNodeName.pool.json file) [optional registration-protection-key]"; exit 1; fi
if [[ $# -eq 2 ]]; then regKeyHash=$2; fi

#Check if json file exists
if [ ! -f "${poolFile}.pool.json" ]; then echo -e "\n\e[33mERROR - \"${poolFile}.pool.json\" does not exist, a dummy one was created, please edit it and retry.\e[0m";
#Generate Dummy JSON File
echo "
{
  \"poolName\": \"${poolFile}\",
  \"poolOwner\": [
    {
    \"ownerName\": \"set_your_owner_name_here\",
    \"ownerWitness\": \"local\"
    }
  ],
  \"poolRewards\": \"set_your_rewards_name_here_can_be_same_as_owner\",
  \"poolPledge\": \"100000000000\",
  \"poolCost\": \"10000000000\",
  \"poolMargin\": \"0.10\",
  \"poolRelays\": [
    {
      \"relayType\": \"ip or dns\",
      \"relayEntry\": \"x.x.x.x_or_the_dns-name_of_your_relay\",
      \"relayPort\": \"3001\"
    }
  ],
  \"poolMetaName\": \"THE NAME OF YOUR POOL\",
  \"poolMetaDescription\": \"THE DESCRIPTION OF YOUR POOL\",
  \"poolMetaTicker\": \"THE TICKER OF YOUR POOL\",
  \"poolMetaHomepage\": \"https://set_your_webserver_url_here\",
  \"poolMetaUrl\": \"https://set_your_webserver_url_here/$(basename ${poolFile}).metadata.json\",
  \"poolExtendedMetaUrl\": \"\",
  \"---\": \"--- DO NOT EDIT OR DELETE BELOW THIS LINE ---\"
}
" > ${poolFile}.pool.json
echo
echo -e "\e[0mStakepool Config JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo
echo -e "\e[0m"
exit 1; fi


#Small subroutine to read the value of the JSON and output an error is parameter is empty/missing
function readJSONparam() {
param=$(jq -r .$1 ${poolFile}.pool.json 2> /dev/null)
if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.pool.json is not a valid JSON file" >&2; exit 1;
elif [[ "${param}" == null ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json does not exist" >&2; exit 1;
elif [[ "${param}" == "" ]]; then echo "ERROR - Parameter \"$1\" in ${poolFile}.pool.json is empty" >&2; exit 1;
fi
echo "${param}"
}

#Read the pool JSON file and extract the parameters -> report an error is something is missing or wrong/empty
poolName=$(readJSONparam "poolName"); if [[ ! $? == 0 ]]; then exit 1; fi
poolOwner=$(readJSONparam "poolOwner"); if [[ ! $? == 0 ]]; then exit 1; fi
rewardsName=$(readJSONparam "poolRewards"); if [[ ! $? == 0 ]]; then exit 1; fi
poolPledge=$(readJSONparam "poolPledge"); if [[ ! $? == 0 ]]; then exit 1; fi
poolCost=$(readJSONparam "poolCost"); if [[ ! $? == 0 ]]; then exit 1; fi
poolMargin=$(readJSONparam "poolMargin"); if [[ ! $? == 0 ]]; then exit 1; fi

#Check if the poolFile entry is the same as the calling one
if [[ ! "${poolName}" == "${poolFile}" ]]; then echo -e "\n\e[35mERROR - The entry for the 'poolName' in your ${poolFile}.pool.json is '${poolName}' and does not match the current path '${poolFile}'. Do you have imported it?\e[0m\n"; exit 1; fi

#Check needed inputfiles
if [ ! -f "${poolName}.node.vkey" ]; then echo -e "\e[33mERROR - ${poolName}.node.vkey is missing! Check poolName field in ${poolFile}.pool.json about the right path, or generate it with script 04a !\e[0m"; exit 1; fi
if [ ! -f "${poolName}.vrf.vkey" ]; then echo -e "\e[33mERROR - ${poolName}.vrf.vkey is missing! Check poolName field in ${poolFile}.pool.json about the right path, or generate it with script 04b !\e[0m"; exit 1; fi
if [ ! -f "${rewardsName}.staking.vkey" ]; then echo -e "\e[33mERROR - ${rewardsName}.staking.vkey is missing! Check poolRewards field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi

#Read ProtocolParameters
case ${workMode} in
        "online")       protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters);; #onlinemode
        "light")        protocolParametersJSON=${lightModeParametersJSON};; #lightmode
        "offline")      readOfflineFile; protocolParametersJSON=$(jq ".protocol.parameters" <<< ${offlineJSON});; #offlinemode
esac
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#Check poolCost Setting
minPoolCost=$(jq -r .minPoolCost <<< ${protocolParametersJSON})

if [[ ${poolCost} -lt ${minPoolCost} ]]; then #If poolCost is set to low, than ask for an automatic change
                echo
                if ask "\e[33mYour poolCost (${poolCost} lovelaces) is lower than the minPoolCost (${minPoolCost} lovelaces). Do you wanna change it to that ?\e[0m" N; then
			poolCost=${minPoolCost}
                        file_unlock ${poolFile}.pool.json       #update the ticker in the json itself to the new one too
                        newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolCost: \"${poolCost}\"}")
                        echo "${newJSON}" > ${poolFile}.pool.json
                else
                        echo
                        echo "Please re-edit the poolCost entry in your ${poolFile}.pool.json, thx."
                        echo
                        exit 1
                fi
        fi

#Check poolMargin Setting - bc will only return a 1 if valid, if invalid like chars it will not return a 1
if [[ $(bc <<< "${poolMargin} >= 0.00 && ${poolMargin} <= 1.00" 2> /dev/null) -ne 1 ]]; then
	echo -e "\e[33mERROR - Parameter \"poolMargin\": The current value of '${poolMargin}' is not in the range 0.00 - 1.00 (0-100%). Please re-edit your ${poolFile}.pool.json file !\n\e[0m"; exit 1;
fi
poolMarginPct=$(bc <<< "${poolMargin} * 100" 2> /dev/null)


#Check PoolRelay Entries
tmp=$(readJSONparam "poolRelays"); if [[ ! $? == 0 ]]; then exit 1; fi
poolRelayCnt=$(jq -r '.poolRelays | length' ${poolFile}.pool.json)
poolRelays=""	#building string for the certificate
for (( tmpCnt=0; tmpCnt<${poolRelayCnt}; tmpCnt++ ))
do
  poolRelayEntryContent=$(jq -r .poolRelays[${tmpCnt}].relayEntry ${poolFile}.pool.json 2> /dev/null);
  if [[ "${poolRelayEntryContent}" == null || "${poolRelayEntryContent}" == "" ]]; then echo "ERROR - Parameter \"relayEntry\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1;
  elif [[ ${#poolRelayEntryContent} -gt 64 ]]; then echo -e "\e[0mERROR - The relayEntry parameter with content \"${poolRelayEntryContent}\" in your ${poolFile}.pool.json is too long. Max. 64chars allowed !\e[0m"; exit 1; fi

  #Load relay port data, verify later depending on the need (multihost does not need a port)
  poolRelayEntryPort=$(jq -r .poolRelays[${tmpCnt}].relayPort ${poolFile}.pool.json 2> /dev/null);
  poolRelayEntryType=$(jq -r .poolRelays[${tmpCnt}].relayType ${poolFile}.pool.json 2> /dev/null);
  if [[ "${poolRelayEntryType}" == null || "${poolRelayEntryType}" == "" ]]; then echo "ERROR - Parameter \"relayType\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi

  #Build relaystring depending on relaytype
  poolRelayEntryType=${poolRelayEntryType^^}  #convert to uppercase
  case ${poolRelayEntryType} in
  IP|IP4|IPV4)  #generate an IPv4 relay entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --pool-relay-ipv4 ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  IP6|IPV6)  #generate an IPv6 relay entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --pool-relay-ipv6 ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  DNS) #generate a dns single-relay A or AAAA entry
	if [[ "${poolRelayEntryPort}" == null || "${poolRelayEntryPort}" == "" ]]; then echo "ERROR - Parameter \"relayPort\" in ${poolFile}.pool.json poolRelays-Array does not exist or is empty!"; exit 1; fi
	poolRelays="${poolRelays} --single-host-pool-relay ${poolRelayEntryContent} --pool-relay-port ${poolRelayEntryPort}";;

  MULTISRV|SRV) #generate a dns SRV multi-relay entry
	#No port needed
        poolRelays="${poolRelays} --multi-host-pool-relay ${poolRelayEntryContent}";;

  * ) #unkown relay type
      echo "ERROR - The relayType parameter in ${poolFile}.pool.json with content \"${poolRelayEntryType}\" is unknown. Only \"IP/IP4/IPv4\", \"IP6/IPv6\", \"DNS\" or , \"MULTISRV\" is supported!"; exit 1;;
  esac
done


#Check PoolMetadata Entries
poolMetaName=$(readJSONparam "poolMetaName"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ${#poolMetaName} -gt 50 ]]; then echo -e "\e[35mERROR - The poolMetaName is too long. Max. 50 chars allowed !\e[0m"; exit 1; fi

poolMetaTickerOrig=$(readJSONparam "poolMetaTicker"); if [[ ! $? == 0 ]]; then exit 1; fi
	poolMetaTicker=${poolMetaTickerOrig//[^[:alnum:]]/_}   #Filter out forbidden chars and replace with _
	#poolMetaTicker=${poolMetaTicker^^} #convert to uppercase
	if [[ ${#poolMetaTicker} -lt 3 || ${#poolMetaTicker} -gt 5 ]]; then echo -e "\e[35mERROR - The poolMetaTicker Entry must be between 3-5 chars long !\e[0m"; exit 1; fi
	if [[ ! "${poolMetaTicker}" == "${poolMetaTickerOrig}" ]]; then #If corrected ticker is different than to the one in the pool.json file, ask if it is ok to use the new one
		echo
		if ask "\e[33mYour poolMetaTicker was corrected from '${poolMetaTickerOrig}' to '${poolMetaTicker}' to fit the rules! Are you ok with this ?\e[0m" N; then
			file_unlock ${poolFile}.pool.json	#update the ticker in the json itself to the new one too
			newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolMetaTicker: \"${poolMetaTicker}\"}")
		        echo "${newJSON}" > ${poolFile}.pool.json
                else
			echo
			echo "Please re-edit the poolMetaTicker entry in your ${poolFile}.pool.json, thx."
			echo
			exit 1
		fi
        fi

poolMetaHomepage=$(readJSONparam "poolMetaHomepage"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ! "${poolMetaHomepage}" =~ https?://.* || ${#poolMetaHomepage} -gt 64 ]]; then echo -e "\e[35mERROR - The poolMetaHomepage entry in your ${poolFile}.pool.json has an invalid URL format or is too long. Max. 64 chars allowed !\e[0m\n\nPlease re-edit the poolMetaHomepage entry in your ${poolFile}.pool.json, thx."; exit 1; fi;

poolMetaUrl=$(readJSONparam "poolMetaUrl"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ! "${poolMetaUrl}" =~ https?://.* || ${#poolMetaUrl} -gt 64 ]]; then echo -e "\e[35mERROR - The poolMetaUrl entry in your ${poolFile}.pool.json has an invalid URL format or is too long. Max. 64 chars allowed !\e[0m\n\nPlease re-edit the poolMetaUrl entry in your ${poolFile}.pool.json, thx."; exit 1; fi

poolMetaDescription=$(readJSONparam "poolMetaDescription"); if [[ ! $? == 0 ]]; then exit 1; fi
if [[ ${#poolMetaDescription} -gt 255 ]]; then echo -e "\e[35mERROR - The poolMetaDescription entry in your ${poolFile}.pool.json is too long. Max. 255 chars allowed !\e[0m\n\nPlease re-edit the poolMetaDescription entry in your ${poolFile}.pool.json, thx!\e[0m"; exit 1; fi


#Read out the POOL-ID and store it in the ${poolName}.pool.json
poolID=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-hex)     #New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
file_unlock ${poolFile}.pool.json
newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolID: \"${poolID}\"}")
echo "${newJSON}" > ${poolFile}.pool.json
file_lock ${poolFile}.pool.json

#Save out the POOL-ID also in the xxx.id file
file_unlock ${poolFile}.pool.id
echo "${poolID}" > ${poolFile}.pool.id
file_lock ${poolFile}.pool.id

poolIDbech=$(${cardanocli} ${cliEra} stake-pool id --cold-verification-key-file ${poolName}.node.vkey --output-bech32)     #New method since 1.23.0
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
#Save out the POOL-ID also in the xxx.id-bech file
file_unlock ${poolFile}.pool.id-bech
echo "${poolIDbech}" > ${poolFile}.pool.id-bech
file_lock ${poolFile}.pool.id-bech
file_unlock ${poolFile}.pool.json
newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolIDbech: \"${poolIDbech}\"}")
echo "${newJSON}" > ${poolFile}.pool.json
file_lock ${poolFile}.pool.json



#Check about Extended Metadata
extendedMetaEntry=
poolExtendedMetaUrl=$(jq -r .poolExtendedMetaUrl ${poolFile}.pool.json 2> /dev/null)

if [[ ${#poolExtendedMetaUrl} -gt 64 ]]; then echo -e "\e[35mERROR - The poolExtendedMetaUrl entry in your ${poolFile}.pool.json is too long. Max. 64 chars allowed !\e[0m\n\nPlease re-edit the poolExtendedMetaUrl entry in your ${poolFile}.pool.json, thx."; exit 1; fi
if [[ "${poolExtendedMetaUrl}" =~ https?://.* && ${#poolExtendedMetaUrl} -lt 65 ]]; then
	#OK, a extended MetaDataURL to an extra JSON file is present, so lets continue generate it

        if [ -f "${poolName}.additional-metadata.json" ]; then
		additionalMetadata=$(cat ${poolName}.additional-metadata.json | jq -rM . 2> /dev/null)
                if [[ $? -ne 0 ]]; then echo "ERROR - ${poolFile}.additional-metadata.json is not a valid JSON file"; exit 1; fi
		extendedMetaEntry=",\n  \"extended\": \"${poolExtendedMetaUrl}\""  #make sure here is the entry for the extended-metadata now
	else # additional-metadata.json is not present, generate a dummy one
	echo -e "\n\e[33m\"${poolFile}.additional-metadata.json\" does not exist, a dummy one was created, please edit it and retry.\e[0m";
	#Generate Dummy JSON File
echo "
{
  \"info\": {
        \"url_png_icon_64x64\": \"http(s) url to pool icon\",
        \"url_png_logo\": \"http(s) url to pool logo\",
        \"location\": \"Country, Continent\",
        \"social\": {
            \"twitter_handle\": \"\",
            \"telegram_handle\": \"\",
            \"facebook_handle\": \"\",
            \"youtube_handle\": \"\",
            \"twitch_handle\": \"\",
            \"discord_handle\": \"\",
	    \"github_handle\": \"\"
        },
        \"company\": {
            \"name\": \"\",
            \"addr\": \"\",
            \"city\": \"\",
            \"country\": \"\",
            \"company_id\": \"\",
            \"vat_id\": \"\"
        },
        \"about\": {
            \"me\": \"\",
            \"server\": \"\",
            \"company\": \"\"
        },
	\"rss\": \"http(s) url to valid RSS feed\"
    },

  \"telegram-admin-handle\": [
        \"\"
    ],

  \"my-pool-ids\": [
        \"${poolID}\"
    ],
  \"when-satured-then-recommend\": [
        \"${poolID}\"
    ]
}
" > ${poolFile}.additional-metadata.json

        fi

	#If ITN Keys are present, generate ITN-Witness entries. Using cardano-signer as a jcli substitute
	if [[ -f "${poolFile}.itn.skey" && -f "${poolFile}.itn.vkey" ]];
		then #Ok, itn secret and public key files are present

                        #Check the cardano-signer binary existance and version
                        if ! exists "${cardanosigner}"; then
                                #Try the one in the scripts folder
                                if [[ -f "${scriptDir}/cardano-signer" ]]; then cardanosigner="${scriptDir}/cardano-signer";
                                else majorError "Path ERROR - Path to the 'cardano-signer' binary is not correct or 'cardano-singer' binaryfile is missing!\nYou can find it here: https://github.com/gitmachtl/cardano-signer/releases\nThis is needed to generate the signed Metadata. Also please check your 00_common.sh or common.inc settings."; exit 1; fi
                        fi
                        cardanosignerCheck=$(${cardanosigner} --version 2> /dev/null)
                        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - This script needs a working 'cardano-signer' binary. Please make sure you have it present with with the right path in '00_common.sh' !\e[0m\n\n"; exit 1; fi
                        cardanosignerVersion=$(echo ${cardanosignerCheck} | cut -d' ' -f 2)
                        versionCheck "${minCardanoSignerVersion}" "${cardanosignerVersion}"
                        if [[ $? -ne 0 ]]; then majorError "Version ${cardanosignerVersion} ERROR - Please use a cardano-signer version ${minCardanoSignerVersion} or higher !\nOld versions are not compatible, please upgrade - thx."; exit 1; fi

                        echo -e "\e[0mSigning ITN-Wittness with Cardano-Signer Version: \e[32m${cardanosignerVersion}\e[0m";
                        showProcessAnimation "Signing " &
                        itnWitnessSign=$(${cardanosigner} sign --jcli --secret-key ${poolFile}.itn.skey --data-file "${poolFile}.pool.id" 2> /dev/stdout | awk {'print $1'})
                        stopProcessAnimation;
                        if [ $? -ne 0 ]; then echo -e "\e[35m${tmp}\e[0m\n"; exit $?; fi

			itnWitnessOwner=$(cat ${poolFile}.itn.vkey)
	                itnJSON=$(echo "{}" | jq ".itn += {owner: \"${itnWitnessOwner}\"}|.itn += {witness: \"${itnWitnessSign}\"}")
			extendedMetaEntry=",\n  \"extended\": \"${poolExtendedMetaUrl}\""

	fi
fi

#Combine the data for the extended-metadata.json if some data is present
if [[ ! "${extendedMetaEntry}" == "" ]]; then
	file_unlock ${poolFile}.extended-metadata.json
	echo "${itnJSON} ${additionalMetadata}" | jq -rs 'reduce .[] as $item ({}; . * $item)' > ${poolFile}.extended-metadata.json
	chmod 444 ${poolFile}.extended-metadata.json #Set it to 444, because it is public anyway so it can be copied over to a websever via scp too
fi

#Generate new <poolFile>.metadata.json File with the Entries and also read out the Hash of it
file_unlock ${poolFile}.metadata.json
echo -e "{
  \"name\": \"${poolMetaName}\",
  \"description\": \"${poolMetaDescription}\",
  \"ticker\": \"${poolMetaTicker}\",
  \"homepage\": \"${poolMetaHomepage}\"${extendedMetaEntry}
}" > ${poolFile}.metadata.json
chmod 444 ${poolFile}.metadata.json #Set it to 444, because it is public anyway so it can be copied over to a websever via scp too

#Check the Metadata file about the maximum size of 512 bytes
metaFileSize=$(du -b "${poolFile}.metadata.json" | cut -f1)
if [[ ${metaFileSize} -gt 512 ]]; then echo -e "\e[35mERROR - The total filesize of your ${poolFile}.metadata.json file is ${metaFileSize} bytes. Maximum allowed filesize is 512 bytes!\nPlease reduce the length of some entries (name, description, ticker, homepage, extended-meta-url).\e[0m"; exit 1; fi


#Generate HASH for the <poolFile>.metadata.json
poolMetaHash=$(${cardanocli} ${cliEra} stake-pool metadata-hash --pool-metadata-file ${poolFile}.metadata.json)
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#Add the HASH to the <poolFile>.pool.json info file
file_unlock ${poolFile}.pool.json
newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolMetaHash: \"${poolMetaHash}\"}")
echo "${newJSON}" > ${poolFile}.pool.json
file_lock ${poolFile}.pool.json


#Check if JSON file is a single owner (old) format than update the JSON with owner array and single owner
ownerType=$(jq -r '.poolOwner | type' ${poolFile}.pool.json)
if [[ "${ownerType}" == "string" ]]; then
        file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {poolOwner: [{\"ownerName\": \"${poolOwner}\"}]}")
	echo "${newJSON}" > ${poolFile}.pool.json
	file_lock ${poolFile}.pool.json
	ownerCnt=1  #of course it is 1, we just converted a singleowner json into an arrayowner json
else #already an array, so check the number of owners in there
	ownerCnt=$(jq -r '.poolOwner | length' ${poolFile}.pool.json)
fi


ownerKeys="" #building string for the certificate

rewardsAccountIncluded="no"

for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)

  #add the ownerWitness="local" field into the json file if missing - needed to set if a witness is local or external
  if [[ "$(jq -r .poolOwner[${tmpCnt}].ownerWitness ${poolFile}.pool.json)" == null ]]; then #if the ownerWitness entry in each owner entry is missing, add it
	file_unlock ${poolFile}.pool.json
        newJSON=$(cat ${poolFile}.pool.json | jq ".poolOwner[${tmpCnt}].ownerWitness = \"local\"")
        echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
  fi

  if [ ! -f "${ownerName}.staking.vkey" ]; then echo -e "\e[0mERROR - ${ownerName}.staking.vkey is missing! Check poolOwner/ownerName field in ${poolFile}.pool.json, or generate one with script 03a !\e[0m"; exit 1; fi
  #When we are in the loop, just build up also all the needed ownerkeys for the certificate
  ownerKeys="${ownerKeys} --pool-owner-stake-verification-key-file ${ownerName}.staking.vkey"
  if [[ "${ownerName}" == "${rewardsName}" ]]; then rewardsAccountIncluded="yes"; fi
done
#OK, all needed files are present, continue



######################################
#
# Show the summary
#
######################################

echo
echo -e "\e[0mCreate a Stakepool registration certificate for PoolNode with \e[32m ${poolName}.node.vkey, ${poolName}.vrf.vkey\e[0m:"
echo
echo -e "\e[0mOwner Stake Keys:\e[32m ${ownerCnt}\e[0m owner(s) with the key(s)"
for (( tmpCnt=0; tmpCnt<${ownerCnt}; tmpCnt++ ))
do
  ownerName=$(jq -r .poolOwner[${tmpCnt}].ownerName ${poolFile}.pool.json)
  echo -ne "\e[0m                 \e[32m ${ownerName}.staking.vkey \e[0m"
  if [[ "$(jq -r .description < ${ownerName}.staking.vkey)" == *"Hardware"* ]]; then echo -e "(Hardware-Key)"; else echo; fi
done
echo -ne "\e[0m   Rewards Stake:\e[32m ${rewardsName}.staking.vkey \e[0m"
  if [[ "$(jq -r .description < ${rewardsName}.staking.vkey)" == *"Hardware"* ]]; then echo -e "(Hardware-Key)"; else echo; fi
echo -e "\e[0m          Pledge:\e[32m ${poolPledge} \e[90mlovelaces \e[0m(\e[32m$(convertToADA ${poolPledge}) \e[90mADA\e[0m)"
echo -e "\e[0m            Cost:\e[32m ${poolCost} \e[90mlovelaces \e[0m(\e[32m$(convertToADA ${poolCost}) \e[90mADA\e[0m)"
echo -e "\e[0m          Margin:\e[32m ${poolMargin} \e[0m(\e[32m${poolMarginPct}%\e[0m)"
echo

#  Create a stake pool registration certificate

file_unlock ${poolName}.pool.cert
${cardanocli} ${cliEra} stake-pool registration-certificate --cold-verification-key-file ${poolName}.node.vkey --vrf-verification-key-file ${poolName}.vrf.vkey --pool-pledge ${poolPledge} --pool-cost ${poolCost} --pool-margin ${poolMargin} --pool-reward-account-verification-key-file ${rewardsName}.staking.vkey ${ownerKeys} ${poolRelays} --metadata-url ${poolMetaUrl} --metadata-hash ${poolMetaHash} --out-file ${poolName}.pool.cert
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

#No error, so lets update the pool JSON file with the date and file the certFile was created
if [[ $? -eq 0 ]]; then
	#Now include the checksum of this certificate also in the poolJson so we can check it in 05c
	#poolCertChecksum=$(cksum ${poolName}.pool.cert 2> /dev/null | awk '{ print $1 }')
	file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {regCertCreated: \"$(date -R)\"}" | jq ". += {regCertFile: \"${poolName}.pool.cert\"}")
	echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
fi

file_lock ${poolName}.pool.cert

#If there was a regKeyHash (regProtectionKey) present, update it in the pool json so it can be used in 05c and also offline
if [[ ! "${regKeyHash}" == "" ]]; then
	file_unlock ${poolFile}.pool.json
	newJSON=$(cat ${poolFile}.pool.json | jq ". += {regProtectionKey: \"${regKeyHash}\"}" )
        echo "${newJSON}" > ${poolFile}.pool.json
        file_lock ${poolFile}.pool.json
fi

echo
echo -e "\e[0mStakepool registration certificate:\e[32m ${poolName}.pool.cert \e[90m"
cat ${poolName}.pool.cert
echo

echo
echo -e "\e[0mStakepool Config JSON:\e[32m ${poolFile}.pool.json \e[90m"
cat ${poolFile}.pool.json
echo

echo -e "\e[0mStakepool Metadata JSON:\e[32m ${poolFile}.metadata.json"
echo -e "\e[0mFilesize:\e[32m ${metaFileSize} bytes \e[90m"
cat ${poolFile}.metadata.json
echo
echo -e "\e[33mDon't forget to upload your \e[32m${poolFile}.metadata.json\e[33m file now to your webserver (${poolMetaUrl}) before running 05b & 05c !"

if [[ ! "${extendedMetaEntry}" == "" ]]; then
echo
echo -e "\e[0mStakepool Extended-Metadata JSON:\e[32m ${poolFile}.extended-metadata.json \e[90m"
cat ${poolFile}.extended-metadata.json
echo
echo -e "\e[33mDon't forget to upload your \e[32m${poolFile}.extended-metadata.json\e[33m file now to your webserver (${poolExtendedMetaUrl}) before running 05b & 05c !"
fi


echo -e "\e[0m"
