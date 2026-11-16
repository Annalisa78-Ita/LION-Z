# LION-Z - version 1.0
## Overview

Lateralization Index via bOotstrap Normalization on Z Maps (LION-Z) is an automated pipeline for estimating hemispheric lateralization from functional neuroimaging Z-maps.

The tool combines voxel-wise Bernoulli bootstrap subsampling, relative threshold exploration, and Seghier's normalized lateralization index (LInew) to evaluate hemispheric lateralization while reducing sensitivity to voxel selection and threshold definition.

LION-Z was developed primarily for resting-state functional MRI maps derived from Independent Component Analysis (ICA), with a particular focus on language-network maps.

-----------------------------------------------

## Requirements and platform compatibility

LION-Z was developed and tested in the following environment:

- Operating system: Ubuntu 20.04.6 LTS
- FSL: 6.0.8
- Python: 3.9
- Python packages: NumPy and NiBabel

LION-Z requires Bash, FSL, Python, NumPy, and NiBabel.

- Linux: Ubuntu 20.04.6 LTS is the primary development and testing environment.
- macOS: Compatibility may be possible with a suitable FSL installation and the required Python dependencies.
- Windows: LION-Z may be run through Windows Subsystem for Linux (WSL 2) using Ubuntu, with FSL and the required Python dependencies installed within the Linux environment. Native Windows execution is not supported.

----------------------------------------------

## Input data

LION-Z requires two NIfTI images:

1. Z-map: a NIfTI image containing voxel-wise Z-scores, preferably derived from resting-state fMRI Independent Component Analysis (ICA).
2. Mask: a binary mask defining the voxels included in the analysis.

The input Z-map and mask must have matching spatial dimensions and spatial geometry, including voxel-to-world orientation and alignment.
The input Z-map and the mask must be placed in the same directory as the LION-Z executable scripts.

----------------------------------------------

## Usage

Run LION-Z from the directory containing `lionz.sh` and `lionz-bootstrap.py`:

Bash: 
./lionz.sh -z <Zmap.nii> -m <mask.nii> [options]

Required arguments:
  -z    Z-map input (NIfTI)
  -m    Binary mask input (NIfTI)

Optional arguments:
  -b    Number of bootstrap samples (default: 500)
  -i    Inferior threshold value (default: 0.10)
  -s    Superior threshold value (default: 0.60)
  -p    Step size for threshold (default: 0.05)
  -r    Bernoulli subsampling probability (default: 0.8)
  -v    Minimum suprathreshold voxels per hemisphere (default: 10)
  -q    Random seed (optional; randomly fixed seed for testing: 3920929963960219586)
  -h    Show this help and exit

-----------------------------------------------

## Output files

LION-Z creates a results/ directory containing the following files for each input map:

    distributionLInew_<map_name>.txt — Mean Linew across the N bootstrap
    results_<map_name>.txt — Main results
    runinfo_<map_name>.txt — Execution information

## Citation

If you use LION-Z in your research, please cite the associated publication once available.

LION-Z tool utilizies the lateralization index formulation proposed by Seghier (2019).
