#!/bin/bash
# Deafult Port
def_port='8080'

# Color Codes
CR=$'\e[1;31m' CG=$'\e[1;32m' CY=$'\e[1;33m' CB=$'\e[1;34m' CC=$'\e[1;36m' CW=$'\e[1;37m' RS=$'\e[1;0m'

architecture=`uname -m`

# Terminate Program
terminated() {
	printf "\n\n${RS} ${CR}[${CW}!${CR}]${CY} Program Interrupted ${CR}[${CW}!${CR}]${RS}\n"
	exit 1
}

trap terminated SIGTERM
trap terminated SIGINT

kill_pid() {
	check_PID="php ngrok cloudflared loclx"
	for process in ${check_PID}; do
		if [[ $(pidof ${process}) ]]; then
			killall ${process} > /dev/null 2>&1
		fi
	done
}

# FIX 3: Port conflict detection helper
# Checks if a port is already in use before binding to it
check_port() {
	if lsof -i :"$1" &>/dev/null 2>&1 || ss -ltn 2>/dev/null | grep -q ":$1 "; then
		printf "\n${RS} ${CR}[${CW}!${CR}]${CY} Port ${1} is already in use. Free it and retry.${RS}\n"
		exit 1
	fi
}

# Host Banner
logo(){

clear
echo "${CY}     _    _           _   
${CY}    | |  | |  ${CC}V${CB}-${CG}2.3${CY}  | |  
${CG}    | |__| | ___  ___| |_ 
${CG}    |  __  |/ _ \/ __| __|
${CY}    | |  | | (_) \__ \ |_ 
${CY}    |_|  |_|\___/|___/\__|
${RS}
${CR} [${CW}~${CR}]${CY} Created By HTR-TECH ${CG}(${CC}Tahmid Rayat${CG})${RS}"

}

path(){
	logo
	printf "\n${RS} ${CR}[${CW}1${CR}]${CY} Use Current Path [host/htdocs]"
	printf "\n${RS} ${CR}[${CW}2${CR}]${CY} Setup a Path"
	printf "\n${RS}"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Select A Hosting option: ${CC}"
	read red_path
	
	if [[ $red_path == 1 || $red_path == 01 ]]; then
		path=$'./htdocs'
	elif [[ $red_path == 2 || $red_path == 02 ]]; then
		printf "\n${RS} ${CC}Enter File Path [Example : /home/tahmid/htdocs]"
		printf "\n${RS}"
		printf "\n${RS} ${CR}>>${CG} ${CC}"
		read path
	else
		printf "\n${RS} ${CR}[${CW}!${CR}]${CY} Invalid option ${CR}[${CW}!${CR}]${RS}\n"
		sleep 2 ; logo ; path
	fi

	[[ ! -d "$path" ]] && mkdir -p "$path"
	menu
}

package(){
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Setting up Environment..${RS}"
	if [[ -d "/data/data/com.termux/files/home" ]]; then
		if [[ ! $(command -v proot) ]]; then
			printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Installing ${CY}Proot${RS}\n"
			pkg install proot resolv-conf -y
		fi
	fi

	if [[ $(command -v php) && $(command -v curl) && $(command -v unzip) ]]; then
		printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Environment Setup Completed !${RS}"
	else
		repr=(curl php unzip)
		for i in "${repr[@]}"; do
			type -p "$i" &>/dev/null || 
				{ 
					printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Installing ${CY}${i}${RS}\n"
					
					if [[ $(command -v pkg) ]]; then
						pkg install "$i" -y
					elif [[ $(command -v apt) ]]; then
						sudo apt install "$i" -y
					elif [[ $(command -v apt-get) ]]; then
						sudo apt-get install "$i" -y
					elif [[ $(command -v dnf) ]]; then
						sudo dnf -y install "$i"
					else
						printf "\n${RS} ${CR}[${CW}!${CR}]${CY} Unfamiliar Distro ${CR}[${CW}!${CR}]${RS}\n"
						exit 1
					fi
				}
		done
	fi

	# FIX 2: Validate PHP actually installed successfully
	# Without this check, a silent package manager failure causes php -S
	# to exit immediately with no user-facing error message
	if ! command -v php &>/dev/null; then
		printf "\n${RS} ${CR}[${CW}!${CR}]${CY} PHP installation failed. Cannot start server.${RS}\n"
		exit 1
	fi
}

