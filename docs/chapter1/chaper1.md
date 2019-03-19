# Chapter 1. Source code migration

This chapter describes options on moving the source code from the Mainframe to the Linux server for the source code and data to be migrated into OpenFrame.  
TmaxSoft recommends transferring all source code to reduce the amount of missing source code during the discovery phase utilizing OFMiner. 
For Discovery, TmaxSoft requires the JCL, Procedures, COBOL and copybooks, so these elements should be prioritized.  

At the point of transfer, TmaxSoft recommends putting a code freeze in effect to minimize change of scope, as reanalyzing a new scope can cause larger than expected delays in project timeline.
Additionally, any code changes that are required on the mainframe need to be carefully tracked to allow TmaxSoft to test these code changes before cutover.

## Option 1: SFTP from Mainframe to Linux Server (On Premise)

TmaxSoft will provide a sample JCL to transfer the source code.  
You (The client) will have to change the sample IP address we have provided to the IP of the Linux server that we provide and run the JCL.  
This will transfer the files to the IP address provided in the PARM of the JCL.  
TmaxSoft will then need access to the Linux server via virtual machine and or VPN connection credentials.

### Requirements from Client:

1. Gather Source code prepare all in scope libraries for FTP
1. Modify JCL to connect to Linux Server

### Requirements from TmaxSoft:

1. Provide the sample JCL
1. Provide IP address of Linux Server (If built by TmaxSoft)
1. Provide source code destination directory

### Sample JCL:
<pre>
//USER001  JOB ,CARTER,MSGLEVEL=(1,1)
//FTPSTP1  EXEC PGM=FTP,REGION=2048K,
//             PARM='12.23.45.678 (EXIT TIMEOUT 120'
//SYSPRINT DD SYSOUT=\*
//SYSOUT   DD SYSOUT=\*
//INPUT    DD  \*
USER
PSSWD
ascii
prompt
cd 'destination full directory path'
lcd 'mainframe pds name'
mput
/*
//*
</pre>

## Option 2: SCP From On Premise Server to Offsite Linux Server

If the Linux server is off premise, you will still have to do Option 1, but there is an additional step.    
Once the source code is on a linux server, the files can be SCP’d (Secure Copied) using WinSCP or FileZilla.

## Option 3: Physical Handover

This option will require the client to download the source code onto a hard drive.  
The client can use the steps mentioned in Option 1;  
instead of putting the source onto a server, the source should be downloaded to a drive that can be handed over to TmaxSoft.  
TmaxSoft will then upload the source code to the Linux Server.  
This process will be done using SCP (Secure Copy) via WinSCP or FileZilla.
