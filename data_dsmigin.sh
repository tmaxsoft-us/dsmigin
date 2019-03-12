#!/bin/bash

####################################################################################################################
#Author: Matthew Koziel
#Date: 20190118
#Description: This script will take in a dataset base name, determine what kind of dataset it is, and determine how to dsmigin the file and execute the dsmigin process
####################################################################################################################
#TODO: DONE
#    : Add options for debug levels
#TODO:
# Add set timestamp of generated schema to timestamp of convcpy file
#TODO: DONE
#We want to use the Input Dataset name to be parsed.
#The script should know what to do to that file based on the naming convention

environment_setup(){
  #Storing the username and checking that the user of this script is oframe
  #Only oframe user can use this script.
  username=$(whoami)
  if ! [ "${username}" = "oframe" ]; then
    echo "${username} is invalid for this function!!"
    exit 100
  fi

  #This is the directory where the input data is stored (In EBCDIC from Mainframe)
  input_data_loc="/opt/nfs_share/data"

  #Date variable
  DATE_=$(date +%Y%m%d)

  #This is where the convcpys are depending on the passed directory name
  convcpy_loc="/home/oframe/common/convcpy/$convcpy_dir"

  #This is the directory where the generated schemas go
  schema_loc="$OPENFRAME_HOME/schema"

  #This is the name of the script.
  #We store this value because the logs that are generated will be named with the script name and date
  basename=$(basename $0)

  #This is the default volume where the migrated data will be stored (This is the volumes Serial name)
  default_volser="DEFVOL"

  #This is the default volume location
  default_vol_loc="$OPENFRAME_HOME/volume_default"

  #This is the directory where the logs for this script will go
  log_dir="$OPENFRAME_HOME/log/scripts"

  #This is the default catalogue for GDG bases to be cataloged
  default_catalog="SYS1.MASTER.ICFCAT"

  #Here we are ensuring the user is using this script correctly
  #First we check if they entered a base name for a dataset
  #Then we check if they entered a name for the schema file
  #If not, the usage is displayed to them, and the program terminates
  if [ "$base_name" == "BLKLST.FONTLIB" ]; then
    echo "THE BASE NAME PROVIDED IS BLACKLISTED"
    echo "Adding --import-only option"
    import_only_opt=" --import-only"
  fi
  if [ -z "$base_name" ];then
    echo '-d <dataset> required!'
    usage
  elif [ -z "$schema_file" ]; then
    echo '-s <schema_file> required!'
    usage
  fi

  echo "Environment has been setup"
}

##########################################################################################
#Function
#Description: This function will check if the schema file they entered exists or not.
#It also checks if the schema file has already been generated
#If the schema file has already been generated, it skips the cobgensch call
##########################################################################################
check_schema(){
  echo "convcpy_loc = $convcpy_loc"
  cd $convcpy_loc
  check_return_code $? "cd $convcpy_loc"

 echo "convcpy_loc: $convcpy_loc"
 echo "schemam_loc: $schema_loc"
 echo "schema_file: $schema_file"
 echo "convcopy_loc/schema_file(cpy): ${convcpy_loc}/${schema_file}cpy"
 echo "schema_loc/schema_file: ${schema_loc}/${schema_file}"

  #If the convcpy file exists in the convcpy location
  if [ -f ${convcpy_loc}/${schema_file}cpy ]; then
    #If the schema file is NOT already generated and in the schema location
    if [ ! -f ${schema_loc}/${schema_file} ]; then
      echo "${schema_loc}/${schema_file}"
      #If the convcpy file is newer than the schema file
       cobgensch -f R ${schema_file}cpy
       check_return_code $? "cobgensch -f R ${schema_file}cpy"
    else
      if [ ${convcpy_loc}/${schema_file}cpy -nt ${schema_loc}/${schema_file} ]; then
        echo "WARNING: THE COPYBOOK HAS BEEN "
        echo "MODIFIED SINCE THE SCHEMA FILE WAS GENERATED"
        echo ""
        echo "Regenerating the schema file since the convcpy file has been modified"
        echo "cobgensch -f R ${schema_file}cpy"
        check_return_code $? "cobgensch -f R ${schema_file}cpy"
      fi
    fi
  else
    echo "The Schema File (.convcpy file) Does not Exist"
    echo "...Exitting Script"
    echo ""
    exit 100
  fi

}

