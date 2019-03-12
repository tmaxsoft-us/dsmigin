#!/bin/bash

################################################################################
#Author: Matthew Koziel
#Date: 20190129
#Description: This script will take an input of dataset names from an excel
#             spreadsheet, remove the temporary datasets, and prepare the names
#             for Mainframe FTP
#Usage: sh dsn2ftp.sh <input_file>
#Examples: sh dsn2ftp.sh files.txt
#          sh dsn2ftp.sh /home/oframe/ysw/file1.txt
#
################################################################################

################################################################################
#ENVIRONMENT SETUP / VARIABLES
#
#For check_return_code
################################################################################
basename=$(basename $0)
log_dir="$OPENFRAME_HOME/log/scripts"
DATE_=$(date +%Y%m%d)
#
curr_dir=$(pwd)
#For remove_temps
input_file=$1
#
TEMP_DIR="/home/oframe/common/temp"

################################################################################
#FUNCTION:                      remove_temps
#DESCRIPTION: When parsing the input file, this function will check for temp
#             datasets by searching for anything starting with && and does
#             not add them to the output_file
################################################################################
remove_temps(){
  echo "Beginning remove_temp function ..."
  cd $mydir
  check_return_code $? "cd $mydir"
  remove_temps_file=${input_file_base}.rmtmps
  #for dataset_name in $(cat ${1})
  #do
  #  if ! [[ "$dataset_name" =~ ^[\&][\&][a-zA-Z0-9]* ]]
  #  then
  #    echo "$dataset_name" >> $remove_temps_file
  #  fi
  #done
  cat $1 | grep -v "&&" >> $remove_temps_file
  echo "... Finished remove_temp function"
}

################################################################################
#FUNCTION:                   remove_mem_and_ver
#DESCRIPTION: When parsing the input file, this function will check for a
#             beginning parenthesis which should indicate a member or gdg
#             If it is detected, it will not be added as part of the
#             dataset_name to the output_file
################################################################################
remove_mem_and_var(){
  echo "Beginning remove_mem_and_var function ..."
  cd $mydir
  check_return_code $? "cd $mydir"
  remove_mem_var_file=${input_file_base}.rmmemvar
  cat $1 |  cut -d"(" -f1 >> ${remove_mem_var_file}
  echo "... Finished remove_mem_and_var function"
}

################################################################################
#FUNCTION:                    remove_output_file
#DESCRIPTION: Removes the passed output file
################################################################################
remove_output_file(){
  if [ -f $1 ]
  then
    rm $1
    check_return_code $? "rm $1"
  fi
}

################################################################################
#FUNCTION:                   check_return_code
#DESCRIPTION: This function checks the return code of the previous command and
#             Outputs the results to the log_dir in $OPENFRAME_HOME/log and
#             appends the script name, date, and .out for successful commands
#             .err for any commands that fail.
#             If a command fails, the script will exit with Return Code 100
################################################################################
check_return_code(){
  rc=$1
  string_=$2

  if [ "$rc" -eq 0 ];
  then
    echo "$string_ : SUCCESSFUL" >> ${log_dir}/${basename}.${DATE_}.out
  else
    echo "$string_ : FAILED" >> ${log_dir}/${basename}.${DATE_}.err
    exit 100
  fi
}


################################################################################
#FUNCTION:                     check_file_exists
#DESCRIPTION: Checks if the file passed in exists or not
################################################################################
check_file_exists(){
  if [ ! -z $1 ]
  then
    if [ ! -f $1 ]
    then
      echo "The file ($1) is not a regular file or does not exist"
      echo "The script failed because the input file passed is not a regular file\
      or does not exist" >> ${log_dir}/${basename}.${DATE_}.err
      usage
      exit 100
    fi
  else
    echo "There was no input field passed"
    echo "The script failed because no input file was passed"\
    >> ${log_dir}/${basename}.${DATE_}.err
    usage
    exit 100
  fi
  echo "INPUT_FILE_NAME=$1"
}

################################################################################
#FUNCTION:                         sort_file
#DESCRIPTION: This function will take in an input file, sort the file, and
#             Output the file to the temporary directory with the suffix .sorted
################################################################################
sort_file(){
  sorted_file=${input_file_base}.sorted
  cat $1 | sort -u >> ${mydir}/${sorted_file}
}

################################################################################
#FUNCTION:                         create_temp_dir
#DESCRIPTION: This function creates a temporary directory in $TEMP_DIR which is
#             set to /home/oframe/common/temp
################################################################################
create_temp_dir(){
  mydir=$(mktemp -dp $TEMP_DIR "$(basename $0).XXXXXXXXXXXX")
  check_return_code $? "mktemp -dp $mydir"
}

