# Neural Representation of Premature Heartbeats

[![License](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a+-orange.svg)](https://www.mathworks.com/products/matlab.html)

The repository contains the code that accompanies this publication: [![DOI](https://img.shields.io/badge/DOI-10.1101/2024.09.06.610728-blue)](https://www.biorxiv.org/content/10.1101/2024.09.06.610728v1)

## Overview

A regular and continuous heartbeat is essential for survival and is therefore closely monitored by the brain. Most people occasionally experience a temporary "stuttering" of the heartbeat, known as a **premature contraction (PC)**, which can originate in the atrium (**PAC** - Premature Atrial Contraction) or the ventricle (**PVC** - Premature Ventricular Contraction). 

Very little is known about how the brain responds to PCs. We analyzed data from simultaneously recorded cardiac (electrocardiogram - ECG) and neural (electroencephalography - EEG) activity during **3065 premature contractions** in **103 participants** (51 with PAC, 52 with PVC) and a matched control group. This repository contains the complete analysis pipeline code that accompanies our publication.

## Repository Structure

```
Heart_Brain_PC/
├── README.md                          # This file
├── main_processing.m                  # Main analysis pipeline
├── setup_project_config.m             # Central configuration file (template)
├── code/                              # Analysis scripts
│   ├── preprocessing/                 # Steps 1-4: Data preprocessing & ICA
│   ├── timedomain/                    # Steps 5-7: HEP time-domain analysis
│   ├── sourcespace/                   # Step 8: Source reconstruction
│   ├── controlanalysis/               # Steps 9-11: Control analyses
│   │   └── matching_PC2control.ipynb  # Python notebook for matching control group to PC group
│   ├── functions/                     # Helper functions
│   └── logfiles/                      # Error logs (not in git)
├── data/                              # Data directories (not in git)
│   ├── raw/                           # Raw EEG/ECG files
│   │   ├── PC/                        # PC group data
│   │   ├── control/                   # Control group data
│   │   ├── crop_marker/               # Crop marker files (optional)
│   │   └── event_marker/              # ECG event files with R-peaks (PC group only)
│   ├── ICA/                           # ICA-processed files
│   │   ├── no/                        # Non-ICA corrected data
│   │   │   ├── PC/
│   │   │   └── control/
│   │   ├── pre/                       # Pre-ICA data (for ICA computation)
│   │   │   ├── PC/
│   │   │   └── control/
│   │   └── post/                      # Post-ICA corrected data
│   │       ├── PC/
│   │       └── control/
│   ├── epochs/                        # Epoched data
│   │   ├── PC/                        # PC group epochs
│   │   └── control/                   # Control group epochs
│   ├── matching/                      # Data for matching control group to PC group
│   └── QA/                            # Quality assessment plots of ICA components and spectra
├── precomputed/                       # Precomputed templates
│   ├── cm17.mat                       # Colormap
│   ├── layout.mat                     # Channel layout
│   ├── neighbours.mat                 # Channel neighbors
│   ├── roi_labels_harvard_oxford.mat  # ROI labels
│   └── source_atlas_eloreta.mat       # Source space atlas
└── results/                           # Analysis outputs (not in git)
```

### What's in Git vs. What's Not

**Included in repository:**
- All MATLAB analysis scripts (`.m` files)
- Python matching notebook (`.ipynb`)
- Precomputed templates and configurations

**Excluded from repository** (see `.gitignore`):
- Raw EEG/ECG data files (`.set`, `.fdt`, `.vhdr`, `.vmrk`, `.eeg`)
- Processed data (`.mat` files in `data/` and root directory)
- Results and figures (in `results/` directory)
- Quality assessment plots (in `data/QA/`)
- Log files (in `code/logfiles/`)

---

## Analysis Pipeline

The analysis is organized in sequential steps. All steps are controlled through `main_processing.m` and configured via `setup_project_config.m`.

### Step 0: Subject Matching (Python)
**Script:** `code/controlanalysis/matching_PC2control.ipynb`

Match healthy control subjects to PC subjects based on:
- Age, BMI, blood pressure (when available)
- Sex (exact matching)
- controlling ECG quality (sinus rhythm, no pathologies)

**Method:** k-Nearest Neighbors with standardized features

### Steps 1-5: Preprocessing & Epoching (PC and Control Groups)

**Note:** All preprocessing steps (1-5) are performed for both PC and Control groups to ensure identical preprocessing pipelines.

#### Step 1: Initial Preprocessing
**Script:** `code/preprocessing/a_1_preprocessing.m`

**Processes:** Both PC and Control groups

- Load raw BrainVision EEG data (`.vhdr`, `.vmrk`, `.eeg`)
- Apply crop markers to remove unwanted segments
- Resample to 500 Hz
- Apply bandpass filters:
  - EEG: 0.5-20 Hz (analysis) or 1-20 Hz (ICA)
  - ECG: 0.5-45 Hz (preserves R-peak morphology)
- Remove line noise (50 Hz) and mark noisy segments
- Detect and interpolate flat channels
- Add channel locations

#### Step 2: Import/Detect R-peaks
**Scripts:** 
- `code/preprocessing/a_2a_import_rpeaks_PC.m` (PC group - external ECG files)
- `code/preprocessing/a_2b_detect_rpeaks_control.m` (Control group - internal detection from ECG channel)

**PC Group:** Import externally detected R-peak events and beat type labels (detected with CER-S):
- `N` = Normal beat
- `S` = Supraventricular (PAC)
- `V` = Ventricular (PVC)
- Beat positions relative to PC: `-4, -3, -2, -1, iPAC/iPVC, +1, +2, +3, +4`
- mark labels in noisy segments as `badECG`

**Control Group:** Detect R-peaks directly from the ECG channel using HEPLAB's detection algorithm.
- mark labels in noisy segments as `badECG`

#### Step 3: ICA Cleaning
**Script:** `code/preprocessing/a_3_run_ICA.m`

**Processes:** Both PC and Control groups

- Run extended Infomax ICA on epoched data
- Automatically identify and remove artifact components:
  - ECG artifacts (correlation with ECG template)
  - Eye movement artifacts
  - Muscle artifacts
  - Line noise
  - Channel noise

#### Step 4: Reintegrate ECG Channel
**Script:** `code/preprocessing/a_4_reintegrate_ecg.m`

**Processes:** Both PC and Control groups

Reintegrate the ECG channel into the EEG data.

#### Step 5: Epoch Data
**Script:** `code/timedomain/a_5_epoch_timedomain.m`

**Processes:** Both PC and Control groups

- Epoch EEG data around R-peaks: -200 to +800 ms
- Subtract averaged iN from every PC-1 beat in continuous data for a clean PC beat
- Apply baseline correction: -150 to -50 ms before reference condition
- Average within beat types
- Save epoched data for statistical analysis

**Outputs:** 
- PC group: `allsubj_timedomain_PC_[baseline]_[ica].mat`
- Control group: `allsubj_timedomain_control_[baseline]_[ica].mat`
  - `[baseline]`: `no`, `ref`, or `int` (baseline correction option)
  - `[ica]`: `no` or `post` (ICA correction status)

### Steps 6-7: Time-Domain Statistics

#### Step 6: EEG Statistics
**Script:** `code/timedomain/a_6_stats_timedomain_EEG.m`

Cluster-based permutation tests (FieldTrip) for:
- **Within-group comparisons:** e.g., PC+1 vs PC-3, PC vs Normal (iN)
- **Between-group comparisons:** PAC vs PVC
- **Control group comparisons:** PC vs Control (Normal beats)
- **T-wave matched comparisons:** PC+1 vs matched T-wave PC-3

#### Step 7: ECG Statistics
**Script:** `code/timedomain/a_7_stats_timedomain_ECG.m`

Same statistical framework as Step 6, but for ECG channel to verify cardiac changes.

### Steps 8: Source Space Analysis

#### Step 8a-b: Source Reconstruction (eLORETA)
**Script:** `code/sourcespace/a_8_source_analysis.m`

- Forward model: eLORETA with regularization (0.5, 0.05, 0.001)
- Aggregate voxels into Harvard-Oxford cortical ROIs (AVG, AVG-SF)
- Statistical comparison between beat types
- Visualization on cortical surface

**Key contrasts:**
- PVC: PVC vs PVC-3 (time window: 220-350 ms)
- PAC+PVC: PC+1 vs PC-3 (time window: 130-200 ms)

#### Step 8c: Time-Resolved Source Analysis
**Script:** `code/sourcespace/a_8c_source_analysis_timewise.m`

Sliding time window analysis to compare PC+1 with PC-3.

### Steps 9-11: Control Analyses

#### Step 9-10: Cardiac Field Artifact (CFA) Correlation
**Scripts:** 
- `code/controlanalysis/a_9_cfa_cluster_correlation.m` (cluster-based)
- `code/controlanalysis/a_10_cfa_timewindow_correlation.m` (time-window averaged)

Control for potential cardiac field artifacts by correlating:
- ΔHEP with ΔECG
- highest HEP amplitude with highest ECG amplitude

**Method:** Spearman correlation with permutation testing

#### Step 11: T-Wave Amplitude Matching
**Script:** `code/controlanalysis/a_11_twave_control.m`

Match PC+1 epochs with Normal/PC-3 epochs based on T-wave amplitude to control for T-wave morphology effects on HEP.

### Step 12: Between-Group Comparison - PC vs Control
**Scripts:** `code/timedomain/a_6_stats_timedomain_EEG.m`, `code/timedomain/a_7_stats_timedomain_ECG.m`

Compare isolated normal (iN) beats between PC and Control groups to identify baseline differences in brain-heart coupling.

**Note:** Control group undergoes the same preprocessing pipeline (Steps 1-5) as PC group to ensure comparable data quality. 

---

## Requirements
### Software Dependencies

#### MATLAB (R2020a or higher)
- **[EEGLAB](https://sccn.ucsd.edu/eeglab/)** (tested with 2021.1)
  - Plugin: `bva_io` (BrainVision file import)
  - Plugin: `erplab` (ERP analysis)
- **[HEPLAB](https://github.com/Heplab/HEPLAB)** (Heartbeat-evoked potential analysis)
- **[FieldTrip](https://www.fieldtriptoolbox.org/)** (tested with 20220422)
- **[Boundedline](https://github.com/kakearney/boundedline-pkg)** (Plotting)
- **[Inpaint_Nans](https://www.mathworks.com/matlabcentral/fileexchange/4551-inpaint_nans)** (Interpolation)
- **[Brewermap](https://github.com/DrosteEffect/BrewerMap)** (Colormaps)
- **[Tensor Toolbox](https://www.tensortoolbox.org/)** (tested with v3.6)
- **[METH Toolbox](https://github.com/guidonolte/METH)** (Source Reconstruction/eLORETA)

#### Python (3.7 or higher)
- `pandas`
- `numpy`
- `scikit-learn`
- `seaborn`
- `matplotlib`
- `jupyter`

Install Python dependencies:
```bash
pip install pandas numpy scikit-learn seaborn matplotlib jupyter
```

### Data Requirements

**Not included in repository** - must be obtained from original study:
- Raw EEG data in BrainVision format (`.vhdr`, `.vmrk`, `.eeg`)
- ECG event files with R-peak annotations for PC and regular beats
- Subject demographic data (for matching)
- Crop marker files (optional, for removing segments)

## Getting Started

### 1. Configure Paths

Edit `setup_project_config.m` to set your local paths:

```matlab
% Base paths
config.paths.base = '/path/to/Heart_Brain_PC/';

% External toolbox paths
config.paths.eeglab = '/path/to/eeglab2021.1/';
config.paths.heplab = '/path/to/HEPLAB/';
config.paths.fieldtrip = '/path/to/fieldtrip-20220422/';
% ... etc
```

### 2. Prepare Data Structure

Create the following directories and populate with raw data:
```
data/
├── raw/
│   ├── PC/              # PC group EEG files
│   ├── control/         # Control group EEG files
│   ├── crop_marker/     # Crop marker files (optional)
│   └── event_marker/    # ECG event files with R-peaks (PC group only)
└── matching/            # CSV files for subject matching
```

### 3. Run Subject Matching (Optional)

If creating a control group:
```bash
jupyter notebook code/controlanalysis/matching_PC2control.ipynb
```

### 4. Run Main Analysis Pipeline

Open MATLAB and run:
```matlab
% Open main script main_processing.m

% Run desired analysis steps
% For example, run steps 1-7 for full preprocessing and time-domain analysis

% Run the script
```

**Analysis steps can be run independently** - just comment/uncomment the relevant sections in `main_processing.m`.

### 5. Check Outputs

- **Preprocessed data:** `data/ICA/` and `data/epochs/`
- **Statistical results:** `results/`
- **Quality assessment:** `data/QA/`
- **Error logs:** `code/logfiles/`

---

## Configuration Guide

All analysis parameters are centralized in `setup_project_config.m`:

### Beat Type Labels

The pipeline tracks beat positions relative to premature contractions:
- `iN`: Isolated normal beat (control condition)
- `iPAC` / `iPVC`: The premature contraction itself
- `-4` to `-1`: Beats before PC
- `+1` to `+4`: Beats after PC

---

## Output Files

### Time-Domain Results
- e.g. `allsubj_timedomain_PC_ref_post.mat` - PC group epoched data
- e.g. `allsubj_timedomain_control_ref_post.mat` - Control group epoched data

### Statistical Results (in `results/`)
- EEG and ECG cluster statistics (FieldTrip structures)
- Topographic plots
- Source space visualizations
- Control analysis results

### Quality Assessment (in `data/QA/`)
- ICA component visualizations
- Spektra before and after ICA
- Artifact rejection summaries


## Citation

If you use this code in your research, please cite:

```bibtex
@article{reinfeldNeuralRepresentationsPrematureHeartbeats2024,
  title={Neural Representation of Premature Heartbeats},
  author={Reinfeld, P., Steinfath, T. P., Ku, P.-H., Nikulin, V. V., Neumann, J., & Villringer, A.},
  journal={bioRxiv},
  year={2024},
  doi={10.1101/2024.09.06.610728},
  url={https://www.biorxiv.org/content/10.1101/2024.09.06.610728v1}
}
```

---

## License

This project is licensed under the **Creative Commons Attribution 4.0 International License (CC BY 4.0)**.

You are free to:
- **Share** — copy and redistribute the material in any medium or format
- **Adapt** — remix, transform, and build upon the material for any purpose, even commercially

Under the following terms:
- **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made

See the [LICENSE](https://creativecommons.org/licenses/by/4.0/) for full details.

---

## Contact

For questions or issues:
- **Issues:** Open an issue on GitHub
- **Email:** Contact the corresponding author (see publication)

---

## Acknowledgments

This research was conducted at the Max Planck Institute for Human Cognitive and Brain Sciences, Leipzig, Germany. We thank all participants and the LIFE study team for providing the data.

---

**Keywords:** Heartbeat Evoked Potential, Predictive Coding, Prediction Error, Premature Contraction, Interoception, EEG, ECG, Heart-Brain Coupling