##########################################################################################
#Function
#Description: This function is determining the [f]ully [q]ualified names
#For the datasets since only a base name is passed
##########################################################################################
get_fq_name(){
  data_count=0
  cd $input_data_loc
  check_return_code $? "cd $input_data_loc"

  data1_name=$(ls -d ${base_name}* | grep -w ${base_name})
  for data in $data1_name
  do
    data_count=$((data_count + 1))
  done
  if [ $data_count -eq 1 ]; then
    fq_name="$data1_name"
    get_input
  elif [ "${data_count}" -gt "1" ]; then
    for item in $data1_name
    do
      if [ ! -d $item ]; then
       fq_name="$item"
       get_input
      else
        echo "There was an error determining the correct PDS name"
        echo "It may be caused because of similar names like:"
        echo "PDS.NAME.PO.FB_133    PDS.NAME.PO.FB_1000"
        exit 100
      fi
    done
  fi

}

##########################################################################################
#Function
#Description: This is for the logs, it checks the return code of the last executed command
#And spits it out into the log directory specified in the environment setup
#If anything fails, it exits
##########################################################################################
check_return_code(){
  rc=$1
  string_=$2

  if [ "$rc" == 0 ];
  then
    echo "$string_ : SUCCESSFUL" >> ${log_dir}/${basename}.${DATE_}.out
  else
    echo "$string_ : FAILED" >> ${log_dir}/${basename}.${DATE_}.err
    exit 100
  fi
}

##########################################################################################
#Function
#Description: Spits out the usage for this script
##########################################################################################
usage(){
  echo "${basename} Script"
  echo "Description: Use this script to migrate datasets for a GDG,Flat file, and PDS"
  echo "             "
  echo "Usage: $1 [options]"
  echo "-h                : Display this information"
  echo "-b <base_name>    : (Required Field) - Specify the PS/GDG/PO BASE Name"
  echo "-s <schema_file>  : (Required Field) - Specify the Schema file"
  echo "-c <convcpy dir>  : (Required Field) - Specify the name of the convcpy directory"
  echo "                  : Example: APP.APPLICATION1 or APP.APPLICATION2.TEST"
  echo "                  : convcpy_loc is set to APP.APPLICATION1 by default"
  echo "-D                : Enable debug mode: Pass a number 1-3"
  echo "-n                : RUN AS DRYMODE (Will not actually execute the dsmigins)"
  echo "-I                : enable --import-only mode (does not convert EBCDIC to ASCII"
  exit 0
}