################################################################################
#FUNCTION:                         remove_temp_dir
#DESCRIPTION: This function removes the temporary directory created by the
#             create_temp_dir function
################################################################################
remove_temp_dir(){
  rm -r $mydir
  check_return_code $? "rm $mydir"
}

################################################################################
#FUNCTION:                          copy_file
#DESCRIPTION: This function simply copies a file. It takes in a file in the
#             first parameter and a directory or directory/file_name in the
#             second parameter
################################################################################
copy_file(){
  cp $1 $2
  check_return_code $? "cp $1 $2"
}

################################################################################
#FUNCTION:                         get_base_input_file
#DESCRIPTION: This function will get the base name of the input file passed.
#             This means you can pass the file name as a fully declared name
#             like /home/oframe/ysw/scripts/tests/file_name
#             and the base name would be "file_name"
################################################################################
get_base_input_file(){
  IFS='/' read -ra field <<< "$1"
  count=${#field[@]}
  input_file_base=${field[$((count-1))]}
}

################################################################################
#FUNCTION:                          seperate_last_field
#DESCRIPTION: This function will ready in the passed file name. It will then
#             read the file, and for every item in the file, it will read it in
#             delimited by '.' Then, it will store the number of fields the item
#             contains and while the counter variable num is less than the
#             count - 1, it will check if the counter variable is eq to
#             count - 2, if it is, it will echo the last field with a space to
#             the output file, otherwise it will echo out the field with a .
#             then it will print the last field.
################################################################################
seperate_last_field(){
  echo "Beginning seperate_last_field function ..."
  seperate_last_file=${input_file_base}.out
  for item in $(cat $1)
  do
    IFS='.' read -ra field <<< "$item"
    count=${#field[@]}
    num=0

    while [ $num -lt $((count-1)) ]
    do
      if [ $num -eq $((count-2)) ]
      then
        echo -n "${field[$num]} " >> $seperate_last_file
      else
        echo -n "${field[$num]}." >> $seperate_last_file
      fi
      num=$((num+1))
    done

    echo "${field[$((count-1))]}" >> $seperate_last_file
  done
  echo "... Finished seperate_last_field function"
}

################################################################################
#FUNCTION:                             usage
#DESCRIPTION: This function prints the usage to the screen in the event that
#             the script fails to run due to misusage
################################################################################
usage(){
  echo "Usage: "
  echo "sh $basename <input_file>"
  echo "examples: sh $basename files.txt"
  echo "          sh $basename /home/oframe/common/abc.txt"
}

################################################################################
#FUNCTION:                           remove_stardot
#DESCRIPTION: This function will remove any datasets that have "*." in the name
################################################################################
remove_stardot(){
  echo "Beginning remove *. files function ..."
  cd $mydir
  check_return_code $? "cd $mydir"
  remove_stardot_file=${input_file_base}.stardot
  cat $1 | grep -v "\*." >> $remove_stardot_file
  echo "... Finished remove *. files function"
}

################################################################################
#FUNCTION:                          remove_NULL
#DESCRIPTION: This function will remove any datasets called NULLFILE
################################################################################
remove_NULL(){
  echo "Beginning remove_NULL function ..."
  cd $mydir
  check_return_code $? "cd $mydir"
  remove_NULL_file=${input_file_base}.rmnull
  cat $1 | grep -v "NULLFILE" >> $remove_NULL_file
  echo "... Finished remove_NULL function"
}

################################################################################
#MAIN FUNCTION                       MAIN
#DESCRIPTION: First, we check that the file passed exists or not. If it doesn't,
#             Or there is a problem with the file (such as it's a directory not
#             a file), the script will output the usage and exit gracefully.
#             Then it will get the base name for the file so we can pass fully
#             qualified file names. Then we create a temporary directory in the
#             $TEMP_DIR folder. This value can be changed by modifying the
#             setup variable at the top of the script.
#             Then, we copy the input file to the temporary folder so we can work
#             on it. Then we remove the temporary datasets described in the file
#             by passing in the input file which has been set to the file copied
#             into the temporary directory. Next, the members are removed by
#             cutting everything before a begin parenthesis '('. and then sorted
#             The sorted file is copied back to wherever the user of the script
#             is currently located and then the temporary directory is deleted.
################################################################################
main(){
  check_file_exists $input_file
  get_base_input_file $input_file
  create_temp_dir
  copy_file $input_file $mydir
  remove_stardot $input_file
  remove_NULL $remove_stardot_file
  remove_temps $remove_NULL_file
  remove_mem_and_var $remove_temps_file
  sort_file $remove_mem_var_file
  seperate_last_field $sorted_file
  copy_file $seperate_last_file ${curr_dir}
  remove_temp_dir
}
main

