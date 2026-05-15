#!/bin/bash
#SBATCH --account=XXXXX
#SBATCH --partition=default_free
#SBATCH --mem=100G
#SBATCH --time=6:00:00
#SBATCH --cpus-per-task=8
#SBATCH --job-name=arriba_run
#SBATCH --output=logs/arriba_%A_%a.out
#SBATCH --array=1-2%2

echo -en "\nA script for running Arriba RNA-Seq fusion detection\n\n"
echo -en "Ruth Cranston 2026\n"
echo " "

# We need a sample sheet to run
[ $# -ne 3 ] && { echo -en " *** Error Nothing to do, usage: <tab delimited sample sheet> <input fastq dir (relative)> <output dir (relative)> ***\n
Make sure sample sheet format is:\nSAMPLE_ID  R1  R2\nOR\nSAMPLE_ID  R1.1  R2.1  R1.2  R2.2\n\n" ; exit 1; }

# Load modules
echo -en "Loading modules...\n"
module --force purge
module load STAR
module load SAMtools
module load Python/3.12.3-GCCcore-13.3.0
module load R/4.4.2-gfbf-2024a
echo -en "Environment set up.\n"

### Set parameters for script
BASE_DIR="$PWD"
SAMPLE_SHEET=$1
INPUT_DIR=$2
OUTPUT_DIR=$3
ARRIBA_VER="v2.5.1"
ARRIBA_DIR="arriba_${ARRIBA_VER}"
REF="GRCh38"
ANNO="GENCODE38"
BLACKLIST="${BASE_DIR}/${ARRIBA_DIR}/database/blacklist_hg38_${REF}_${ARRIBA_VER}.tsv.gz"
KNOWN_FUSIONS="${BASE_DIR}/${ARRIBA_DIR}/database/known_fusions_hg38_${REF}_${ARRIBA_VER}.tsv.gz"
PROTEIN_DOMAINS="${BASE_DIR}/${ARRIBA_DIR}/database/protein_domains_hg38_${REF}_${ARRIBA_VER}.gff3"
CYTOBANDS="${BASE_DIR}/${ARRIBA_DIR}/database/cytobands_hg38_${REF}_${ARRIBA_VER}.tsv"
STAR_INDEX_DIR="STAR_index_${REF}_${ANNO}"

### Script starts - running as an array

# Remove output dir file if exists
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

### Run STAR alignment jobs
echo -ne "\nRunning STAR alignment jobs...\n"

# Read the line safely
LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_SHEET" | tr -d '\r')
IFS=$'\t' read -r -a FIELDS <<< "$LINE"

SAMPLE_ID="${FIELDS[0]}"

R1_FULL=()
R2_FULL=()

for ((i=1; i<${#FIELDS[@]}; i+=2)); do
    r1="${FIELDS[i]}"
    r2="${FIELDS[i+1]}"

    # skip if empty
    [[ -z "$r1" || -z "$r2" ]] && continue

    # prepend INPUT_DIR once
    R1_FULL+=("${INPUT_DIR}${r1}")
    R2_FULL+=("${INPUT_DIR}${r2}")
done

R1_CSV=$(IFS=,; echo "${R1_FULL[*]}")
R2_CSV=$(IFS=,; echo "${R2_FULL[*]}")

echo "  - Processing sample: ${SAMPLE_ID}"
echo "  - Task ID: ${SLURM_ARRAY_TASK_ID}"

# STAR align command
STAR --runThreadN ${SLURM_CPUS_PER_TASK} \
     --genomeDir ${STAR_INDEX_DIR} \
     --outFileNamePrefix ${OUTPUT_DIR}${SAMPLE_ID}. \
     --outTmpDir ${OUTPUT_DIR}TmpDir_${SAMPLE_ID} \
     --genomeLoad NoSharedMemory \
     --readFilesCommand zcat \
     --outSAMtype BAM Unsorted \
     --outBAMcompression 9 \
     --readFilesIn "${R1_CSV}" "${R2_CSV}" \
     --outSAMunmapped Within \
     --outFilterMultimapNmax 1 \
     --outFilterMismatchNmax 3 \
     --chimSegmentMin 10 \
     --chimOutType WithinBAM SoftClip \
     --chimJunctionOverhangMin 10 \
     --chimScoreMin 1 \
     --chimScoreDropMax 30 \
     --chimScoreJunctionNonGTAG 0 \
     --chimScoreSeparation 1 \
     --alignSJstitchMismatchNmax 5 -1 5 5 \
     --chimSegmentReadGapMax 3

# Post alignment clean up
echo -ne "Performing post-alignment clean-up for ${SAMPLE_ID}\n"
mv ${OUTPUT_DIR}${SAMPLE_ID}.Aligned.out.bam ${OUTPUT_DIR}${SAMPLE_ID}.bam
rm ${OUTPUT_DIR}${SAMPLE_ID}.Log.final.out
rm ${OUTPUT_DIR}${SAMPLE_ID}.Log.out
rm ${OUTPUT_DIR}${SAMPLE_ID}.Log.progress.out
rm ${OUTPUT_DIR}${SAMPLE_ID}.SJ.out.tab


### Run Arriba jobs
echo -ne "Running Arriba for ${SAMPLE_ID}\n"
${ARRIBA_DIR}/arriba \
	-x ${OUTPUT_DIR}${SAMPLE_ID}.bam \
	-o ${OUTPUT_DIR}${SAMPLE_ID}_fusions.tsv \
	-O ${OUTPUT_DIR}${SAMPLE_ID}_fusions.discarded.tsv \
	-a ${BASE_DIR}/${REF}.fa \
	-g ${BASE_DIR}/${ANNO}.gtf \
	-b ${BLACKLIST} \
	-k ${KNOWN_FUSIONS} \
	-t ${KNOWN_FUSIONS} \
	-p ${PROTEIN_DOMAINS}

### Sort bam files and index using SAMtools
echo -ne "\nRunning SAMtools jobs to sort output BAM...\n"
samtools sort \
	 -@ ${SLURM_CPUS_PER_TASK} \
	 -l 9 \
	 -o ${OUTPUT_DIR}${SAMPLE_ID}.sorted.bam \
	 -O 'bam' \
	 -T ${OUTPUT_DIR}temp_${SAMPLE_ID}.bam \
	 ${OUTPUT_DIR}${SAMPLE_ID}.bam

samtools index -b ${OUTPUT_DIR}${SAMPLE_ID}.sorted.bam
rm ${OUTPUT_DIR}${SAMPLE_ID}.bam

### Plot fusions
echo -ne "\nPlotting Arriba fusions...\n"

# export the R libraries location (downloaded during comet_prep_arriba.sh)
export R_LIBS="${BASE_DIR}/R_packages"
${BASE_DIR}/${ARRIBA_DIR}/draw_fusions.R \
       --fusions=${OUTPUT_DIR}${SAMPLE_ID}_fusions.tsv \
       --alignments=${OUTPUT_DIR}${SAMPLE_ID}.sorted.bam \
       --output=${OUTPUT_DIR}${SAMPLE_ID}.pdf \
       --annotation=${ANNO}.gtf \
       --cytobands=${CYTOBANDS} \
       --proteinDomains=${PROTEIN_DOMAINS}
   
echo -ne "\nAll done!\n"