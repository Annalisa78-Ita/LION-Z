#!/usr/bin/env python3

###############################################################################
# Bootstrap voxel-wise for LION-Z
# Bernoulli subsampling
# Threshold saturation control
###############################################################################

import sys
import numpy as np
import nibabel as nib


if len(sys.argv) != 11:
    print(
        "Usage: lionz-bootstrap.py "
        "Z_L.nii.gz Z_R.nii.gz thresholds.txt "
        "NBOOT PBOOT MINVOX SEED ZMAX NVOX OUTPUT_FILE"
    )
    sys.exit(1)



ZL_img = sys.argv[1]
ZR_img = sys.argv[2]
THR_file = sys.argv[3]
NBOOT = int(sys.argv[4])
PBOOT = float(sys.argv[5])
MINVOX = int(sys.argv[6])
SEED = int(sys.argv[7])
ZMAX = float(sys.argv[8])
NVOX = int(sys.argv[9])
OUTPUT_FILE = sys.argv[10]


# ------------- Load data --------------------------

ZL = nib.load(ZL_img).get_fdata().ravel()
ZR = nib.load(ZR_img).get_fdata().ravel()

# Retain masked positive ICA values

ZL = ZL[ZL > 0]
ZR = ZR[ZR > 0]

THR = np.sort(np.loadtxt(THR_file))


# --------- Random seed generator ----------------
rng = np.random.default_rng(SEED)

LI = []
N_THR_USED = []

VALID_BOOT = 0


# --------------- Bootstrap --------------------

for _ in range(NBOOT):

    # Bernoulli voxel-wise subsampling

    selL = rng.random(ZL.size) < PBOOT
    selR = rng.random(ZR.size) < PBOOT

    zL = ZL[selL]
    zR = ZR[selR]

    li_thr = []
    thr_counter = 0

    # Progressive threshold exploration

    for t in THR:

        maskL = zL >= t
        maskR = zR >= t

        voxL = np.sum(maskL)
        voxR = np.sum(maskR)

        # Saturation control

        if voxL < MINVOX or voxR < MINVOX:
            break

        L = zL[maskL].sum()
        R = zR[maskR].sum()

        if max(L, R) == 0:
            continue

        li = (L - R) / max(L, R)

        li_thr.append(li)
        thr_counter += 1

    # Store bootstrap result

    if li_thr:

        LI.append(np.mean(li_thr))
        N_THR_USED.append(thr_counter)
        VALID_BOOT += 1


LI = np.asarray(LI)
N_THR_USED = np.asarray(N_THR_USED)


# ------------------ Summary -----------------------

LI_MEDIAN = np.median(LI)
LI_SD = np.std(LI)

CI_LOW, CI_HIGH = np.percentile(LI, [2.5, 97.5])


if LI_MEDIAN > 0.2:
    CLASSIFICATION = "Leftward lateralization"

elif LI_MEDIAN < -0.2:
    CLASSIFICATION = "Rightward lateralization"

else:
    CLASSIFICATION = "Bilateral configuration"

PERC_POS = np.mean(LI > 0) * 100

N_VALID = len(LI)

MEAN_THR_USED = np.mean(N_THR_USED)
MEDIAN_THR_USED = np.median(N_THR_USED)

# Round the mean number of thresholds to the nearest integer.

MEAN_THR_USED_ROUNDED = int(np.floor(MEAN_THR_USED + 0.5))


# ------------ RESULTS --------------------------

with open("results.txt", "w") as f:

    f.write("LION-Z Results\n")

    f.write(f"Median LInew: {LI_MEDIAN:.4f}\n")

    f.write(f"Lateralization classification: {CLASSIFICATION}\n")

    f.write(
        f"95% Empirical Stability Interval (ESI): "
        f"{CI_LOW:.4f} - {CI_HIGH:.4f}\n"
    )

    f.write(f"Standard deviation (SD): {LI_SD:.4f}\n")

    f.write(f"Positive LInew iterations: {PERC_POS:.2f}%\n")

    f.write(f"Valid bootstrap iterations: {N_VALID}/{NBOOT}\n")

    f.write(
        f"Number of voxels within language mask: {NVOX}\n"
    )

    f.write(
        f"Mean number of thresholds used: "
        f"{MEAN_THR_USED_ROUNDED}\n"
    )

    f.write(
        f"Absolute Zmax within the masked map: {ZMAX:.4f}\n"
    )

np.savetxt(
    OUTPUT_FILE,
    LI,
    fmt="%.8f"
)

