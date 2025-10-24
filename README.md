# Neural Representation of Premature Heartbeats

[![License](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020a+-orange.svg)](https://www.mathworks.com/products/matlab.html)

The repository contains the code that accompanies this publication: [![DOI](https://img.shields.io/badge/DOI-10.1162%2FIMAG.a.30-blue)](https://www.biorxiv.org/content/10.1101/2024.09.06.610728v1)

## Overview

A regular and continuous heartbeat is essential for survival and is therefore closely
monitored by the brain. Most people occasionally experience a temporary “stuttering”
of the heartbeat, known as a premature contraction (PC), which can
originate in the atrium (PAC) or the ventricle (PVC). Very little is known about
how the brain responds to PCs. We analysed data from simultaneously recorded
cardiac (electrocardiogram - ECG) and neural (electroencephalography - EEG)
activity during 3065 PCs in 103 participants (51 with PAC, 52 with PVC) and
a matched control group. This repository contains the underlying code for analysing this data. 

## Key methods

- preprocessing the data
- HEP analysis
- Source Space analysis
- Control Analysis
  - Controlling for CFA (Correlation Analysis)
  - Controlling for T-Wave Amplitude
  - Control Group Analysis
 
## Requirements

## Software Dependencies

- **MATLAB** 
  - EEGLAB (tested with 2021.1)
    - erplab 
    - HEPLAB 
  - FieldTrip (tested with 20220422)
  - Boundedline
  - Inpaint Nans
- **Python**
  - `jupyter-notebook`

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

**Keywords:** Heartbeat Evoked Potential, Predictive Coding, Prediction Error, Premature Contraction, Interoception, EEG, ECG, Heart-Brain Coupling
