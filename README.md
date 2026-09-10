# Arriba_ncl

Here are two bash scripts and one R script which run an end-to-end analysis of RNA-sequencing fusion detection using [Arriba](https://github.com/suhrig/arriba) on the Newcastle University server (Comet) with slurm scheduler.

The scripts include:  
* `arriba_prep.sh`:
    * Arriba release (v2.5.1), associated references and genome build (GRCh38) and annotation (GENCODE38) are downloaded and compiled where necessary.
    * STAR indexes are generated.
    * Required R packages are installed in a local directory.
* `arriba_run.sh`
    * STAR alignment is performed using [Arriba-recommended parameters](https://github.com/suhrig/arriba/wiki/03-Workflow) and outputs are saved to disk to allow manual inspection in IGV if required.
    * Arriba fusion analysis is performed incorporating the use of the associated blacklist, protein domain information and information about known fusions (included in the Arriba release).
    * Post-analysis `.bam` files are sorted and indexed using samtools.
    * Fusions are plotted using the provided `draw_fusions.R` script with the locally installed libraries (installed during `arriba_prep.sh`).
    * `arriba_run.sh` is run as a slurm job array for parallel processing of multiple samples.

### Setup

* Create a new directory and move into it.
* Git clone this repository.
```
git clone https://github.com/RECranston/Arriba_ncl.git
```
* Change into the cloned directory `cd Arriba_ncl`. Make the `arriba_prep.sh`, `arriba_run.sh` and `install_R_packages.R` scripts executable
```
chmod 777 *.sh
chmod 777 install_R_packages.R
```
* Edit the script header of `arriba_prep.sh` and `arriba_run.sh` to assign the correct account name to the sbatch run.
* Run the setup script. 
```
sbatch ./arriba_prep.sh
```
* The defined arriba release will now be downloaded and compiled. Defined genome files and annotations will be downloaded and associated STAR indexes will be generated.
* Ensure trimmed fastq.gz files are available and defined in a tab-separated sample sheet where the first column is the name of the sample to be analysed. Save this file as a `.txt`.
The sample sheet can include 2 fastq files per sample name or multiple paired fastqs per sample (or a mix of both) as per the examples below:
```
sample_name  sample1_L001_R1.fastq.gz  sample1_L001_R2.fastq.gz
```
Or
```
sample1  sample1_L001_R1.fastq.gz  sample1_L001_R2.fastq.gz  sample1_L002_R1.fastq.gz  sample1_L002_R2.fastq.gz  sample1_L003_R1.fastq.gz  sample1_L003_R2.fastq.gz
```
* Move all fastq.gz files for analysis (or symlink using `ln -s`) to a sub-directory within the current directory.

### Run the pipeline
Parameters required for arriba_run.sh can be checked by running ./arriba_run.sh in the terminal:
```
sbatch ./arriba_run.sh <tab delimited sample sheet> <input fastq dir (relative)> <output dir (relative)>
```
* `<tab delimited sample sheet>` is the name of the sample sheet (`.txt` file) of fastq.gz file locations and associated sample names created during the setup stage.
* `<input fastq dir (relative)>` is the location of the directory containing the fastq.gz files relative to the current directory e.g. `trimmed_fastq/` (note the trailing “/”). This is the directory which was created and populated during the setup stage.
* Similarly `<output dir (relative)>` is the location of the directory where the output data is to be stored, relative to the current directory e.g. `arriba_output/` (note the trailing “/”).
* Please edit the script header to assign the correct account name to the sbatch run and the correct number of jobs in the array, and jobs to be simultaneously performed.  
  E.g. this example runs samples 1-10 from the sample sheet, running two samples at a time.
```
#SBATCH --array=1-10%2
```
This can usually be defined by the number of rows in the sample sheet e.g. `cat sample_sheet.txt | wc -l`
* Run the script using your custom input e.g.:
```
sbatch ./arriba_run.sh sample_sheet.txt trimmed_fastq/ arriba_output/
```
* Resulting data is saved to the defined output directory including `.bam`, `.bam.bai`, `.pdf` reports from `draw_fusions.R`, and `.tsv` files containing detected fusions and discarded fusion calls.
