#!/bin/bash

# Clear the terminal so we can see things
clear

# Source terminal colors
. ./colors.sh

# Source functions - Simulate prototyping
# check_deps()
# cleanup()
# cleanupfiles()
# error()
# print_kernels()
# spinner()
# update()
. ./functions.sh

# Ensure root privledges
SUDO=''

if (( $EUID != 0 )); then
	SUDO='sudo'
fi

# Init variables
NOW=$(date +%h%d_%H-%m-%S)
VERAPPEND=$(date +.%y%m%d)
FOLDER="Build_$NOW"
OUTPUT="kernel_$NOW.tar.xz"
DEPENDENCIES="gcc make fakeroot libncurses5 libncurses5-dev kernel-package build-essential pkg-config qt5-qmake libnotify-bin"
UPDATENEEDED=0
PLUS="${Cyan}[+]${Reg}"

if [ "$#" -gt 1 ]; then
	usage
fi
if [ "$#" -eq 1 ]; then
	if ! [[ -f "$1" ]]; then
		error ${LINENO} "$1 is not a file or does not exist." 1
	fi
	OUTPUT=$1
else
	echo -e "If you have a local kernel archive, pass it as an argument to use it.\n"
	print_kernels
fi

echo -e "${PLUS} Checking Dependencies"
check_deps

echo -e "${PLUS} Creating a directory to build your kernel from source."
mkdir $FOLDER 2>/dev/null || error ${LINENO} "You cannot create a directory here." 1
echo -e "    Directory Created:\t${Cyan}${FOLDER}${Reg}\n"

echo -ne "${PLUS} Extracting your kernel . . . "
tar xf $OUTPUT -C ./$FOLDER &
spinner $!

# Check for successful extraction
wait $!
EXIT_STAT=$?
if [ $EXIT_STAT -ne 0 ]
then
	error ${LINENO} "An error occured while extracting the archive." $EXIT_STAT
fi

EXTRACTED=$(ls $FOLDER/)
echo -e "\n    Extracted Folder:\t${Cyan}${FOLDER}/${EXTRACTED}${Reg}\n"

pushd $FOLDER/linux*

echo -e "${PLUS} Launching configuratino GUI \"make -s xconfig\"."
	make xconfig 2>/dev/null || error ${LINENO} "Error occured while running \"make xconfig\"." 1

echo -ne "${PLUS} Cleaning the source tree and reseting kernel-package parameters . . . "
	fakeroot make-kpkg clean 1>/dev/null 2>/dev/null || error ${LINENO} "Error occurred while running \"make-kpkg clean\"." 1
echo -e "\n \_ ${Green}Cleaned${Reg}\n"

read -p "[?] Would you like to build the kernel now? This will take a while (y/N):" -n 1 -r
if [[ ! $REPLY  =~ ^[Yy]$ ]]; then
	echo -e "\n\nYou can build it later with:\nfakeroot make-kpkg -rootcmd --initrd --append-to-version=$VERAPPEND kernel_image kernel_headers"
	cleanup
	echo -e "${Green}[%] Exiting without compilation.${Reg}"
	popd 1>/dev/null 2>/dev/null
	exit 0
else
	echo -e "\n${PLUS} Compiling your kernel!"
	echo -e " \_ An alert notification will trigger when complete. Time for a stroll . . .\n\n"
	echo -e "--------------------------------------------------------------------------------------------------"
	countdown 'Compilation will begin in ' 10
	echo -e " -- ${Yellow}Starting Compilation${Reg} -- "
	echo -e "--------------------------------------------------------------------------------------------------\n\n"
	
	fakeroot time -f "\n\n\tTime Elapsed: %E\n\n" make-kpkg --rootcmd fakeroot --initrd --append-to-version=$VERAPPEND kernel_image kernel_headers \
		|| error ${LINENO} "Something happened during the compilation process, but I can't help you." 1
fi

# Provide a user notification 
echo -e $'\a' && notify-send -i emblem-default "Kernel compliation completed."

read -p "[?] Kernel compiled successfully. Would you like to install? (y/N)" -n 1 -r
if [[ ! $REPLY  =~ ^[Yy]$ ]]; then
	dir=`pwd`
	pDir="$(dirname "$dir")"
	echo -e "\n\nYou can manually install the kernel with:\nsudo dpkg -i $pDir/*.deb"
	echo -e "\n \_ Skipping kernel installation . . ."
else
	echo -e "\n \_ ${Green}Installing kernel . . .${Reg}"
	$SUDO dpkg -i ../*.deb
fi

cleanup
popd 1>/dev/null 2>/dev/null

echo -e "${Green}[%] Complete${Reg}"