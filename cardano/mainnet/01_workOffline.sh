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


#Display usage instructions
showUsage() {
cat >&2 <<EOF
Usage:    $(basename $0) new                ... Resets the '$(basename ${offlineFile})' with only the current protocol-parameters in it
          $(basename $0) info               ... Displayes the Address and TX info in the '$(basename ${offlineFile})'

	  $(basename $0) add mywallet       ... Adds the UTXO info of mywallet.addr to the '$(basename ${offlineFile})'
          $(basename $0) add owner.staking  ... Adds the Rewards info of owner.staking to the '$(basename ${offlineFile})'
          $(basename $0) add mydrep.drep    ... Adds the DRep info of mydrep.drep.id to the '$(basename ${offlineFile})'

          $(basename $0) execute            ... Executes the first cued transaction in the '$(basename ${offlineFile})'
          $(basename $0) execute 3          ... Executes the third cued transaction in the '$(basename ${offlineFile})'

          $(basename $0) attach <filename>  ... This will attach a small file <filename> into the '$(basename ${offlineFile})'
          $(basename $0) extract            ... Extract the attached files in the '$(basename ${offlineFile})'

          $(basename $0) cleartx            ... Removes the cued transactions in the '$(basename ${offlineFile})'
          $(basename $0) clearhistory       ... Removes the history in the '$(basename ${offlineFile})'
          $(basename $0) clearfiles         ... Removes the attached files in the '$(basename ${offlineFile})'

EOF
}

