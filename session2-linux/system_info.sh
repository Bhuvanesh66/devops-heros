#!/bin/bash
# ---------------------------------------------------------------
# Session 2 - Linux Homework
# A shell script that prints system information, takes user input
# with "read -p", creates a directory and stores the running
# process list in a file inside it.
#
# Concepts used: variables, read -p, mkdir, touch, echo,
#                date, hostname, whoami, df, ps, > redirection
# Author: Bhuvanesh M S (24bcs10134)
# ---------------------------------------------------------------

echo "==============================================="
echo "        SYSTEM INFORMATION REPORT"
echo "==============================================="
echo ""

# ---- Taking input from the user using read -p ----
read -p "Enter your name: " USER_NAME
read -p "Enter a name for the report directory: " DIR_NAME
echo ""

echo "Hello, $USER_NAME! Generating your system report..."
echo ""

# ---- Storing command output inside variables ----
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
CURRENT_USER=$(whoami)

# ---- 1. Print the current date ----
echo "-----------------------------------------------"
echo "1. Current Date and Time : $CURRENT_DATE"

# ---- 2. Print the hostname ----
echo "2. Hostname              : $HOST_NAME"

# ---- 3. Print the username ----
echo "3. Logged in Username    : $CURRENT_USER"
echo "-----------------------------------------------"
echo ""

# ---- 4. Print the disk usage ----
echo "4. Disk Usage (df -h):"
df -h
echo ""

# ---- 5. Print the running processes ----
echo "5. Running Processes (top 10):"
ps aux | head -n 10
echo ""

# ---- Creating a directory using mkdir ----
mkdir -p "$DIR_NAME"
echo "Directory created : $DIR_NAME"

# ---- Creating an empty file using touch ----
PROCESS_FILE="$DIR_NAME/processes.txt"
touch "$PROCESS_FILE"
echo "File created      : $PROCESS_FILE"

# ---- Storing process information in the file using > redirection ----
ps aux > "$PROCESS_FILE"
echo "Process list saved into $PROCESS_FILE"

# ---- Also saving the disk usage report ----
DISK_FILE="$DIR_NAME/diskusage.txt"
df -h > "$DISK_FILE"
echo "Disk usage saved into $DISK_FILE"
echo ""

echo "==============================================="
echo " Report generated for $USER_NAME on $CURRENT_DATE"
echo "==============================================="