##########################################################################################
#Function
#Description: This determines what kind of dataset we are dealing with
#GDG,PDS,FLAT,#TODO VSAM
#It gathers all of the information stored in the data name
##########################################################################################
get_input(){

  count=0
  dataset_type="PS"
  IFS='.' read -ra field <<< "$fq_name"
  count=${#field[@]}
  if [ "${field[$((count-2))]}" == "PO" ]; then
    dataset_type="PDS"
  elif [[ "${field[$((count-3))]}" =~ ^[G][0-9]{4}[V][0-9]{2}$ ]]; then
    dataset_type="GDG"
  fi

  lrecl=$(echo $fq_name | cut -d"_" -f2)
  #TODO we have the fields directly, we dont' have to cut like this
  file_format=$(echo $fq_name | cut -d"_" -f1 | cut -d"." -f${count})
  if [[ $file_format =~ ^[F][B][a-zA-Z]*$ ]]; then
    file_format="FB"
  elif [[ $file_format =~ ^[V][B][a-zA-Z]*$ ]]; then
    file_format="VB"
  fi
  org_type=$(echo $fq_name | cut -d"_" -f1 | cut -d"." -f$((count - 1)))
  echo "file_format: $file_format"
  echo "data_name: $fq_name"
  echo "Field Count: $count"
  echo "dataset_type: $dataset_type"
  echo "org_type: $org_type"

  concat_options

  if [ "$dataset_type" == "PDS" ]; then
    dsmigin_pds
  elif [ "$dataset_type" == "GDG" ]; then
    dsmigin_gdg
  else
    dsmigin_flat
  fi
}

##########################################################################################
#Function
#Description: This function does the dsmigin for a pds
##########################################################################################
dsmigin_pds(){

  #First, Create the PDS in DEFVOL
  create_pds

  echo "dsmigin_pds starting ..."
  cd ${input_data_loc}/${fq_name}
  check_return_code $? "cd ${input_data_loc}/${fq_name}"

  for item in $(ls);do

  cmd="dsmigin ${input_data_loc}/${fq_name}/${item} ${base_name} -m ${item}"
  cmd+=" ${default_volser_opt}"
  cmd+=" ${org_type_opt}"
  cmd+=" ${lrecl_opt}"
  cmd+=" ${file_format_opt}"
#  cmd+=" ${schema_file_opt}"
  cmd+=" ${debug_level_opt}"
  cmd+=" ${import_only_opt}"

  if [ "${dryrun}" -eq 1 ]; then
    echo "**************************DRYRUN*****************************"
    echo "${cmd}"
    check_return_code $? "${cmd}"
    echo "*************************************************************"
  else
    echo "${cmd}"
    ${cmd}
    check_return_code $? "${cmd}"
  fi

  done
  echo "... ending dsmigin_pds"
}

##########################################################################################
#Function
#Description: This function is called for dsmigin of a GDG
##########################################################################################
dsmigin_gdg(){
  #First, Create the GDG Base
  create_gdg_base

  echo "dsmigin_gdg starting ..."
  cd $input_data_loc
  check_return_code $? "cd $input_data_loc"

  cmd="dsmigin ${input_data_loc}/${fq_name} ${base_name}"
  cmd+=" ${default_volser_opt}"
  cmd+=" ${org_type_opt}"
  cmd+=" ${lrecl_opt}"
  cmd+=" ${file_format_opt}"
  cmd+=" ${schema_file_opt}"
  cmd+=" ${debug_level_opt}"
  cmd+=" -m +1"
  cmd+=" ${import_only_opt}"

  if [ "${dryrun}" -eq 1 ]; then
    echo "**************************DRYRUN*****************************"
    echo "${cmd}"
    check_return_code $? "${cmd}"
    echo "*************************************************************"
  else
    echo "${cmd}"
    ${cmd}
    check_return_code $? "${cmd}"
  fi

  echo "... ending dsmigin_gdg"
}
##########################################################################################
#Function
#Description: This function is called for dsmigin of a flat file
##########################################################################################
dsmigin_flat(){

  echo "dsmigin_flat starting ..."
  cd $input_data_loc
  check_return_code $? "cd $input_data_loc"

  cmd="dsmigin ${input_data_loc}/${fq_name} ${base_name}"
  cmd+=" ${default_volser_opt}"
  cmd+=" ${org_type_opt}"
  cmd+=" ${lrecl_opt}"
  cmd+=" ${file_format_opt}"
  cmd+=" ${schema_file_opt}"
  cmd+=" ${debug_level_opt}"
  cmd+=" ${import_only_opt}"

  if [ "${dryrun}" -eq 1 ]; then
    echo "**************************DRYRUN*****************************"
    echo "${cmd}"
    check_return_code $? "${cmd}"
    echo "*************************************************************"
  else
    echo "${cmd}"
    ${cmd}
    check_return_code $? "${cmd}"
  fi

    echo "... ending dsmigin_flat"
}

##########################################################################################
#Function
#Description: This function creates a GDG base
##########################################################################################
create_gdg_base(){
  listcat_count=$(listcat -n $base_name | grep "GDG" | wc -l)
  if [ $listcat_count == 1 ]; then
    echo "The GDG base is already created, skipping create_gdg_base"
  else
    if [ "$dryrun" == "1" ]; then
      echo "gdgcreate $base_name -c $default_catalog"
    else
      echo "gdgcreate $base_name -c $default_catalog"
      gdgcreate $base_name -c $default_catalog
      check_return_code $? "gdgcreate $base_name -c $default_catalog"
    fi
  echo ""
  fi
}

##########################################################################################
#Function
#Description: This function creates a PDS
##########################################################################################
create_pds(){
  cd $default_vol_loc
  check_return_code $? "cd $default_vol_loc"

  if [ -d $base_name ]; then
    echo "PDS: $base_name is already created"
  else
    if [ $dryrun == 1 ]; then
#      echo "pdsgen $base_name ${default_volser} -f ${file_format} -l ${lrecl}"
      check_return_code $? "pdsgen $base_name ${default_volser} -f ${file_format} -l ${lrecl}"
    else
#      echo "pdsgen $base_name ${default_volser} -f ${file_format} -l ${lrecl}"
#      pdsgen $base_name ${default_volser} -f ${file_format} -l ${lrecl}
      echo "dscreate -o PO -l 80 -f FB -v DEFVOL $base_name"
      dscreate -o PO -l 80 -f FB -v DEFVOL $base_name
      check_return_code $? "dscreate -o PO -l 80 -f FB -v DEFVOL $base_name"
    fi
  fi
}

##########################################################################################
#Function
#Description: Concatenating the command based ont he options passed
##########################################################################################
concat_options(){
  echo "concatenating the options ..."
  case $debug_level in
    0) debug_level_opt="";;
    1) debug_level_opt=" -D 1";;
    2) debug_level_opt=" -D 2";;
    3) debug_level_opt=" -D 3";;
    *) echo "Debug level needs to be 0-3"
       usage;;
  esac

  default_volser_opt=" -v $default_volser"
  file_format_opt=" -f ${file_format}"
  lrecl_opt=" -l ${lrecl}"
  org_type_opt=" -o ${org_type}"
  schema_file_opt=" -s ${schema_file}"

 # cmd="dsmigin ${input_data_loc}/${fq_name} ${base_name}"
 # cmd+=" ${default_volser_opt}"
 # cmd+=" ${org_type_opt}"
 # cmd+=" ${lrecl_opt}"
 # cmd+=" ${file_format_opt}"
 # cmd+=" ${schema_file_opt}"
 # cmd+=" ${debug_level_opt}"

  echo "... finished concatenating options"
}
##########################################################################################
#Function
#Description: Main function Starts here
#First, call environment_setup to set some variables based on environment
#Second, Check the schema file. Check if it exists, check if the convcpy file exists
#cobgensch -f R if the convcpy exists and the schema file does not.
#Third, get the fully qualified name of the dataset passed in.
##########################################################################################
main(){
  echo "Starting data_dsmigin.sh ..."
  environment_setup
  check_schema
  get_fq_name
  echo "... Completed data_dsmigin.sh"
}

#Setting some variables for debug and dryrun options
debug_level=0
dryrun=0
import_only_opt=""


while getopts "hb:s:D:nc:I" options
do
  case $options in
    h) usage;;
    c) convcpy_dir=$OPTARG;;
    n) dryrun=1;;
    b) base_name=$OPTARG;;
    s) schema_file=$OPTARG;;
    D) debug_level=$OPTARG;;
    I) import_only_opt=" --import-only";;
    *) usage;;
  esac
done

main
exit 0

