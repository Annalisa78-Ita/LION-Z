#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# LION-Z = Lateralization Index via bOotstrap Normalization on Z map - version 1.0
###############################################################################
# Bootstrap voxel-wise (Bernoulli subsampling)
# LInew = (L - R) / max(L, R)  — Seghier 2019
###############################################################################

usage() {
cat << EOF
Usage: ./lionz.sh -z <Zmap.nii> -m <mask.nii> [options]

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
EOF

echo "HINT: For maps derived from MELODIC_ICA, LION-Z is developed and tailored for this type of map."
exit 0
}

# ---------------- INPUT & CHECK -------------------------

NBOOT=500
MIN_THR=0.10
MAX_THR=0.60
STEP_THR=0.05
PBOOT=0.8
MINVOX=10
SEED=""

while getopts ":z:m:b:i:s:p:r:v:q:h" opt; do
  case $opt in
    z) ZMAP="$OPTARG" ;;
    m) LANG_MASK="$OPTARG" ;;
    b) NBOOT="$OPTARG" ;;
    i) MIN_THR="$OPTARG" ;;
    s) MAX_THR="$OPTARG" ;;
    p) STEP_THR="$OPTARG" ;;
    r) PBOOT="$OPTARG" ;;
    v) MINVOX="$OPTARG" ;;
    q) SEED="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [ -z "${ZMAP:-}" ] || [ -z "${LANG_MASK:-}" ]; then
    echo "ERROR: Z-map and mask are required."
    usage
fi

# ---------------- Random SEED ----------------

if [ -z "$SEED" ]; then
    SEED=$(python3 -c 'import secrets; print(secrets.randbits(64))')
else
    :
fi

# ---------------- OUTPUT Identification ----------------

BASE=$(basename "$ZMAP" .nii.gz)

mkdir -p results

RESULTS_FILE="results/results_${BASE}.txt"
RUNINFO_FILE="results/runinfo_${BASE}.txt"

DISTRIBUTION_FILE="results/distributionLInew_${BASE}.txt"

# ---------------- Temporary folder ----------------

TMPDIR="tmp_lionz"
mkdir -p "$TMPDIR"

trap 'rm -rf "$TMPDIR"' EXIT

# --------------------------------------------------

echo "LION-Z v1.0"
echo "Processing map: $BASE"
echo "Bootstrap iterations: $NBOOT"
echo "Bernoulli inclusion probability: $PBOOT"
echo "Relative threshold range: $MIN_THR–$MAX_THR (step: $STEP_THR)"
echo "Random seed: $SEED"

# ---------------- check dimensions ----------------

ZDIM=$(fslhd "$ZMAP" | awk '/^dim1/ {print $2,$3,$4}')
MDIM=$(fslhd "$LANG_MASK" | awk '/^dim1/ {print $2,$3,$4}')

if [ "$ZDIM" != "$MDIM" ]; then
    echo "ERROR: Z-map and mask dimensions do not match."
    exit 1
fi

# ---------------- Z THRESHOLDS ----------------

fslmaths "$ZMAP" -abs -mas "$LANG_MASK" "$TMPDIR/Z_abs_masked.nii.gz"

ZMAX=$(fslstats "$TMPDIR/Z_abs_masked.nii.gz" -R | awk '{print $2}')

# Generate absolute thresholds in a temporary file.
# The generated thresholds remain unchanged during bootstrap

THR_FILE="$TMPDIR/thresholds.txt"

> "$THR_FILE"

for t in $(LC_NUMERIC=C seq "$MIN_THR" "$STEP_THR" "$MAX_THR"); do

    awk -v thr="$t" -v zmax="$ZMAX" 'BEGIN {
        printf "%.6f\n", thr*zmax
    }' >> "$THR_FILE"

done

# ---------------- mask voxel base ----------------

fslmaths "$ZMAP" -abs -thr 0 -bin -mas "$LANG_MASK" \
    "$TMPDIR/mask_boot_base.nii.gz"

