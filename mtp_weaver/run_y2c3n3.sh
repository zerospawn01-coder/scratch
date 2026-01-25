#!/bin/bash
#SBATCH --job-name=Y2C3N3_RTSC
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=24
#SBATCH --cpus-per-task=1
#SBATCH --mem=192G
#SBATCH --time=36:00:00
#SBATCH --output=Y2C3N3_RTSC.out
#SBATCH --error=Y2C3N3_RTSC.err

# Load Environment (Adjust for Jules cluster)
module load intel-oneapi-compilers/2022.0.1
module load intel-oneapi-mpi/2021.5.0
module load qe/7.2

# Variables
OUTDIR="./out/"
TMPDIR="./tmp/"
PREFIX="Y2C3N3"
QE_PARA="mpirun -np 48 pw.x -nk 4 -nb 4 -ni 1"
PH_PARA="mpirun -np 48 ph.x -ni 1"

mkdir -p $OUTDIR $TMPDIR

echo "Starting RTSC Validation Pipeline for $PREFIX"

# 1. SCF Calculation (Structural Integrity)
echo "Running SCF..."
$QE_PARA -in scf.in > scf.out
if [ $? -ne 0 ]; then echo "SCF FAILED"; exit 1; fi

# 2. NSCF Calculation (Dense Mesh for EPC)
echo "Running NSCF..."
$QE_PARA -in nscf.in > nscf.out
if [ $? -ne 0 ]; then echo "NSCF FAILED"; exit 1; fi

# 3. Phonon Calculation (Stability Audit)
echo "Running Phonons..."
$PH_PARA -in ph.in > ph.out
if [ $? -ne 0 ]; then echo "PHONON FAILED"; exit 1; fi

# 4. Q2R & Matdyn (Band Interpolation)
echo "Running Q2R and Matdyn..."
mpirun -np 1 q2r.x < q2r.in > q2r.out
mpirun -np 1 matdyn.x < matdyn.in > matdyn.out

# 5. Stability Audit Script
python check_stability.py matdyn.freq.gp

# 6. EPC Calculation (The Final Verdict)
echo "Running EPC..."
$PH_PARA -in elph.in > elph.out

echo "Validation Pipeline Completed."