#Check commandline parameters
if [[ $# -eq 0 ]]; then $(showUsage); exit 1; fi
case ${1} in
  cleartx|clearhistory|clearfiles|extract|info )
		action="${1}"
		;;

  new|execute|clear )
		action="${1}";
		if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT MODE to do this!\e[0m\n"; exit 1; #exit if command is called in offline mode, needs to be in online mode
		elif [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mYour ONLINE/LIGHT Node must be fully synced, please wait a bit!\e[0m\n"; exit 1; #check that the node is fully synced
		fi

                if [[ $# -eq 2 ]]; then executeCue=${2}; else executeCue=1; fi
		;;

  add )
		action="${1}";
		if ${offlineMode}; then echo -e "\e[35mYou have to be in ONLINE or LIGHT MODE to do this!\e[0m\n"; exit 1; #exit if command is called in offline mode, needs to be in online mode
		elif [[ $(get_currentSync) != "synced" ]]; then echo -e "\e[35mYour ONLINE/LIGHT Node must be fully synced, please wait a bit!\e[0m\n"; exit 1; #check that the node is fully synced
		fi
		if [[ $# -eq 2 ]]; then

			#check what it is
			case "$(basename ${2})" in

				*".drep"*) #if it contains the string ".drep", check if there is a *.drep.id file
					drepName="$(dirname $2)/$(basename $2 .id)"; drepName=${drepName/#.\//};
					if [ ! -f "${drepName}.id" ]; then echo -e "\e[35mNo ${drepName}.id file found for adding a DRep!\e[0m\n"; showUsage; exit 1; fi
					action="add-drep";
					;;

				*) #nothing matched, should be a payment/stake address than. check that there is a *.addr file
					addrName="$(dirname $2)/$(basename $2 .addr)"; addrName=${addrName/#.\//};
					if [ ! -f "${addrName}.addr" ]; then echo -e "\e[35mNo ${addrName}.addr file found for adding a Address!\e[0m\n"; showUsage; exit 1; fi
					;;
			esac

		else
			echo -e "\e[35mMissing AddressName/DRepName for the Input!\e[0m\n"; showUsage; exit 1;
		fi # $# -eq 2
		;;

  attach )
                action="${1}";
                if [[ $# -eq 2 ]]; then fileToAttach="${2}"; else echo -e "\e[35mMissing File to attach!\e[0m\n"; showUsage; exit 1; fi
                if [ ! -f "${fileToAttach}" ]; then echo -e "\e[35mNo ${fileToAttach} file found on that location!\e[0m\n"; showUsage; exit 1; fi
                ;;

  * ) 		showUsage; exit 1;
		;;
esac


#Read the current offlineFile
if [ -f "${offlineFile}" ]; then
				offlineJSON=$(jq . ${offlineFile} 2> /dev/null)
				if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - '$(basename ${offlineFile})' is not a valid JSON file, please delete it.\e[0m\n"; exit 1; fi
				if [[ $(trimString "${offlineJSON}") == "" ]]; then offlineJSON="{}"; fi #nothing in the file, make a new one
			    else
				offlineJSON="{}";
			    fi


case ${action} in
  cleartx )
		#Clear the history entries from the offlineJSON
		offlineJSON=$( jq "del (.transactions)" <<< ${offlineJSON})
		offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"cleared all transactions\" } ]" <<< ${offlineJSON})
	        #Write the new offileFile content
	        echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
		echo -e "\e[33mTransactions in the '$(basename ${offlineFile})' have been cleared, you can start over.\e[0m\n";
		exit;
                ;;

  clearhistory )
		#Clear the history entries from the offlineJSON
                offlineJSON=$( jq "del (.history)" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"history cleared\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
                echo -e "\e[33mWho needs History in the '$(basename ${offlineFile})', cleared. :-)\e[0m\n";
                exit;
                ;;

  clearfiles )
                #Clear the files entries from the offlineJSON
                offlineJSON=$( jq "del (.files)" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"attached files cleared\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
                showOfflineFileInfo;
                echo -e "\e[33mAll attached files within the '$(basename ${offlineFile})' were cleared. :-)\e[0m\n";
                exit;
                ;;

  new|clear )
		#Build a fresh new offlineJSON with the current protocolParameters in it
		offlineJSON="{}";

		#Read ProtocolParameters
		case ${workMode} in

		        "online") #onlinemode
				#get the normal parameters
				protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters )

				#Governance Stuff
				governanceParametersJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/null | jq -r '{ committee : (.committee), constitution : (.constitution), prevActionIDs : (.nextRatifyState.nextEnactState.prevGovActionIds) }' 2> /dev/null)
				if [[ "${governanceParametersJSON}" == "" ]]; then governanceParametersJSON="{}"; fi

				#Era-History
				eraHistoryJSON=$(${cardanocli} ${cliEra} query era-history --out-file /dev/stdout 2> /dev/null | jq -r "{ \"eraHistory\": . }")
				if [[ "${eraHistoryJSON}" == "" ]]; then eraHistoryJSON="{ \"eraHistory\": {} }"; fi

				#merge them together
	                        protocolParametersJSON=$( jq --sort-keys ". += ${governanceParametersJSON} | . += ${eraHistoryJSON} " <<< ${protocolParametersJSON})
				;;

		        "light") #lightmode
				protocolParametersJSON=${lightModeParametersJSON}
				;;

		esac
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		offlineJSON=$( jq ".general += {onlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
		if ${fullMode}; then
			offlineJSON=$( jq ".general += {onlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
			else
			offlineJSON=$( jq ".general += {onlineNODE: \"light\" }" <<< ${offlineJSON})
		fi

		offlineJSON=$( jq ".protocol += {parameters: ${protocolParametersJSON} }" <<< ${offlineJSON})
		offlineJSON=$( jq ".protocol += {era: \"$(get_NodeEra)\" }" <<< ${offlineJSON})
                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"new file created - ${workMode} mode\" } ]" <<< ${offlineJSON})
                #Write the new offileFile content
                echo "${offlineJSON}" > ${offlineFile}
		showOfflineFileInfo;
                echo -e "\e[33mThe '$(basename ${offlineFile})' has been set to a good looking and clean fresh state. :-)\e[0m\n";
                exit;
                ;;

  add|add-drep )
		#Updating the current protocolParameters before doing other stuff later on
		case ${workMode} in

		        "online") #onlinemode
				#get the normal parameters
				protocolParametersJSON=$(${cardanocli} ${cliEra} query protocol-parameters )

				#Governance Stuff
				governanceParametersJSON=$(${cardanocli} ${cliEra} query gov-state 2> /dev/null | jq -r '{ committee : (.committee), constitution : (.constitution), prevActionIDs : (.nextRatifyState.nextEnactState.prevGovActionIds) }' 2> /dev/null)
				if [[ "${governanceParametersJSON}" == "" ]]; then governanceParametersJSON="{}"; fi

				#Era-History
				eraHistoryJSON=$(${cardanocli} ${cliEra} query era-history --out-file /dev/stdout 2> /dev/null | jq -r "{ \"eraHistory\": . }")
				if [[ "${eraHistoryJSON}" == "" ]]; then eraHistoryJSON="{ \"eraHistory\": {} }"; fi

				#merge them together
	                        protocolParametersJSON=$( jq --sort-keys ". += ${governanceParametersJSON} | . += ${eraHistoryJSON} " <<< ${protocolParametersJSON})
				;;

		        "light") #lightmode
				protocolParametersJSON=${lightModeParametersJSON}
				;;

		esac
		checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

		offlineJSON=$( jq ".general += {onlineCLI: \"${versionCLI}\" }" <<< ${offlineJSON})
		if ${fullMode}; then
			offlineJSON=$( jq ".general += {onlineNODE: \"${versionNODE}\" }" <<< ${offlineJSON})
			else
			offlineJSON=$( jq ".general += {onlineNODE: \"light\" }" <<< ${offlineJSON})
		fi

                offlineJSON=$( jq ".protocol += {parameters: ${protocolParametersJSON} }" <<< ${offlineJSON})
                offlineJSON=$( jq ".protocol += {era: \"$(get_NodeEra)\" }" <<< ${offlineJSON})
                ;;


  info )
		#Displays infos about the content in the offlineJSON
		showOfflineFileInfo;

		#Check if there are any files attached
		filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
		if [[ ${filesCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${filesCnt} files attached in the '$(basename ${offlineFile})'. You can extract them by running the command: $(basename $0) extract\e[0m\n"; fi

		#Check the number of pending transactions
		transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
		if [[ ${transactionsCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${transactionsCnt} pending transactions in the '$(basename ${offlineFile})'. You can submit them by running the command: $(basename $0) execute\e[0m\n"; fi
		exit;
		;;

  attach )
		#Attach a given File into the offlineJSON
                readOfflineFile;
                offlineJSON=$( jq ".files.\"${fileToAttach}\" += { date: \"$(date -R)\", size: \"$(du -b ${fileToAttach} | cut -f1)\", base64: \"$(base64 -w 0 ${fileToAttach})\" }" <<< ${offlineJSON});

                if [[ $? -eq 0 ]]; then
                                        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"attached file '${fileToAttach}'\" } ]" <<< ${offlineJSON})
                                        echo "${offlineJSON}" > ${offlineFile}
                			showOfflineFileInfo;
                			echo -e "\e[33mFile '${fileToAttach}' was attached into the '$(basename ${offlineFile})'. :-)\e[0m\n";
				   else
                                        echo -e "\e[35mERROR - Could not attach file '${fileToAttach}' to the '$(basename ${offlineFile})'. :-)\e[0m\n"; exit 1;
				   fi
                exit;
		;;

esac


###########################################
###
### action = add
###
###########################################
#
# START

if [[ "${action}" == "add" ]]; then

checkAddr=$(cat ${addrName}.addr)

typeOfAddr=$(get_addressType "${checkAddr}")

#What type of Address is it? Base&Enterprise or Stake
if [[ ${typeOfAddr} == ${addrTypePayment} ]]; then  #Enterprise and Base UTXO adresses

	echo -e "\e[0mChecking UTXOs of Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

	echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
	echo

        #Get UTX0 Data for the address. When in online mode of course from the node and the chain, in lightmode via API requests
        case ${workMode} in
                "online")       #check that the node is fully synced, otherwise the query would mabye return a false state
                                showProcessAnimation "Query-UTXO: " &
                                utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${checkAddr} 2> /dev/stdout);
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${checkAddr}"); stopProcessAnimation;
                                ;;

                "light")        showProcessAnimation "Query-UTXO-LightMode: " &
                                utxo=$(queryLight_UTXO "${checkAddr}");
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                showProcessAnimation "Convert-UTXO: " &
                                utxoJSON=$(generate_UTXO "${utxo}" "${checkAddr}"); stopProcessAnimation;
                                ;;
        esac

        utxoEntryCnt=$(jq length <<< ${utxoJSON})
        if [[ ${utxoEntryCnt} == 0 ]]; then echo -e "\e[35mNo funds on the Address!\e[0m\n"; exit 1; else echo -e "\e[32m${utxoEntryCnt} UTXOs\e[0m found on the Address!"; fi
        echo

        totalLovelaces=0;       #Init for the Sum
        totalAssetsJSON="{}"; #Building a total JSON with the different assetstypes "policyIdHash.name", amount and name
        totalPolicyIDsLIST=""; #Buffer for the policyIDs, will be sorted/uniq/linecount at the end of the query

        #For each utxo entry, check the utxo#index and check if there are also any assets in that utxo#index
        #LEVEL 1 - different UTXOs

        readarray -t utxoHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${utxoJSON})
        readarray -t utxoLovelaceArray <<< $(jq -r "flatten | .[].value.lovelace" <<< ${utxoJSON})
        readarray -t assetsEntryCntArray <<< $(jq -r "flatten | .[].value | del (.lovelace) | length" <<< ${utxoJSON})
        readarray -t assetsEntryJsonArray <<< $(jq -c "flatten | .[].value | del (.lovelace)" <<< ${utxoJSON})
        readarray -t utxoDatumHashArray <<< $(jq -r "flatten | .[].datumhash" <<< ${utxoJSON})


        for (( tmpCnt=0; tmpCnt<${utxoEntryCnt}; tmpCnt++ ))
        do
        utxoHashIndex=${utxoHashIndexArray[${tmpCnt}]}
        utxoAmount=${utxoLovelaceArray[${tmpCnt}]} #Lovelaces
        totalLovelaces=$(bc <<< "${totalLovelaces} + ${utxoAmount}" )
#       echo -e "Hash#Index: ${utxoHashIndex}\tAmount: ${utxoAmount}";
        echo -e "Hash#Index: ${utxoHashIndex}\tADA: $(convertToADA ${utxoAmount}) \e[90m(${utxoAmount} lovelaces)\e[0m";
        if [[ ! "${utxoDatumHashArray[${tmpCnt}]}" == null ]]; then echo -e " DatumHash: ${utxoDatumHashArray[${tmpCnt}]}"; fi
        assetsEntryCnt=${assetsEntryCntArray[${tmpCnt}]}

        if [[ ${assetsEntryCnt} -gt 0 ]]; then

                        assetsJSON=${assetsEntryJsonArray[${tmpCnt}]}
                        assetHashIndexArray=(); readarray -t assetHashIndexArray <<< $(jq -r "keys_unsorted[]" <<< ${assetsJSON})
                        assetNameCntArray=(); readarray -t assetNameCntArray <<< $(jq -r "flatten | .[] | length" <<< ${assetsJSON})

                        #LEVEL 2 - different policyIDs
                        for (( tmpCnt2=0; tmpCnt2<${assetsEntryCnt}; tmpCnt2++ ))
                        do
                        assetHash=${assetHashIndexArray[${tmpCnt2}]} #assetHash = policyID
                        totalPolicyIDsLIST+="${assetHash}\n"

                        assetsNameCnt=${assetNameCntArray[${tmpCnt2}]}
                        assetNameArray=(); readarray -t assetNameArray <<< $(jq -r ".\"${assetHash}\" | keys_unsorted[]" <<< ${assetsJSON})
                        assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r ".\"${assetHash}\" | flatten | .[]" <<< ${assetsJSON})

                               #LEVEL 3 - different names under the same policyID
                                for (( tmpCnt3=0; tmpCnt3<${assetsNameCnt}; tmpCnt3++ ))
                                do
                                assetName=${assetNameArray[${tmpCnt3}]}
                                assetAmount=${assetAmountArray[${tmpCnt3}]}
                                assetBech=$(convert_tokenName2BECH "${assetHash}${assetName}" "")
                                if [[ "${assetName}" == "" ]]; then point=""; else point="."; fi
                                oldValue=$(jq -r ".\"${assetHash}${point}${assetName}\".amount" <<< ${totalAssetsJSON})
                                newValue=$(bc <<< "${oldValue}+${assetAmount}")
                                assetTmpName=$(convert_assetNameHEX2ASCII_ifpossible "${assetName}") #if it starts with a . -> ASCII showable name, otherwise the HEX-String
                                totalAssetsJSON=$( jq ". += {\"${assetHash}${point}${assetName}\":{amount: \"${newValue}\", name: \"${assetTmpName}\", bech: \"${assetBech}\"}}" <<< ${totalAssetsJSON})
                                if [[ "${assetTmpName:0:1}" == "." ]]; then assetTmpName=${assetTmpName:1}; else assetTmpName="{${assetTmpName}}"; fi

                                case "${assetHash}${assetTmpName:1:8}" in
                                        "${adahandlePolicyID}000de140" )        #$adahandle cip-68
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Own): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}00000000" )        #$adahandle virtual
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Vir): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}000643b0" )        #$adahandle reference
                                                assetName=${assetName:8};
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle(Ref): \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        "${adahandlePolicyID}"* )               #$adahandle cip-25
                                                echo -e "\e[90m                           Asset: ${assetBech}  \e[33mADA Handle: \$$(convert_assetNameHEX2ASCII ${assetName}) ${assetTmpName}\e[0m"
                                                ;;
                                        * ) #default
                                                echo -e "\e[90m                           Asset: ${assetBech}  Amount: ${assetAmount} ${assetTmpName}\e[0m"
                                                ;;
                                esac

                                done
                        done
        fi
        done
        echo -e "\e[0m-----------------------------------------------------------------------------------------------------"
        echo -e "Total ADA on the Address:\e[32m $(convertToADA ${totalLovelaces}) ADA / ${totalLovelaces} lovelaces \e[0m\n"

        totalPolicyIDsCnt=$(echo -ne "${totalPolicyIDsLIST}" | sort | uniq | wc -l)

        totalAssetsCnt=$(jq length <<< ${totalAssetsJSON});
        if [[ ${totalAssetsCnt} -gt 0 ]]; then
                        echo -e "\e[32m${totalAssetsCnt} Asset-Type(s) / ${totalPolicyIDsCnt} different PolicyIDs\e[0m found on the Address!\n"
                        printf "\e[0m%-56s%11s    %16s %-44s  %7s  %s\n" "PolicyID:" "Asset-Name:" "Total-Amount:" "Bech-Format:" "Ticker:" "Meta-Name:"

                        totalAssetsJSON=$(jq --sort-keys . <<< ${totalAssetsJSON}) #sort the json by the hashname
                        assetHashNameArray=(); readarray -t assetHashNameArray <<< $(jq -r "keys_unsorted[]" <<< ${totalAssetsJSON})
                        assetAmountArray=(); readarray -t assetAmountArray <<< $(jq -r "flatten | .[].amount" <<< ${totalAssetsJSON})
                        assetNameArray=(); readarray -t assetNameArray <<< $(jq -r "flatten | .[].name" <<< ${totalAssetsJSON})
                        assetBechArray=(); readarray -t assetBechArray <<< $(jq -r "flatten | .[].bech" <<< ${totalAssetsJSON})

                        for (( tmpCnt=0; tmpCnt<${totalAssetsCnt}; tmpCnt++ ))
                        do
                        assetHashName=${assetHashNameArray[${tmpCnt}]}
                        assetAmount=${assetAmountArray[${tmpCnt}]}
                        assetName=${assetNameArray[${tmpCnt}]}
                        assetBech=${assetBechArray[${tmpCnt}]}
                        assetHashHex="${assetHashName//./}" #remove a . if present, we need a clean subject here for the registry request

                        if $queryTokenRegistry; then #if activated, check the current asset on the metadata server. if data is available, include it in the offlineJSON in a compact format
				metaResponse=$(curl -sL -m 20 "${tokenMetaServer}/${assetHashHex}")
                                metaAssetName=$(jq -r ".name.value | select (.!=null)" 2> /dev/null <<< ${metaResponse}); if [[ ! "${metaAssetName}" == "" ]]; then metaAssetName="${metaAssetName} "; fi
                                metaAssetTicker=$(jq -r ".ticker.value | select (.!=null)" 2> /dev/null <<< ${metaResponse})
				if [[ "${metaAssetName}" != "" || "${metaAssetTicker}" != "" ]]; then
					#reduce the keys in metaResponse to only name and ticker. remove the subkeys signatures and sequenceNumber to safe some storage space
					offlineJSON=$( jq ".tokenMetaServer.\"${assetHashHex}\" += $(jq -cM "{name,ticker} | del(.[].signatures,.[].sequenceNumber)" <<< ${metaResponse} 2> /dev/null)" <<< ${offlineJSON})
				fi
                        fi

                        if [[ "${assetName}" == "." ]]; then assetName=""; fi

                        printf "\e[90m%-70s \e[32m%16s %44s  \e[90m%-7s  \e[36m%s\e[0m\n" "${assetHashName:0:56}${assetName}" "${assetAmount}" "${assetBech}" "${metaAssetTicker}" "${metaAssetName}"
                        done
        fi
	echo

	#Add this address to the offline.json file
	offlineJSON=$( jq ".address.\"${checkAddr}\" += {name: \"${addrName}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalamount: ${totalLovelaces} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalassetscnt: ${totalAssetsCnt} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {date: \"$(date -R)\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {used: \"no\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {type: \"${typeOfAddr}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {utxoJSON: ${utxoJSON} }" <<< ${offlineJSON})

        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"added utxo-info for '${addrName}'\" } ]" <<< ${offlineJSON})

	#Write the new offileFile content
	echo "${offlineJSON}" > ${offlineFile}

	#Readback the content and compare it to the current one
	utxoJSON=$(jq . <<< ${utxoJSON}) # bring it into the same format
        readback=$(cat ${offlineFile} | jq -r ".address.\"${checkAddr}\".utxoJSON")
        if [[ "${utxoJSON}" == "${readback}" ]]; then
							showOfflineFileInfo;
							echo -e "\e[33mLatest Information about this address was added to the '$(basename ${offlineFile})'.\nYou can now transfer it to your offline machine to work with it, or you can\nadd another address information to the file by re-running this script.\e[0m\n";
						 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the '$(basename ${offlineFile})'. Retry or delete the offlineFile and retry again.\e[0m\n";
	fi


elif [[ ${typeOfAddr} == ${addrTypeStake} ]]; then  #Staking Address

	echo -e "\e[0mChecking Rewards on Stake-Address-File\e[32m ${addrName}.addr\e[0m: ${checkAddr}"
	echo

        echo -e "\e[0mAddress-Type / Era:\e[32m $(get_addressType "${checkAddr}")\e[0m / \e[32m$(get_addressEra "${checkAddr}")\e[0m"
        echo

        #Get rewards state data for the address. When in online mode of course from the node and the chain, in light mode via koios
        case ${workMode} in

                "online")       showProcessAnimation "Query-StakeAddress-Info: " &
                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${checkAddr} 2> /dev/null )
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                rewardsJSON=$(jq . <<< "${rewardsJSON}")
                                ;;

                "light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
                                rewardsJSON=$(queryLight_stakeAddressInfo "${checkAddr}")
                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
                                ;;
        esac

        rewardsEntryCnt=$(jq -r 'length' <<< ${rewardsJSON})

        if [[ ${rewardsEntryCnt} == 0 ]]; then echo -e "\e[35mStaking Address is not on the chain, register it first !\e[0m\n"; exit 1;
        else echo -e "\e[0mFound:\e[32m ${rewardsEntryCnt}\e[0m entries\n";
        fi

        rewardsSum=0

        for (( tmpCnt=0; tmpCnt<${rewardsEntryCnt}; tmpCnt++ ))
        do
        rewardsAmount=$(jq -r ".[${tmpCnt}].rewardAccountBalance" <<< ${rewardsJSON})
	rewardsAmountInADA=$(bc <<< "scale=6; ${rewardsAmount} / 1000000")

        delegationPoolID=$(jq -r ".[${tmpCnt}].delegation // .[${tmpCnt}].stakeDelegation" <<< ${rewardsJSON})

        rewardsSum=$((${rewardsSum}+${rewardsAmount}))
	rewardsSumInADA=$(bc <<< "scale=6; ${rewardsSum} / 1000000")

        echo -ne "[$((${tmpCnt}+1))]\t"

        #Checking about rewards on the stake address
        if [[ ${rewardsAmount} == 0 ]]; then echo -e "\e[35mNo rewards found on the stake Addr !\e[0m";
        else echo -e "Entry Rewards: \e[33m${rewardsAmountInADA} ADA / ${rewardsAmount} lovelaces\e[0m"
        fi

        #If delegated to a pool, show the current pool ID
        if [[ ! ${delegationPoolID} == null ]]; then echo -e "   \tAccount is delegated to a Pool with ID: \e[32m${delegationPoolID}\e[0m"; fi

        echo

        done

        if [[ ${rewardsEntryCnt} -gt 1 ]]; then echo -e "   \t-----------------------------------------\n"; echo -e "   \tTotal Rewards: \e[33m${rewardsSumInADA} ADA / ${rewardsSum} lovelaces\e[0m\n"; fi

        #Add this address to the offline.json file
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {name: \"${addrName}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {totalamount: ${rewardsSum} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {date: \"$(date -R)\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {used: \"no\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {type: \"${typeOfAddr}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".address.\"${checkAddr}\" += {rewardsJSON: ${rewardsJSON} }" <<< ${offlineJSON})

        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"added stake address rewards-state for '${addrName}'\" } ]" <<< ${offlineJSON})

        #Write the new offileFile content
        echo "${offlineJSON}" > ${offlineFile}

        #Readback the content and compare it to the current one
        rewardsJSON=$(jq . <<< ${rewardsJSON}) # bring it into the same format
        readback=$(cat ${offlineFile} | jq -r ".address.\"${checkAddr}\".rewardsJSON")
        if [[ "${rewardsJSON}" == "${readback}" ]]; then
							showOfflineFileInfo;
							echo -e "\e[33mLatest Information about this address was added to the '$(basename ${offlineFile})'.\nYou can now transfer it to your offline machine to work with it, or you can\nadd another address information to the file by re-running this script.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the offlineFile '${offlineFile}'. Retry or delete the offlineFile and retry again.\e[0m\n";
        fi