NVOX=$(fslstats "$TMPDIR/mask_boot_base.nii.gz" -V | awk '{print $1}')

echo "Number of voxels within language mask: $NVOX"

if [ "$NVOX" -eq 0 ]; then
    echo "ERROR: No voxels available within the language mask."
    exit 1
fi

# ------- hemispheric split & preprocessing Z ----------

NX=$(fslhd "$LANG_MASK" | awk '/^dim1/ {print $2}')
MID=$((NX / 2))

# Hemispheric left
fslmaths "$LANG_MASK" -roi "$MID" -1 0 -1 0 -1 0 -1 \
    "$TMPDIR/lang_L.nii.gz"

# Hemispheric right
fslmaths "$LANG_MASK" -roi 0 "$MID" 0 -1 0 -1 0 -1 \
    "$TMPDIR/lang_R.nii.gz"


fslmaths "$ZMAP" -abs -mas "$LANG_MASK" "$TMPDIR/Z_abs_masked.nii.gz"

fslmaths "$TMPDIR/Z_abs_masked.nii.gz" \
    -mas "$TMPDIR/lang_L.nii.gz" "$TMPDIR/Z_L.nii.gz"

fslmaths "$TMPDIR/Z_abs_masked.nii.gz" \
    -mas "$TMPDIR/lang_R.nii.gz" "$TMPDIR/Z_R.nii.gz"

# ---------------- run information ----------------

cat > "$RUNINFO_FILE" << EOF
LION-Z version: 1.0
Date: $(date)
Input map: $ZMAP
Mask: $LANG_MASK
Bootstrap: $NBOOT
Bernoulli probability: $PBOOT
Threshold range: $MIN_THR - $MAX_THR
Threshold step: $STEP_THR
Random seed: $SEED
FSL version: $(cat "$FSLDIR/etc/fslversion")
Python: $(python3 --version)
Minimum suprathreshold voxels per hemisphere: $MINVOX
EOF

# ---------------- CALL lionz-bootstrap ----------------

python3 lionz-bootstrap.py \
    "$TMPDIR/Z_L.nii.gz" \
    "$TMPDIR/Z_R.nii.gz" \
    "$THR_FILE" \
    "$NBOOT" \
    "$PBOOT" \
    "$MINVOX" \
    "$SEED" \
    "$ZMAX" \
    "$NVOX" \
    "$DISTRIBUTION_FILE"

# -----------------------------------------------------

rm -rf "$TMPDIR"
mv results.txt "$RESULTS_FILE"

# ---------------- LOAD RESULTS ----------------

LI_MEDIAN=$(awk -F': ' '/^Median LInew:/ {print $2}' "$RESULTS_FILE")

LI_ESI=$(awk -F': ' '/^95% Empirical Stability Interval \(ESI\):/ {print $2}' "$RESULTS_FILE")

LI_SD=$(awk -F': ' '/^Standard deviation \(SD\):/ {print $2}' "$RESULTS_FILE")

PERC_POS=$(awk -F': ' '/^Positive LInew iterations:/ {print $2}' "$RESULTS_FILE")

VALID_BOOT=$(awk -F': ' '/^Valid bootstrap iterations:/ {print $2}' "$RESULTS_FILE")

CLASSIFICATION=$(awk -F': ' '/^Lateralization classification:/ {print $2}' "$RESULTS_FILE")

# ---------------- Terminal OUTPUT ----------------

echo ""
echo "Median LInew: $LI_MEDIAN"
echo "95% ESI: $LI_ESI"
echo "SD: $LI_SD"
echo "Lateralization classification: $CLASSIFICATION"
echo "Positive LInew iterations: $PERC_POS"
echo "Valid bootstrap iterations: $VALID_BOOT"
echo ""
echo "Results saved: $RESULTS_FILE"
echo "Run information saved: $RUNINFO_FILE"

