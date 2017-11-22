
#!/bin/ksh
# Get script running directory
CMDDIR="${0%/*}"
if [[ -z "${CMDDIR}" || "${CMDDIR}" = "." ]];then
	CMDDIR=${PWD}
fi
echo "CMDDIR is ${CMDDIR}"

# Get root directory
LOG_ROOT="${CMDDIR%%/FileArchive}"
if [[ $LOG_ROOT = /dev || $LOG_ROOT = /pat || $LOG_ROOT = /prod ]]
then
	SCRIPTDIR=${LOG_ROOT}/FileArchive
        echo "LOG_ROOT is ${LOG_ROOT}"
else
        echo "It seems that we try to run the script from a wrong directory: ${CMDDIR} Abort!"
        exit 1
fi

# Redirect stdout and stderr to log files
exec >"${SCRIPTDIR}/FileArchiving.log"
exec 2>"${SCRIPTDIR}/FileArchiving_err.log"

#
# Define folders
#
FromDIR_LOG=${LOG_ROOT}/log
ToDIR_LOG=${LOG_ROOT}/log

# archive and purge old logs 
# archive criteria: 14 days old; files with same date '_yymmdd' are zipped into one file; ignore subfolders.

perl ${SCRIPTDIR}/arch.pl ${FromDIR_LOG} ${ToDIR_LOG} 14 _YYMMDD IGNORE_SUBFOLDER

if [[ $? -ne 0 ]]
then
	echo "archiving ${FromDIR_LOG} failed! Abort."
	exit 1
fi

echo "\nDone.\n"
exit 0