else #unsupported address type

	echo -e "\e[35mAddress type unknown!\e[0m"; exit 1;
fi

fi # END
#
###########################################
###
### action = add
###
###########################################


###########################################
###
### action = add-drep
###
###########################################
#
# START

if [[ "${action}" == "add-drep" ]]; then

drepID=$(cat ${drepName}.id) #we already checked that the file is present, so load the id from it

#calculate the drep hash, and also do a bech validity check
drepHASH=$(${bech32_bin} 2> /dev/null <<< "${drepID}")
if [ $? -ne 0 ]; then echo -e "\e[35mERROR - The content of '${drepName}.id' is not a valid DRep-Bech-ID.\e[0m\n"; exit 1; fi;

        echo -e "\e[0mChecking current Status about the DRep-ID:\e[32m ${drepID}\e[0m\n"

        #Get state data for the drepID. When in online mode of course from the node and the chain, in light mode via koios
        case ${workMode} in


	        "online")       showProcessAnimation "Query DRep-ID Info: " &
	                        drepStateJSON=$(${cardanocli} ${cliEra} query drep-state --drep-key-hash ${drepHASH} --drep-script-hash ${drepHASH} --include-stake 2> /dev/stdout )
	                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                        drepStateJSON=$(jq -r ".[0] // []" <<< "${drepStateJSON}") #get rid of the outer array
	                        ;;

	        "light")        showProcessAnimation "Query DRep-ID-Info-LightMode: " &
	                        drepStateJSON=$(queryLight_drepInfo "${drepID}")
	                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${drepStateJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
	                        drepStateJSON=$(jq -r ".[0] // []" <<< "${drepStateJSON}") #get rid of the outer array
	                        ;;
        esac

	{ read drepEntryCnt;
	  read drepDepositAmount;
	  read drepAnchorURL;
	  read drepAnchorHASH;
	  read drepExpireEpoch;
	  read drepDelegatedStake; } <<< $(jq -r 'length, .[1].deposit, .[1].anchor.url // "empty", .[1].anchor.dataHash // "no hash", .[1].expiry // "-", .[1].stake // 0' <<< ${drepStateJSON})

        #Checking about the content
        if [[ ${drepEntryCnt} == 0 ]]; then #not registered yet
                echo -e "\e[0mDRep-ID is NOT on the chain, we will add this information to register it offline.\e[0m\n";
	else
		echo -e "\e[0mDRep-ID is \e[32mregistered\e[0m on the chain with a deposit of \e[32m${drepDepositAmount}\e[0m lovelaces"
		echo -e "\e[0mCurrent Anchor-URL(HASH):\e[94m ${drepAnchorURL} (${drepAnchorHASH})\e[0m"
	        echo -e "\e[0m    Current Expire-Epoch:\e[32m ${drepExpireEpoch}\e[0m"
	        echo -e "\e[0m Current Delegated-Stake:\e[32m $(convertToADA ${drepDelegatedStake}) ADA\e[0m\n"
	fi

        echo

        #Add this DRep-ID to the offline.json file
        offlineJSON=$( jq ".drep.\"${drepID}\" += {name: \"${drepName}\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".drep.\"${drepID}\" += {deposit: ${drepDepositAmount} }" <<< ${offlineJSON})
        offlineJSON=$( jq ".drep.\"${drepID}\" += {date: \"$(date -R)\" }" <<< ${offlineJSON})
        offlineJSON=$( jq ".drep.\"${drepID}\" += {drepStateJSON: ${drepStateJSON} }" <<< ${offlineJSON})

        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"added drep-id info for '${drepName}'\" } ]" <<< ${offlineJSON})

        #Write the new offileFile content
        echo "${offlineJSON}" > ${offlineFile}

        #Readback the content and compare it to the current one
        readback=$(cat ${offlineFile} | jq -r ".drep.\"${drepID}\".drepStateJSON")
        if [[ "${drepStateJSON}" == "${readback}" ]]; then
							showOfflineFileInfo;
							echo -e "\e[33mLatest Information about this DRep-ID was added to the '$(basename ${offlineFile})'.\nYou can now transfer it to your offline machine to work with it, or you can\nadd another address/drep information to the file by re-running this script.\e[0m\n";
                                                 else
                                                        echo -e "\e[35mERROR - Could not verify the written data in the offlineFile '${offlineFile}'. Retry or delete the offlineFile and retry again.\e[0m\n";
        fi

