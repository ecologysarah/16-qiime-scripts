#!/bin/bash

#This script will tar compress and archive your data. The OUT, ERR and temp directories are not included. It relies on correctly setting the variables indicated below.
#Written by Sarah Christofides, 2022. Released under Creative Commons BY-SA.

###VARIABLES TO BE SET###
#Set the path to your directory on scratch - do not include a trailing /
myDir=
#Set your username
userProject=
#Set the name and path for the tar file (do not include the file extension)
TAR=
#Set the path to the archive location. N.B. If this is a remote server, it will need a ssh key pair in place.
ARCHIVE=
#Set the slurm queue to use: defq for gomphus, epyc for iago, htc for hawk
queue=epyc
######

mem="40G"
cpu="2"
runTime="05:00:00"
scriptBase="06-archive"

##Create the slurm script
scriptName=${myDir}/temp/${scriptBase}.sh
rm -rf ${scriptName} || true
touch ${scriptName}

echo "#!/bin/bash" >> ${scriptName}
echo "#SBATCH --partition=${queue}" >> ${scriptName}
echo "#SBATCH --mem-per-cpu=${mem}" >> ${scriptName}
echo "#SBATCH --nodes=1" >> ${scriptName}
echo "#SBATCH --cpus-per-task=${cpu}" >> ${scriptName}
echo "#SBATCH --time=${runTime}" >> ${scriptName}
echo "#SBATCH --output ${myDir}/OUT/${scriptBase}.%J" >> ${scriptName}
echo "#SBATCH --error ${myDir}/ERR/${scriptBase}.%J" >> ${scriptName}

##Create the tar archive
echo "tar -czvf ${myDir}/${TAR}.tar.gz --exclude={"${myDir}/ERR","${myDir}/OUT","${myDir}/temp"} ${myDir}" >> ${scriptName}

##Transfer it to the backup location
echo "rsync ${myDir}/${TAR}.tar.gz ${ARCHIVE}" >> ${scriptName}

echo "exit 0" >> ${scriptName}

##Make the script executable
chmod u+x ${scriptName}

##Submit the script to the compute queue
sbatch ${scriptName}

exit 0

