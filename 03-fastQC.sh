#!/bin/bash

#This script will quality check the raw and trimmed data using fastQC. It relies on correctly setting the variables indicated below.
#Written by Sarah Christofides, 2022, based on a script from Rob Andrews. Released under Creative Commons BY-SA.

###VARIABLES TO BE SET###
#Set the path to your directory on scratch - do not include a trailing /
myDir=
#Set your username
userProject=
#Indicate if the data is single-end (SE) or paired-end (PE)
ends=PE
#Set the slurm queue to use: defq for gomphus, epyc for iago, htc for hawk
queue=epyc
######

sampleIDs=$(cat ${myDir}/01-download/SampleFileNames.txt)

mem="20G"
nodes="1"
runTime="00:05:00"
scriptBase="03QC"
slurmids=""

#Set the correct version of FastQC and multiqc
FASTQC=$(module avail -L fastqc/ | tail -n 1)
multiQC=$(module avail -L multiqc/ | tail -n 1)
##Append this information to the report
echo -e "\nQuality assessed with ${FASTQC} and ${multiQC}" >> ${myDir}/AnalysisReport.txt

#Make directories for the output
DIRLIST=("03-fastqc" "03-fastqc/raw" "03-fastqc/trimmed" "03-fastqc/multiqc")
for DIRECTORY in "${DIRLIST[@]}"
do
        if [ ! -d "${myDir}/$DIRECTORY" ]; then
          mkdir ${myDir}/${DIRECTORY}
        fi
done

#For each sample in turn, create and run a slurm script that will do FastQC
for sampleID in $sampleIDs
do
	scriptName=${myDir}/temp/${scriptBase}.${sampleID}.sh
	rm -rf ${scriptName} || true
	touch ${scriptName}

	echo "#!/bin/bash" >> ${scriptName} 
        echo "#SBATCH --partition=${queue}" >> ${scriptName}
        echo "#SBATCH --mem-per-cpu=${mem}" >> ${scriptName}
        echo "#SBATCH --nodes=${nodes}" >> ${scriptName}
        echo "#SBATCH --tasks-per-node=${nodes}" >> ${scriptName}
	echo "#SBATCH --time=${runTime}" >> ${scriptName}
        echo "#SBATCH --output ${myDir}/OUT/${scriptBase}${jobName}.%J" >> ${scriptName}
        echo "#SBATCH --error ${myDir}/ERR/${scriptBase}${jobName}.%J" >> ${scriptName}

	echo "module load ${FASTQC}" >> ${scriptName}	

	## run fastqc on the raw fastq

	echo -n "fastqc -o ${myDir}/03-fastqc/raw/ ${myDir}/01-download/*/${sampleID}R1*" >> ${scriptName}
        if [ "${ends}" = PE ]; then echo " ${myDir}/01-download/*/${sampleID}R2*" >> ${scriptName}; fi
	echo -e "\n" >> ${scriptName}

	## run fastqc on the trimmed fastq

	echo -n "fastqc -o ${myDir}/03-fastqc/trimmed/ ${myDir}/02-trim/trim_${sampleID}_R1*" >> ${scriptName}
        if [ "${ends}" = PE ]; then echo " ${myDir}/02-trim/trim_${sampleID}_R2*" >> ${scriptName}; fi

	echo -e "\nexit 0" >> ${scriptName}

	chmod u+x ${scriptName}

        slurmids="${slurmids}:$(sbatch --parsable ${scriptName})"

done

#Create and run a slurm script that will do multiQC on both sets of FastQCs
scriptName=${myDir}/temp/${scriptBase}.sh
touch ${scriptName}

echo "#!/bin/bash" > ${scriptName}
echo "#SBATCH --partition=defq" >> ${scriptName}
echo "#SBATCH --mem-per-cpu=${mem}" >> ${scriptName}
echo "#SBATCH --nodes=${nodes}" >> ${scriptName}
echo "#SBATCH --tasks-per-node=${nodes}" >> ${scriptName}
echo "#SBATCH --output ${myDir}/OUT/${scriptBase}${jobName}.%J" >> ${scriptName}
echo "#SBATCH --error ${myDir}/ERR/${scriptBase}${jobName}.%J" >> ${scriptName}

echo "module load ${multiQC}" >> ${scriptName}

#Run multiQC on the raw fastQC
echo "multiqc ${myDir}/03-fastqc/raw/ -o ${myDir}/03-fastqc/multiqc/ -i Raw -f" >> ${scriptName}

#Run multiQC on the trimmed fastQC
echo "multiqc ${myDir}/03-fastqc/trimmed/ -o ${myDir}/03-fastqc/multiqc -i Trimmed -f" >> ${scriptName}

chmod u+x ${scriptName}

sbatch -d afterok${slurmids} ${scriptName}

exit 0