fi # END
#
###########################################
###
### action = add-drep
###
###########################################


###########################################
###
### action = execute
###
###########################################
#
# START

if [[ "${action}" == "execute" ]]; then

#Show Information first
showOfflineFileInfo;

#Check the number of pending transactions
transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
if [[ ${transactionsCnt} -eq 0 ]]; then echo -e "\e[33mNo pending transactions found in the '$(basename ${offlineFile})'.\e[0m\n"; exit; fi

#Check that the online and offline cli version is the same
offlineVersionCLI=$(jq -r ".general.offlineCLI" <<< ${offlineJSON})
if [[ ! "${offlineVersionCLI}" == "${versionCLI}" ]]; then echo -e "\e[33mWARNING - Online(${versionCLI}) and Offline(${offlineVersionCLI}) CLI version mismatch, but will try to continue.\e[0m\n"; fi

if [[ ${executeCue} -gt 0 && ${executeCue} -le ${transactionsCnt} ]]; then transactionCue=${executeCue}; else echo -e "\e[35mERROR - There is no cued transaction with ID=${executeCue} available!\e[0m\n"; exit 1; fi
transactionIdx=$(( ${transactionCue} - 1 ));

#Execute the first or given transaction in cue
echo "------------------"
echo
echo -e "\e[33mExecute Transaction in Cue [${transactionCue}]: "
echo

