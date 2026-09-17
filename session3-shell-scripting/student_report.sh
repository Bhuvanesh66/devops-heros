#!/bin/bash
# ---------------------------------------------------------------
# Session 3 - Shell Scripting Homework
# Covers every requirement listed in task.md:
#   - print the current date
#   - print the hostname and the username
#   - capture process info into a file with >
#   - print name, roll number and a comment
#   - use variables, take input with read -p,
#     and create a directory and a file
# Author: Bhuvanesh M S (24bcs10134)
# ---------------------------------------------------------------

# ---- variables holding COMMAND OUTPUT, via $( ) ----
current_date=$(date)
host_name=$(hostname)
current_user=$(whoami)

echo "==============================================="
echo "            STUDENT / SYSTEM REPORT"
echo "==============================================="

# ---- 1. current date ----
echo "Current date : $current_date"

# ---- 2. hostname and username ----
# NOTE: this is the mistake task.md made on purpose --
#   echo $hostname   -> prints an EMPTY variable
#   echo $(hostname) -> runs the COMMAND
echo "Hostname     : $host_name"
echo "Username     : $current_user"
echo "Logged in    : $(who | wc -l) session(s)"
echo "-----------------------------------------------"

# ---- 3. take input with read -p ----
read -p "Enter your name: "        name
read -p "Enter your roll number: " roll_no
read -p "Enter your comment: "     comment
echo ""

# ---- 4. print them back using the variables ----
echo "My name is $name"
echo "My roll number is $roll_no"
echo "My comment is: $comment"
echo "-----------------------------------------------"

# ---- 5. create a directory and a file inside it ----
report_dir="report_${roll_no}"
mkdir -p "$report_dir"
touch "$report_dir/process.log"
echo "Created directory : $report_dir"

# ---- 6. redirect process info into the file with > ----
ps -ef > "$report_dir/process.log"
echo "Saved process list: $report_dir/process.log ($(wc -l < "$report_dir/process.log") lines)"

# ---- append the student details with >> (append, not overwrite) ----
{
  echo "Name       : $name"
  echo "Roll number: $roll_no"
  echo "Comment    : $comment"
  echo "Generated  : $current_date on $host_name by $current_user"
} > "$report_dir/student.txt"

echo "Saved details     : $report_dir/student.txt"
echo "==============================================="
echo "--- first 5 lines of process.log ---"
head -5 "$report_dir/process.log"
