#!/bin/bash

#This script will read the trimmed data into QIIME, denoise it with DADA2 and return summary visualisations. It relies on correctly setting the variables indicated below.
#Written by Sarah Christofides, 2022. Released under Creative Commons BY-SA.

###VARIABLES TO BE SET###
#Set the path to your directory on scratch - do not include a trailing /
myDir=
#Set your username
userProject=
#Path to metadata (mapping) file. See https://docs.qiime2.org/2022.2/tutorials/metadata/
metadat=
#Indicate if the data is single-end (SE) or paired-end (PE)
ends=PE
#Set the slurm queue to use: defq for gomphus, epyc for iago, htc for hawk
queue=epyc
######

mem="2G"
cpu="100"
runTime="05:00:00"
scriptBase="04denoise"

##Set the correct version of QIIME
QIIME=$(module avail -L qiime/ | tail -n 1)
##Append this information to the report
echo -e "\nSequences denoised using DADA2 in ${QIIME}" >> ${myDir}/AnalysisReport.txt

##Make directories for the output
DIRLIST=("04-denoise" "04-denoise/input" "04-denoise/visualisations")
for DIRECTORY in "${DIRLIST[@]}"
do
        if [ ! -d "${myDir}/$DIRECTORY" ]; then
          mkdir ${myDir}/${DIRECTORY}
        fi
done

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

echo "module load ${QIIME}" >> ${scriptName}

##Make a file manifest
if [ "${ends}" = PE ]
	then echo "echo -e \"sample-id\tforward-absolute-filepath\treverse-absolute-filepath\" > ${myDir}/04-denoise/manifest.txt" >> ${scriptName}
	else echo "echo -e \"sample-id\tforward-absolute-filepath\" > ${myDir}/04-denoise/manifest.txt" >> ${scriptName}
fi

echo "cat ${metadat} | sed '1d' | cut -f 1 | while read line
do
        file1=\$(ls ${myDir}/02-trim/*\${line}_*R1*)" >> ${scriptName}
        if [ "${ends}" = PE ]; then echo "	file2=\$(ls ${myDir}/02-trim/*\${line}_*R2*)" >> ${scriptName}; fi
        if [ "${ends}" = PE ]; then echo "	echo -e \"\${line}\t\${file1}\t\${file2}\" >> ${myDir}/04-denoise/manifest.txt" >> ${scriptName}
		else echo "	echo -e \"\${line}\t/\${file1}\" >> ${myDir}/04-denoise/manifest.txt" >> ${scriptName}
	fi
echo "done" >> ${scriptName}

##Tabulate the metadata (mapping) file. This step effectively serves to validate this file.
echo "qiime metadata tabulate \\
  --m-input-file ${metadat} \\
  --o-visualization ${myDir}/04-denoise/metadata.qzv" >> ${scriptName}

##Load the data into a QIIME artefact

echo "qiime tools import \\" >> ${scriptName}
if [ "${ends}" = SE ]
	then echo "  --type 'SampleData[SequencesWithQuality]' \\" >> ${scriptName}
	else echo "  --type 'SampleData[PairedEndSequencesWithQuality]' \\" >> ${scriptName}
fi
echo "  --input-path ${myDir}/04-denoise/manifest.txt \\" >> ${scriptName}
if [ "${ends}" = SE ]
        then echo "  --input-format SingleEndFastqManifestPhred33V2 \\" >> ${scriptName}
        else echo "  --input-format PairedEndFastqManifestPhred33V2 \\" >> ${scriptName}
fi
echo "  --output-path ${myDir}/04-denoise/input/input-seqs.qza" >> ${scriptName}

##Denoise using DADA2. Discard reads with >2 expected errors.
if [ "${ends}" = SE ]
        then echo "qiime dada2 denoise-single \\
  --p-trunc-len 0 \\" >> ${scriptName}
        else echo "qiime dada2 denoise-paired \\
  --p-trunc-len-f 0 \\
  --p-trunc-len-r 0 \\" >> ${scriptName}
fi
if [ "${ends}" = SE ]
        then echo "  -- p-max-ee 2.0 \\" >> ${scriptName}
        else echo "  --p-max-ee-f 2.0 \\
  --p-max-ee-r 2.0 \\" >> ${scriptName}
fi
echo "  --i-demultiplexed-seqs ${myDir}/04-denoise/input/input-seqs.qza \\
  --p-chimera-method \"consensus\" \\
  --p-n-threads ${cpu} \\
  --o-table ${myDir}/04-denoise/table.qza \\
  --o-representative-sequences ${myDir}/04-denoise/representative_sequences.qza \\
  --o-denoising-stats ${myDir}/04-denoise/denoising_stats.qza" >> ${scriptName}

##Summarise results
echo "qiime feature-table summarize \\
  --i-table ${myDir}/04-denoise/table.qza \\
  --o-visualization ${myDir}/04-denoise/visualisations/table.qzv \\
  --m-sample-metadata-file ${metadat}" >> ${scriptName}
  
echo "qiime feature-table tabulate-seqs \\
  --i-data ${myDir}/04-denoise/representative_sequences.qza \\
  --o-visualization ${myDir}/04-denoise/visualisations/representative_sequences.qzv" >> ${scriptName}

##Get info on reads discarded etc
echo "qiime tools export \\
  --input-path ${myDir}/04-denoise/denoising_stats.qza \\
  --output-path ${myDir}/04-denoise" >> ${scriptName}

echo "exit 0" >> ${scriptName}

##Make the script executable
chmod u+x ${scriptName}

##Submit the script to the compute queue
sbatch ${scriptName}

exit 0