#Check that the protocol era is still the same
transactionEra=$(jq -r ".transactions[${transactionIdx}].era" <<< ${offlineJSON})
if [[ ! "${transactionEra}" == "$(get_NodeEra)" ]]; then echo -e "\e[33mWARNING - Online($(get_NodeEra)) and Offline(${transactionEra}) Era mismatch, but will try to continue.\e[0m\n";fi

transactionType=$(jq -r ".transactions[${transactionIdx}].type" <<< ${offlineJSON})
transactionDate=$(jq -r ".transactions[${transactionIdx}].date" <<< ${offlineJSON})
transactionFromName=$(jq -r ".transactions[${transactionIdx}].fromAddr" <<< ${offlineJSON})
transactionFromAddr=$(jq -r ".transactions[${transactionIdx}].sendFromAddr" <<< ${offlineJSON})
transactionToName=$(jq -r ".transactions[${transactionIdx}].toAddr" <<< ${offlineJSON})
transactionToAddr=$(jq -r ".transactions[${transactionIdx}].sendToAddr" <<< ${offlineJSON})
transactionTxJSON=$(jq -r ".transactions[${transactionIdx}].txJSON" <<< ${offlineJSON})

#Write out the TxJSON to a temporary file
txFile="${tempDir}/$(basename ${transactionFromName}).tmp.txfile"
rm ${txFile} 2> /dev/null #delete an old one if present
echo "${transactionTxJSON}" > ${txFile};
checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi

