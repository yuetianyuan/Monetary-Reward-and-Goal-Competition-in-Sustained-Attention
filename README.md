# Monetary Reward and Goal Competition in Sustained Attention

An EEG study examining how monetary reward and goal competition (task-switching) shape behavioral performance and neural correlates of sustained attention. This repository contains the experimental task script and all analysis code for the MA thesis.

---

## Overview

Participants performed a continuous performance task (Go/NoGo) with two independent task sets that alternated across mini-blocks. Reward was manipulated block-by-block, and EEG was recorded throughout. The study targets three neural signatures:

- **N2pc** — lateralized attentional selection (200–400 ms)
- **P3** — decision/evaluation component (300–700 ms)
- **Theta oscillations** — frontal cognitive control
- **MVPA decoding** — multivariate classification of task state from EEG

---

## Repository Structure

```
.
├── EEG_goal_switching_CPT_EEG_v2_reward.m   # Experimental task (PsychToolBox)
├── all_trial_performance.m                  # Behavioral ANOVA summary
├── glmm_trialtype_reward_switch.m           # Trial-level GLMM (all trial types)
├── glmm_nogo_accuracy_trialnum_reward_switch.m  # GLMM on NoGo trials only
├── n2pc_3x2x2_anova_trialtype_condition_reward.m  # N2pc repeated-measures ANOVA
├── ipsi_contra_anova.m                      # Contralateral/ipsilateral follow-up
├── p3_analysis.m                            # P3 component analysis
├── across_suject_mvpa.m                     # MVPA feature extraction
├── plots/                                   # Generated figures
├── average_r/                               # Pre-processed EEG data (not tracked)
├── analysis/                                # Output tables and results
└── MACSS_MA_thesis.pdf                      # Full thesis document
```

---

## Experimental Design

| Parameter | Value |
|---|---|
| Total trials | 2,560 |
| Mini-blocks | 128 (20 trials each) |
| NoGo frequency | 20% |
| Task sets | 2 (e.g., odd/even numbers vs. consonant/vowel letters) |
| Reward condition | Binary (rewarded / unrewarded) per block |
| Stimulus lateralization | Left or right (for N2pc analysis) |
| EEG channels | 30 |

**Block structure:** Repeat blocks (same task set) and switch blocks (alternate task set) are randomized across participants. Reward blocks are interleaved independently.

### EEG Trigger Codes

| Code | Condition |
|---|---|
| 1–2 | Go, Task 1, Left/Right |
| 3–4 | NoGo, Task 1, Left/Right |
| 5–6 | Go, Task 2, Left/Right |
| 7–8 | NoGo, Task 2, Left/Right |
| 88 | Feedback onset |
| 200 | Block end |

---

## Requirements

- MATLAB (R2018b or later recommended)
- [PsychToolBox-3](http://psychtoolbox.org/) — for running the experimental task
- Eyelink Toolbox — for eye-tracking (optional; can be disabled)
- MATLAB Statistics and Machine Learning Toolbox — for ANOVA and GLMM

---

## Running the Experiment

1. Open MATLAB and navigate to the project directory.
2. Run `EEG_goal_switching_CPT_EEG_v2_reward.m`.
3. Fill in the input dialog:
   - **Subject number** — participant ID
   - **Condition** (1–4) — counterbalances task-category mapping
   - **Color** (1 or 2) — counterbalances cue color assignment (blue/red)
   - **Reward** (1 = reward block, 0 = no reward)
   - **Eye tracking** (1 = on, 0 = off)
   - **Output directory** — where raw data is saved
4. Raw data is saved as a `.mat` file with a timestamp.

---

## Running the Analyses

Pre-processed data must be placed in `./average_r/` as:
```
switch_<subject_id>_beh_eeg_data.mat
```
Each file should contain the table `eeg_beh_data_final_monster` with columns:
`Time`, `subject_eeg`, `trial_type_eeg`, `accuracy_eeg`, `reward_eeg`, `condition_eeg`, `block_trial_eeg`, and one column per electrode (30 channels).

Run scripts individually in MATLAB:

```matlab
% Behavioral summary
all_trial_performance

% Trial-level mixed-effects models
glmm_trialtype_reward_switch
glmm_nogo_accuracy_trialnum_reward_switch

% ERP analyses
n2pc_3x2x2_anova_trialtype_condition_reward
ipsi_contra_anova
p3_analysis

% MVPA feature extraction
across_suject_mvpa
```

Outputs (tables, figures) are written to `./analysis/` and `./plots/`.

**Note:** Subject 8 is excluded from all analyses.

---

## Key Analysis Parameters

| Analysis | Electrodes | Time Window |
|---|---|---|
| N2pc | P7 (left), P8 (right) | 200–400 ms |
| P3 | Pz | 300–700 ms |
| MVPA | All 30 channels | 0–500 ms |

Peak amplitude is computed by averaging ±50 ms around the individual peak within each search window.

---

## Statistical Models

- **Repeated-measures ANOVA** — 2 (Reward) × 2 (Condition: repeat/switch) × 2 (Trial Type: Go/NoGo) on subject-level ERP amplitude means
- **GLMM (all trials)** — `accuracy ~ trial_type × reward × switch + (1|subject)`, logistic link
- **GLMM (NoGo only)** — `accuracy ~ trial_num_centered × reward × switch + (1|subject)`, logistic link
- **MVPA** — trial-level multivariate decoding (SVM/LDA) from 30-channel feature vectors

---

## Citation

For full methods, results, and discussion, see the thesis:

> Yuan, Yuetian. *Monetary Reward and Goal Competition in Sustained Attention*. MA Thesis, MACSS Program, 2025.

---

## Contact

**Yuetian Yuan** — [GitHub](https://github.com/yuetianyuan)
