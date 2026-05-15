#!/bin/bash
#SBATCH --account=XXXX
#SBATCH --partition=default_free
#SBATCH --mem=50G
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=10
#SBATCH --job-name=arriba_prep
#SBATCH --output=slurm_log_%j.out


# STAR index making 8 cpus

echo -en "\nA script for preparing working dir for Arriba RNA-Seq fusion detection\n\n"
echo -en "Ruth Cranston 2026\n"
echo " "

# Load modules
echo -en "Loading modules...\n"
module --force purge
module load STAR
module load R/4.4.2-gfbf-2024a
echo -en "Environment set up.\n"

### Prepare all indexes and gene lists etc

# Set parameters
BASE_DIR="$PWD"

# Detect if Arriba is already downloaded and built
#ARRIBA_VER="v1.2.0" # old version
ARRIBA_VER="v2.5.1"
ARRIBA_DIR="arriba_${ARRIBA_VER}"
ARRIBA="${ARRIBA_DIR}/arriba"
ARRIBA_REL="https://github.com/suhrig/arriba/releases/download/${ARRIBA_VER}/arriba_${ARRIBA_VER}.tar.gz"

echo "Detecting if Arriba is present"
if [[ -f ${ARRIBA} ]]
then
    echo -en " * Arriba binary found, no need to fetch and compile\n"
else
    echo -en " * Arriba not found, downloading and compiling from source...\n"
    # rm incomplete downloads or extractions
    [[ -e arriba_${ARRIBA_VER}.tar.gz ]] && rm arriba_${ARRIBA_VER}.tar.gz
    [[ -e arriba_${ARRIBA_VER} ]] && rm -rf arriba_${ARRIBA_VER}
    wget -q ${ARRIBA_REL}
    tar -xf arriba_${ARRIBA_VER}.tar.gz
    cd ${ARRIBA_DIR}
    make
    cd $BASE_DIR
fi

# Detect if STAR index + reference and annotation is present
REF="GRCh38"
ANNO="GENCODE38"
REF_ANNO="${REF}+${ANNO}"
STAR_INDEX_DIR="STAR_index_${REF}_${ANNO}"
STARI_CPU=8

echo -ne "\nDetecting if STAR index is present\n"
if [[ -d ${STAR_INDEX_DIR} ]]
then
    echo -en " * STAR index ${STAR_INDEX_DIR} found, no need to rebuild\n"
else
    echo -en " * STAR index not found, downloading and building on $STARI_CPU cpu core(s)... (this may take some time)\n"
    # Run script with options
    ./${ARRIBA_DIR}/download_references.sh ${REF_ANNO}
fi

# create directory for R packages
if [[ -d ${BASE_DIR}/R_packages/ ]]
then
    rm -rf ${BASE_DIR}/R_packages/
fi
mkdir ${BASE_DIR}/R_packages/

# Set R temp directory to avoid permission issues
mkdir -p ${BASE_DIR}/R_tmp
export TMPDIR=${BASE_DIR}/R_tmp
export R_TempDir=${BASE_DIR}/R_tmp

# install R packages
echo -ne " - Downloading R packages \n"
${BASE_DIR}/install_R_packages.R

# clean up
rm -rf ${BASE_DIR}/R_tmp

echo -ne "\nArriba prep complete\n"
