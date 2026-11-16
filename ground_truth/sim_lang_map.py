#!/usr/bin/env python3

import numpy as np
import nibabel as nib
import os


# PARAMETERS

shape = (91, 109, 91)

# Radiological orientation (compatible with FSL)
affine = np.array([
    [-2, 0, 0, 90],
    [0, 2, 0, -126],
    [0, 0, 2, -72],
    [0, 0, 0, 1]
])

output_dir = "sim_maps_blob"
os.makedirs(output_dir, exist_ok=True)

# Language seed centers (voxel coordinates)
seeds = {
    "Broca_Left":     np.array([70, 76, 37]),
    "Broca_Right":    np.array([18, 77, 37]),
    "Wernicke_Left":  np.array([74, 39, 44]),
    "Wernicke_Right": np.array([16, 42, 42]),
}

blob_peak = 30.0
blob_sigma_vox = 3.0
noise_std = 0.5


# SIMULATED LATERALIZATION CLASSES

simulation_classes = {
    "strong_left":    ("left", 1.0),
    "moderate_left":  ("left", 0.6),
    "weak_left":      ("left", 0.3),
    "bilateral":      (None,   0.0),
    "weak_right":     ("right", 0.3),
    "moderate_right": ("right", 0.6),
    "strong_right":   ("right", 1.0),
}


# FUNCTIONS

def create_gaussian_blob(shape, center_voxel, peak, sigma):

    grid = np.indices(shape).astype(float)
    dist2 = np.sum((grid - center_voxel[:, None, None, None])**2, axis=0)

    return peak * np.exp(-dist2 / (2 * sigma**2))


def simulate_zmap(shape, seeds, lateralization=None, delta_lat=0.0):

    np.random.seed()

    # Gaussian background noise
    zmap = np.random.normal(
        0,
        noise_std,
        size=shape
    ).astype(np.float32)

    blob_map = np.zeros(shape, dtype=np.float32)

    # Hemisphere intensities
    if lateralization == "left":

        L_int = blob_peak * (1 + delta_lat / 2)
        R_int = blob_peak * (1 - delta_lat / 2)

    elif lateralization == "right":

        R_int = blob_peak * (1 + delta_lat / 2)
        L_int = blob_peak * (1 - delta_lat / 2)

    else:

        L_int = blob_peak
        R_int = blob_peak

    for label, center in seeds.items():

        if "Left" in label:
            intensity = L_int
        else:
            intensity = R_int

        blob_map += create_gaussian_blob(
            shape,
            center,
            intensity,
            blob_sigma_vox
        )

    # Signal + noise
    zmap += blob_map

    # ICA-like positive Z values
    zmap = np.abs(zmap)

    return zmap


# SIMULATION

n_maps = 10

class_names = list(simulation_classes.keys())

ground_truth_file = os.path.join(
    output_dir,
    "simulation_ground_truth.txt"
)

with open(ground_truth_file, "w") as gt:

    gt.write("MapID\tFilename\tClass\n")

    for i in range(n_maps):

        # Random class
        sim_class = np.random.choice(class_names)

        lateralization, delta = simulation_classes[sim_class]

        zmap_data = simulate_zmap(
            shape,
            seeds,
            lateralization=lateralization,
            delta_lat=delta
        )

        filename = f"Zmap_sim_{i+1:02d}_{sim_class}.nii.gz"

        nib.save(
            nib.Nifti1Image(zmap_data, affine),
            os.path.join(output_dir, filename)
        )

        gt.write(
            f"{i+1:02d}\t{filename}\t{sim_class}\n"
        )

        print("------------------------------------------------")
        print(f"Saved: {filename}")
        print(f"Ground truth : {sim_class}")
        print(f"Hemisphere   : {lateralization}")
        print(f"Delta        : {delta:.1f}")

print("\n======================================")
print(f"{n_maps} simulated maps generated.")
print(f"Ground truth saved in:")
print(ground_truth_file)
