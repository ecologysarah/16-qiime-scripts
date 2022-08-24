This is a set of scripts to take 16S amplicon data from raw FASTQs on a remote server through to ASVs with assigned taxonomy and basic QIIME plots. It uses fastp for quality trimming and fastQC and multiqc for quality assessment. The remaining steps are done in QIIME, using DADA2 for denoising. 
This scripts were designed to be run on Cardiff School of Biosciences' server iago, which uses a slurm job scheduler and modules for loading software. 
Sarah Christofides, August 2022
