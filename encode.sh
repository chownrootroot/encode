#!/bin/bash

strDelete=0
strMode=0

# Read in arguments
until [ -z "${1}" ]; do
    if [ "${1}" = "--key" ]; then
        shift
        strPrivkey="${1}"
    elif [ "${1}" = "--path" ]; then
        shift
        strPath="${1}"
    elif [ "${1}" = "--delete" ]; then
        strDelete="1"
    elif [ "${1}" = "-e" ]; then
        strMode="1"
    elif [ "${1}" = "-d" ]; then
        strMode="2"
     fi
    shift
done

function encrypt(){
	if [ ! -d "${strPath}" ]; then
	    printf "%s\n" "Path does not exist."
	    exit 1
	elif [ ! -f "${strPrivkey}" ]; then
	    printf "%s\n" "Privkey does not exist."
	    exit 1
#	elif [ ! -f "public.pem" ]; then
#	    printf "%s\n" "Pubkey does not exist."
#	    exit 1
	fi

	# Generate public key
	printf "Generating public key"
	openssl rsa -in ${strPrivkey} -outform PEM -pubout -out public.pem
	printf "..done\n"
	

	# Generate password
	printf "Generating password"
	openssl rand -hex 32 > pass
	printf "..done\n"
	
	# Encrypt files
	iFileNo=0
	for file in ${strPath}*; do
	    strTrimmed=$(echo ${file} | awk -F "/" '{print $NF}')
	    iFileNo=$(($iFileNo+1))
	    printf "Encrypting ${file}.."
	    openssl enc -aes-256-cbc -salt -in "${file}" -out "${strPath}${iFileNo}.aes" -pass file:pass
	    printf "%s;%s\n" ${iFileNo} "${strTrimmed}" >> files 
	    printf "..done\n"
	    if [ "${strDelete}" = "1" ]; then
	    	rm "${file}"
	    fi
	done

	# Encrypt password
	printf "Encrypting password"
	openssl rsautl -encrypt -inkey public.pem -pubin -in pass -out ${strPath}_encrypted_password
	printf "..done\n"

	# Encrypt file list
	printf "Encrypting file list"
	openssl enc -aes-256-cbc -salt -in files -out ${strPath}_files -pass file:./pass
	printf "..done\n"

	# Delete files
	printf "Cleaning password and file list..."
	rm pass files public.pem
	printf "..done\n"

}

function decrypt(){
	if [ ! -d "${strPath}" ]; then
	    printf "%s\n" "Path does not exist."
	    exit 1
	elif [ ! -f "${strPrivkey}" ]; then
	    printf "%s\n" "Privkey does not exist."
	    exit 1
	elif [ ! -f "${strPath}_encrypted_password" ]; then
	    printf "%s\n" "Password does not exist."
	    exit 1
	elif [ ! -f "${strPath}_files" ]; then
	    printf "%s\n" "File list does not exist."
	    exit 1
	fi

	# Decrypt password
	printf "Decrypting password..."
	openssl rsautl -decrypt -inkey ${strPrivkey} -in "${strPath}_encrypted_password" -out pass
	printf "..done\n"
	
	# Decrypt file list
	printf "Decrypting file list..."
	openssl enc -d -aes-256-cbc -in "${strPath}_files" -out files -pass file:./pass
	printf "..done\n"
	
	# Decrypt
	while read line; do
		strFileNo=$(echo "${line}" | awk -F ";" '{print $1}')			
		strFileName=$(echo "${line}" | awk -F ';' '{print $2}')
                printf "Decrypting ${strFileName}.."
		openssl enc -d -aes-256-cbc -in "${strPath}${strFileNo}.aes" -out "${strPath}${strFileName}" -pass file:./pass
	        printf "..done\n"
       	        if [ "${strDelete}" = "1" ]; then
	    		rm "${strPath}${strFileNo}.aes"
	        fi
		
	done < files

	# Delete files
	printf "Cleaning password and file list..."
	rm ${strPath}_files ${strPath}_encrypted_password pass files	
	printf "..done\n"

}

if [ "${strMode}" = 0 ]; then
	printf "Encrypt/decrypt not selected\n"
	exit 1
elif [ "${strMode}" = 1 ]; then
	encrypt
elif [ "${strMode}" = 2 ]; then
	decrypt
fi

exit 0