case ${transactionType} in

        Transaction|Asset-Minting|Asset-Burning )
			#Normal UTXO Transaction (lovelaces and/or tokens)

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

			if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

			echo -e "\e[32m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] from '${transactionFromName}' to '${transactionToName}' \e[90m(${transactionDate})\n\t   \t\e[90mfrom ${transactionFromAddr}\n\t   \t\e[90mto ${transactionToAddr}\e[0m"
			echo

			if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}) #mark payment address as used
				if [[ ! "$(jq -r .address.\"${transactionToAddr}\" <<< ${offlineJSON})" == null ]]; then offlineJSON=$( jq ".address.\"${transactionToAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}); fi #mark destination address as used if present
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - utxo from '${transactionFromName}' to '${transactionToName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
				showOfflineFileInfo;
				echo
        		fi
                        ;;


        Withdrawal )
                        #Rewards Withdrawal Transaction
                        transactionStakeName=$(jq -r ".transactions[${transactionIdx}].stakeAddr" <<< ${offlineJSON})
                        transactionStakeAddr=$(jq -r ".transactions[${transactionIdx}].stakingAddr" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON} 2> /dev/null) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

			if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

			#Check that the RewardsState of the StakeAddress (transactionStakeAddr) has not changed
		        case ${workMode} in

		                "online")       showProcessAnimation "Query-StakeAddress-Info: " &
		                                rewardsJSON=$(${cardanocli} ${cliEra} query stake-address-info --address ${transactionStakeAddr} 2> /dev/null )
		                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
		                                ;;

				"light")        showProcessAnimation "Query-StakeAddress-Info-LightMode: " &
		                                rewardsJSON=$(queryLight_stakeAddressInfo "${transactionStakeAddr}")
		                                if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${rewardsJSON}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
		                                ;;
		        esac
			rewardsLiveJSON=$(jq . <<< ${rewardsJSON} 2> /dev/null)

                        rewardsOfflineJSON=$(jq -r ".address.\"${transactionStakeAddr}\".rewardsJSON" <<< ${offlineJSON})

			if [[ ! "${rewardsLiveJSON}" == "${rewardsOfflineJSON}" ]]; then echo -e "\e[35mERROR - The rewards state between the offline capture and now has changed for the stake address '${transactionStakeName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[32m\t[${transactionCue}]\t\e[0mRewards-Withdrawal[${transactionEra}] from '${transactionStakeName}' to '${transactionToName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mfrom ${transactionStakeAddr}\n\t   \t\e[90mto ${transactionToAddr}\n\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
				offlineJSON=$( jq ".address.\"${transactionStakeAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
				if [[ ! "$(jq -r .address.\"${transactionToAddr}\" <<< ${offlineJSON})" == null ]]; then offlineJSON=$( jq ".address.\"${transactionToAddr}\" += {used: \"yes\" }" <<< ${offlineJSON}); fi #mark destination address as used if present
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - withdrawal from '${transactionStakeName}' to '${transactionToName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
			;;


        StakeKeyRegistration|StakeKeyDeRegistration )
                        #StakeKey Registration of De-Registration Transaction
                        transactionStakeName=$(jq -r ".transactions[${transactionIdx}].stakeAddr" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

			if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for '${transactionStakeName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for '${transactionStakeName}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        DelegationCertRegistration|VoteDelegationCertRegistration )
                        #StakeKey Registration of De-Registration Transaction
                        transactionDelegName=$(jq -r ".transactions[${transactionIdx}].delegName" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

	             	if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDelegName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for '${transactionDelegName}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        DRepIDRegistration|DRepIDReRegistration|DRepIDRetirement )
                        #DRep-ID Registration, Update or Retirement Transaction
                        transactionDRepName=$(jq -r ".transactions[${transactionIdx}].drepName" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

	             	if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for '${transactionDRepName}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
				offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for '${transactionDRepName}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        PoolRegistration|PoolReRegistration )
                        #Pool Registration, Re-Registration
                        poolMetaTicker=$(jq -r ".transactions[${transactionIdx}].poolMetaTicker" <<< ${offlineJSON})
                        poolMetaUrl=$(jq -r ".transactions[${transactionIdx}].poolMetaUrl" <<< ${offlineJSON})
                        poolMetaHash=$(jq -r ".transactions[${transactionIdx}].poolMetaHash" <<< ${offlineJSON})
                        regProtectionKey=$(jq -r ".transactions[${transactionIdx}].regProtectionKey" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

 	        	if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

		        #Check if the regProtectionKey is correct, this is a service to not have any duplicated Tickers on the Chain. If you know how to code you can see that it is easy, just a little protection for Noobs
		        echo -ne "\e[0m\x54\x69\x63\x6B\x65\x72\x20\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x43\x68\x65\x63\x6B\x20\x66\x6F\x72\x20\x54\x69\x63\x6B\x65\x72\x20'\e[32m${poolMetaTicker}\e[0m': "
		        checkResult=$(curl -m 20 -s $(echo -e "\x68\x74\x74\x70\x73\x3A\x2F\x2F\x6D\x79\x2D\x69\x70\x2E\x61\x74\x2F\x63\x68\x65\x63\x6B\x74\x69\x63\x6B\x65\x72\x3F\x74\x69\x63\x6B\x65\x72\x3D${poolMetaTicker}&key=${regProtectionKey}") );
		        if [[ $? -ne 0 ]]; then echo -e "\e[33m\x50\x72\x6F\x74\x65\x63\x74\x69\x6F\x6E\x20\x53\x65\x72\x76\x69\x63\x65\x20\x6F\x66\x66\x6C\x69\x6E\x65\e[0m";
		                           else
		                                if [[ ! "${checkResult}" == "OK" ]]; then
		                                                                echo -e "\e[35mFailed\e[0m";
		                                                                echo -e "\n\e[35mERROR - This Stakepool-Ticker '${poolMetaTicker}' is protected, your need the right registration-protection-key to interact with this Ticker!\n";
		                                                                echo -e "If you wanna protect your Ticker too, please reach out to @atada_stakepool on Telegram to get your unique ProtectionKey, Thx !\e[0m\n\n"; exit 1;
		                                                         else
		                                                                echo -e "\e[32mOK\e[0m";
		                                fi
		        fi
		        echo

		        #Metadata-JSON HASH PreCheck: Check and compare the online metadata.json file hash with
		        #the one in the currently pool.json file. If they match up, continue. Otherwise exit with an ERROR
		        #Fetch online metadata.json file from the pool webserver
		        echo -ne "\e[0mMetadata HASH Check, fetching the MetaData JSON file from \e[32m${poolMetaUrl}\e[0m: "
		        tmpMetadataJSON="${tempDir}/tmpmetadata.json"
			curl -sL "${poolMetaUrl}" --output "${tmpMetadataJSON}"
		        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR, can't fetch the metadata file from the webserver!\e[0m\n"; exit 1; fi
		        #Check the downloaded data that is a valid JSON file
			tmpCheckJSON=$(jq . "${tmpMetadataJSON}" 2> /dev/null)
		        if [[ $? -ne 0 ]]; then echo -e "\e[35mERROR - Not a valid JSON file on the webserver!\e[0m\n"; exit 1; fi
		        #Ok, downloaded file is a valid JSON file. So now look into the HASH
			onlineMetaHash=$(${cardanocli} ${cliEra} stake-pool metadata-hash --pool-metadata-file "${tmpMetadataJSON}")
		        checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		        #Compare the HASH now, if they don't match up, output an ERROR message and exit
		        if [[ ! "${poolMetaHash}" == "${onlineMetaHash}" ]]; then
		                echo -e "\e[35mERROR - HASH mismatch!\n\nPlease make sure to upload your MetaData JSON file correctly to your webserver!\nPool-Registration aborted! :-(\e[0m\n";
		                echo -e "\nYour remote file at \e[32m${poolMetaUrl}\e[0m with HASH \e[32m${onlineMetaHash}\e[0m\ndoes not match with your local HASH \e[32m${poolMetaHash}\e[0m:\n"
		                echo -e "--- BEGIN REMOTE FILE ---\e[33m"
		                cat "${tmpMetadataJSON}"
		                echo -e "\e[0m---  END REMOTE FILE ---"
		                echo -e "\e[0m\n"
		                exit 1;
		        else echo -e "\e[32mOK\e[0m\n"; fi
		        #Ok, HASH is the same, continue

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
                                offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for Pool '${poolMetaTicker}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                        fi
                        ;;


        PoolRetirement )
                        #Pool Retirement
                        poolMetaTicker=$(jq -r ".transactions[${transactionIdx}].poolMetaTicker" <<< ${offlineJSON})

			#Check that the UTXO on the paymentAddress (transactionFromAddr) has not changed
		        case ${workMode} in
		                "online")	showProcessAnimation "Query-UTXO: " &
						utxo=$(${cardanocli} ${cliEra} query utxo --output-text --address ${transactionFromAddr} 2> /dev/stdout);
	                                        if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;

		                "light")	showProcessAnimation "Query-UTXO-LightMode: " &
						utxo=$(queryLight_UTXO "${transactionFromAddr}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${utxo}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						;;
			esac
                        showProcessAnimation "Convert-UTXO: " &
                        utxoLiveJSON=$(generate_UTXO "${utxo}" "${transactionFromAddr}"); stopProcessAnimation;
			utxoLiveJSON=$(jq . <<< ${utxoLiveJSON}) #to bring it in the jq format if compressed

			utxoOfflineJSON=$(jq -r ".address.\"${transactionFromAddr}\".utxoJSON" <<< ${offlineJSON})

	                if [[ ! "${utxoLiveJSON}" == "${utxoOfflineJSON}" ]]; then echo -e "\e[35mERROR - The UTXO status between the offline capture and now has changed for the payment address '${transactionFromName}' !\e[0m\n"; exit 1; fi

                        echo -e "\e[90m\t[${transactionCue}]\t\e[0m${transactionType}[${transactionEra}] for Pool '${poolMetaTicker}', payment via '${transactionFromName}' \e[90m(${transactionDate})"
                        echo -e "\t   \t\e[90mpayment via ${transactionFromAddr}\e[0m"
                        echo

                        if ask "\e[33mDoes this look good for you, continue ?" N; then

		       		echo
				case ${workMode} in
					"online")
						#onlinesubmit
						echo -ne "\e[0mSubmitting the transaction via the node ... "
						${cardanocli} ${cliEra} transaction submit --tx-file ${txFile}
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi
		                                echo -e "\n\e[0mStatus: \e[36mDONE - Transaction submitted\n"

						#Show the TxID
						txID=$(${cardanocli} ${cliEra} transaction txid --output-text --tx-file ${txFile}); echo -e "\e[0m TxID is: \e[32m${txID}\e[0m"
						checkError "$?"; if [ $? -ne 0 ]; then exit $?; fi;
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;

					"light")
						#lightmode submit
						showProcessAnimation "Submit-Transaction-LightMode: " &
						txID=$(submitLight "${txFile}");
						if [ $? -ne 0 ]; then stopProcessAnimation; echo -e "\e[35mERROR - ${txID}\e[0m\n"; exit $?; else stopProcessAnimation; fi;
						echo -e "\e[0mSubmit-Transaction-LightMode ... \e[32mDONE\n"
						if [[ "${transactionExplorer}" != "" ]]; then echo -e "\e[0mTracking: \e[32m${transactionExplorer}/${txID}\n\e[0m"; fi
						;;
				esac
				echo

                                #Write the new offileFile content
                                offlineJSON=$( jq ".address.\"${transactionFromAddr}\" += {used: \"yes\" }" <<< ${offlineJSON})
                                offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"tx submit ${txID} - ${transactionType} for Pool '${poolMetaTicker}', payment via '${transactionFromName}'\" } ]" <<< ${offlineJSON})
                                offlineJSON=$( jq "del (.transactions[${transactionIdx}])" <<< ${offlineJSON})
                                echo "${offlineJSON}" > ${offlineFile}
                                showOfflineFileInfo;
                                echo
                                echo -e "\e[33mDon't de-register/delete your rewards staking account/address yet! You will receive the pool deposit fees on it!\n"
                                echo -e "\e[0m\n"
                        fi
                        ;;


        * )             #Unknown Transaction Type !?
                        echo -e "\n\e[90m\t[${transactionCue}]\t\e[35mUnknown transaction type\e[0m"
                        ;;
