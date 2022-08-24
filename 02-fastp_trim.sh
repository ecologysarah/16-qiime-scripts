#!/bin/bash

#This script will quality trim and remove adapters from sequencing data using fastp (Chen et al 2018). It relies on correctly setting the variables indicated below.
#Written by Sarah Christofides, 2022. Released under Creative Commons BY-SA.

###VARIABLES TO BE SET###
##Set the path to your directory on scratch - do not include a trailing /
myDir=
##Set your username
userProject=
##Indicate if the data is single-end (SE) or paired-end (PE)
ends=PE
##Indicate if you want to specify an adapter for SE reads (set as "" to omit)
adapt=""
##Set the slurm queue to use: defq for gomphus, epyc for iago, htc for hawk
queue=epyc
######

sampleIDs=$(cat ${myDir}/01-download/SampleFileNames.txt)

mem="20G"
cpu="1"
runTime="00:05:00"
scriptBase="02trim"

##Set the correct version of fastp
FASTP=$(module avail -L fastp/ | tail -n 1)
##Append this information to the report
echo -e "\nSequences quality trimmed with ${FASTP}" >> ${myDir}/AnalysisReport.txt

##Make the output directory
if [ ! -d "${myDir}"/02-trim ]
        then mkdir ${myDir}/02-trim
fi

##Loop over each sample in turn

for sampleID in $sampleIDs
do

        ## write a script to the temp/ directory (one for each sample)
        scriptName=${myDir}/temp/${scriptBase}.${sampleID}.sh

        ## make an empty script for writing
        touch ${scriptName}

        ## write the SLURM parameters to the top of the script
        echo "#!/bin/bash" > ${scriptName}
        echo "#SBATCH --partition=${queue}" >> ${scriptName}
        echo "#SBATCH --mem-per-cpu=${mem}" >> ${scriptName}
        echo "#SBATCH --nodes=1" >> ${scriptName}
        echo "#SBATCH --tasks-per-node=${cpu}" >> ${scriptName}
	echo "#SBATCH --time=${runTime}" >> ${scriptName}
        echo "#SBATCH --output ${myDir}/OUT/${scriptBase}${jobName}.%J" >> ${scriptName}
        echo "#SBATCH --error ${myDir}/ERR/${scriptBase}${jobName}.%J" >> ${scriptName}

        ## load the module
        echo "module load $FASTP

        ##Find the path to the file
        LOCATION=\$(find ${myDir}/01-download/ -name ${sampleID}R1* | sed -E 's/(.+)\/.+/\1/')

	## ascertain the format of the end of the file name
	FILEND=\$(ls \${LOCATION}/${sampleID}R1* | sed -E 's/.+_R1(.+)/\1/')" >> ${scriptName}

        ## run the command
        echo "fastp -h ${myDir}/02-trim/trim_${sampleID}.html \\
        -i \${LOCATION}/${sampleID}R1\${FILEND} \\" >> ${scriptName}
        if [ ! "${adapt}" = "" ]; then echo "-a ${adapt} \\" >> ${scriptName}; fi
        if [ "${ends}" = PE ]; then echo "-I \${LOCATION}/${sampleID}R2\${FILEND} \\" >> ${scriptName}; fi
        echo "-o ${myDir}/02-trim/trim_${sampleID}_R1\${FILEND} \\" >> ${scriptName}
        if [ "${ends}" = PE ]; then echo "-O ${myDir}/02-trim/trim_${sampleID}_R2\${FILEND} \\" >> ${scriptName}; fi
	##Set the minimum phred score to 20
	echo -e "-q 20
	" >> ${scriptName}

        ## make the script into an 'executable'
        chmod u+x ${scriptName}

        ## submit the script to the compute queue
        sbatch ${scriptName}

done

exit 0