## Download Binaries
download() {
	url="$1"
	output="$2"
	file=`basename $url`
	if [[ -e "$file" || -e "$output" ]]; then
		rm -rf "$file" "$output"
	fi
	curl --silent --insecure --fail --retry-connrefused \
		--retry 3 --retry-delay 2 --location --output "${file}" "${url}"

	if [[ -e "$file" ]]; then
		# FIX 4: Use ##*. instead of #*. to strip up to the LAST dot
		# #*. only strips to the first dot, so "loclx-linux-amd64.zip"
		# would evaluate to "linux-amd64.zip" and miss the zip branch entirely
		if [[ ${file##*.} == "zip" ]]; then
			unzip -qq $file > /dev/null 2>&1
		elif [[ ${file##*.} == "tgz" ]]; then
			tar -zxf $file > /dev/null 2>&1
		else
			mv -f $file $output > /dev/null 2>&1
		fi
		chmod +x $output > /dev/null 2>&1
		rm -rf "$file"
	else
		echo -e "\n${RS} ${CR}[${CW}!${CR}]${CY} Error occured while downloading ${CR}${output}."
		exit 1
	fi
}

## Install ngrok
install_ngrok() {
	if [[ -e "./ngrok" ]]; then
		printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Ngrok already installed.${RS}"
	else
		printf "\n${RS} ${CR}[${CW}-${CR}]${CC} Installing ngrok...${RS}"
		if [[ ("$architecture" == *'arm'*) || ("$architecture" == *'Android'*) ]]; then
			download 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz' 'ngrok'
		elif [[ "$architecture" == *'aarch64'* ]]; then
			download 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz' 'ngrok'
		elif [[ "$architecture" == *'x86_64'* ]]; then
			download 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz' 'ngrok'
		else
			download 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-386.tgz' 'ngrok'
		fi
	fi
}

## Install Cloudflared
install_cloudflared() {
	if [[ -e "./cloudflared" ]]; then
		printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Cloudflared already installed.${RS}"
	else
		printf "\n${RS} ${CR}[${CW}-${CR}]${CC} Installing Cloudflared...${RS}"
		if [[ ("$architecture" == *'arm'*) || ("$architecture" == *'Android'*) ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm' 'cloudflared'	
		elif [[ "$architecture" == *'aarch64'* ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64' 'cloudflared'
		elif [[ "$architecture" == *'x86_64'* ]]; then
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64' 'cloudflared'
		else
			download 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386' 'cloudflared'
		fi
	fi
}

## Install LocalXpose
install_localxpose() {
	if [[ -e "./loclx" ]]; then
		printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Localxpose already installed.${RS}"
	else
		printf "\n${RS} ${CR}[${CW}-${CR}]${CC} Installing Localxpose...${RS}"
		if [[ ("$architecture" == *'arm'*) || ("$architecture" == *'Android'*) ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-arm.zip' 'loclx'
		elif [[ "$architecture" == *'aarch64'* ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-arm64.zip' 'loclx'
		elif [[ "$architecture" == *'x86_64'* ]]; then
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-amd64.zip' 'loclx'
		else
			download 'https://api.localxpose.io/api/v2/downloads/loclx-linux-386.zip' 'loclx'
		fi
	fi
}

## LocalXpose Authentication
localxpose_auth() {
	./loclx -help > /dev/null 2>&1 &
	{ logo; sleep 1; }
	[ -d ".localxpose" ] && auth_f=".localxpose/.access" || auth_f="$HOME/.localxpose/.access"
	[ -d "/data/data/com.termux/files/home" ] && status=$(termux-chroot ./loclx account status) || status=$(./loclx account status)

	if [[ $status == *"Error"* ]]; then
		echo -e "\n${CR} [${CW}!${CR}]${CG} Create an account on ${CY}localxpose.io${CG} & copy the token\n"
		sleep 3
		read -p "${CR} [${CW}?${CR}]${CY} Input Loclx Token :${CY} " loclx_token
		if [[ ${#loclx_token} -lt 10 ]]; then
			echo -e "\n${CR} [${CQ}!${CR}]${CR} You have to input Localxpose Token."
			sleep 2; menu;
		else
			echo -n "$loclx_token" > $auth_f 2> /dev/null
		fi
	fi
}

## Ngrok Authentication
ngrok_auth() {
	if ! [[ -e ".ngrok.yml" && $(awk -F'authtoken: ' '{print $2}' "./.ngrok.yml" | xargs) != "" ]]; then
		{ logo; sleep 1; }
		echo -e "\n${CR} [${CW}!${CR}]${CG} Create an account on ${CY}ngrok.com${CG} & copy the token\n"
		sleep 3
		read -p "${CR} [${CW}?${CR}]${CY} Input Ngrok.com Token :${CY} " ngrok_token
		if [[ ${#ngrok_token} -lt 10 ]]; then
			echo -e "\n${CR} [${CQ}!${CR}]${CR} You have to input valid ngrok Token."
			sleep 2; menu;
		else
			./ngrok --config ".ngrok.yml" authtoken $ngrok_token > /dev/null 2>&1 &
		fi
	fi
}

## Host on Localhost. Just "php -S" lol
localhost() {
	printf "\n${RS} ${CR}[${CW}-${CR}]${CY} Input Port [default:${def_port}]: ${CC}"
	read port
	port="${port:-${def_port}}"
	# FIX 3: Check port is free before binding
	check_port "$port"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Starting PHP Server on Port ${CY}${port}${RS}\n"
	cd "$path" && php -S 127.0.0.1:"$port" > /dev/null 2>&1 &
	sleep 2
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Successfully Hosted at : ${CY}http://127.0.0.1:$port ${RS}"
	printf "\n\n ${CR}[${CW}-${CR}]${CC} Press Ctrl + C to exit.${RS}\n"
	while [ true ]; do
		sleep 0.75
	done
}

## Start ngrok
ngrok() {
	ngrok_auth
	# FIX 3: Check port is free before binding
	check_port "$def_port"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Starting PHP Server on Port ${CY}${def_port}${RS}\n"
	cd "$path" && php -S 127.0.0.1:"$def_port" > /dev/null 2>&1 &
	sleep 1
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Launching Ngrok on Port ${CY}${def_port}${RS}"

	if [[ `command -v termux-chroot` ]]; then
		sleep 2 && termux-chroot ./ngrok --config ".ngrok.yml" http 127.0.0.1:"$def_port" --log=stdout > /dev/null 2>&1 &
	else
		sleep 2 && ./ngrok --config ".ngrok.yml" http 127.0.0.1:"$def_port" --log=stdout > /dev/null 2>&1 &
	fi

	sleep 8
	# FIX 1: Old pattern '.ngrok.io' no longer matches ngrok's current free-tier
	# domains which use '.ngrok-free.app'. Updated to match any HTTPS ngrok URL
	# so it stays correct regardless of future domain changes.
	ngrk=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -Eo 'https://[^"]+\.ngrok[^"]+')
	printf "\n\n${RS} ${CR}[${CW}-${CR}]${CG} Successfully Hosted at : ${CY}${ngrk}${RS}"
	printf "\n\n ${CR}[${CW}-${CR}]${CC} Press Ctrl + C to exit.${RS}\n"
	while [ true ]; do
		sleep 0.75
	done
}

## Start Cloudflared
cloudflared() { 
	rm .cld.log > /dev/null 2>&1 &
	# FIX 3: Check port is free before binding
	check_port "$def_port"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Starting PHP Server on Port ${CY}${def_port}${RS}\n"
	cd "$path" && php -S 127.0.0.1:"$def_port" > /dev/null 2>&1 &
	sleep 1
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Launching Cloudflared on Port ${CY}${def_port}${RS}"

	if [[ `command -v termux-chroot` ]]; then
		sleep 2 && termux-chroot ./cloudflared tunnel -url 127.0.0.1:"$def_port" --logfile ".cld.log" > /dev/null 2>&1 &
	else
		sleep 2 && ./cloudflared tunnel -url 127.0.0.1:"$def_port" --logfile ".cld.log" > /dev/null 2>&1 &
	fi

	sleep 8
	cldflr=$(grep -o 'https://[-0-9a-z]*\.trycloudflare.com' ".cld.log")
	printf "\n\n${RS} ${CR}[${CW}-${CR}]${CG} Successfully Hosted at : ${CY}${cldflr}${RS}"
	printf "\n\n ${CR}[${CW}-${CR}]${CC} Press Ctrl + C to exit.${RS}\n"
	while [ true ]; do
		sleep 0.75
	done
}

## Start LocalXpose
localxpose() { 
	rm .loclx.log > /dev/null 2>&1 &
	localxpose_auth
	# FIX 3: Check port is free before binding
	check_port "$def_port"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Starting PHP Server on Port ${CY}${def_port}${RS}\n"
	cd "$path" && php -S 127.0.0.1:"$def_port" > /dev/null 2>&1 &
	sleep 1
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Launching LocalXpose on Port ${CY}${def_port}${RS}"

	if [[ `command -v termux-chroot` ]]; then
		sleep 2 && termux-chroot ./loclx tunnel --raw-mode http --https-redirect -t 127.0.0.1:"$def_port" > ".loclx.log" 2>&1 &
	else
		sleep 2 && ./loclx tunnel --raw-mode http --https-redirect -t 127.0.0.1:"$def_port" > ".loclx.log" 2>&1 &
	fi
	
	sleep 8
	loclx_url=$(grep -o '[0-9a-zA-Z.]*\.loclx.io' ".loclx.log")
	printf "\n\n${RS} ${CR}[${CW}-${CR}]${CG} Successfully Hosted at : ${CY}http://${loclx_url}${RS}"
	printf "\n\n ${CR}[${CW}-${CR}]${CC} Press Ctrl + C to exit.${RS}\n"
	while [ true ]; do
		sleep 0.75
	done
}

menu() {
	logo
	echo -e "\n${CR} [${CW}01${CR}]${CG} Localhost ${CR}[${CC}Manual Forwarding${CR}]"
	echo -e "${CR} [${CW}02${CR}]${CG} Ngrok.io"
	echo -e "${CR} [${CW}03${CR}]${CG} Cloudflared"
	echo -e "${CR} [${CW}04${CR}]${CG} LocalXpose"
	printf "\n${RS} ${CR}[${CW}-${CR}]${CG} Select an Option: ${CB}"
	read REPLY

	case $REPLY in 
		1 | 01)
			localhost;;
		2 | 02)
			ngrok;;
		3 | 03)
			cloudflared;;
		4 | 04)
			localxpose;;
		*)
			printf "\n${RS} ${CR}[${CW}!${CR}]${CY} Invalid option ${CR}[${CW}!${CR}]${RS}\n"
			sleep 2; path;;
	esac
}

kill_pid
package
install_ngrok
install_cloudflared
install_localxpose
path