esac

#clean up
rm ${txFile} 2> /dev/null


#Check the number of pending transactions
transactionsCnt=$(jq -r ".transactions | length" <<< ${offlineJSON})
if [[ ${transactionsCnt} -gt 0 ]]; then echo -e "\e[33mThere are ${transactionsCnt} more pending transactions in the '$(basename ${offlineFile})'.\nYou can submit them by re-running the same command again.\e[0m\n"; exit; fi

echo
fi # END
#
###########################################
###
### action = execute
###
###########################################


###########################################
###
### action = extract
###
###########################################
#
# START

if [[ "${action}" == "extract" ]]; then

#Show Information first
showOfflineFileInfo;

#Check the number of files attached
filesCnt=$(jq -r ".files | length" <<< ${offlineJSON})
if [[ ${filesCnt} -eq 0 ]]; then echo -e "\e[33mNo attached files found in the '$(basename ${offlineFile})'.\e[0m\n"; exit; fi

echo "------------------"
echo
echo -e "\e[36mExtracting ${filesCnt} files from the '$(basename ${offlineFile})': \e[0m"
echo

offlineJSONtemp=${offlineJSON}	#make a temporary local copy of all the files entries, because we delete it directly in the main one

for (( tmpCnt=0; tmpCnt<${filesCnt}; tmpCnt++ ))
do

  filePath=$(jq -r ".files | keys[${tmpCnt}]" <<< ${offlineJSONtemp})
  fileDate=$(jq -r ".files.\"${filePath}\".date" <<< ${offlineJSONtemp})
  fileSize=$(jq -r ".files.\"${filePath}\".size" <<< ${offlineJSONtemp})
  echo -ne "\e[90m\t[$((${tmpCnt}+1))]\t\e[0m${filePath} \e[90m(${fileSize}, ${fileDate})\e[0m -> "

  fileBase64=$(jq -r ".files.\"${filePath}\".base64" <<< ${offlineJSONtemp})

  #Decode base64 and write the it to the filePath
  if [ -f "${filePath}" ]; then
	                        echo -e "\e[33mSkipped (File exists, delete it first if you wanna overwite it)\e[0m\n";
			   else
				mkdir -p $(dirname ${filePath}) #generate the output path if not already present
				base64 --decode <(echo "${fileBase64}") 2> /dev/null > ${filePath} #write the file into the path
				if [[ $? -eq 0 ]]; then
					echo -e "\e[32mExtracted\e[0m\n";
		                        #Write the new offileFile content
		                        offlineJSON=$( jq ".history += [ { date: \"$(date -R)\", action: \"extracted file '${filePath}'\" } ]" <<< ${offlineJSON})
		                        offlineJSON=$( jq "del (.files.\"${filePath}\")" <<< ${offlineJSON})
		                        echo "${offlineJSON}" > ${offlineFile}
			  			   else
				 	echo -e "\e[35mFailed (maybe some rights issues?)\e[0m\n";
				fi
  fi

done

#Check if there are any files attached
filesCnt=$(jq -r ".files | length" <<< ${offlineJSON});
if [[ ${filesCnt} -gt 0 ]]; then echo -e "\e[33mThere are still ${filesCnt} files attached in the '$(basename ${offlineFile})'.\nYou can extract them by running the command: $(basename $0) extract\e[0m\n"; exit; fi

echo
fi # END
#
###########################################
###
### action = execute
###
###########################################
