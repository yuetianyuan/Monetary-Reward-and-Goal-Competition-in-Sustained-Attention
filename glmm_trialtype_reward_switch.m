%% glmm_trialtype_reward_switch_full.m
% Standalone script (no dependence on existing workspace variables)
%  model (trial-level mixed-effects logistic regression):
%   accuracy(1/0) ~ trial_type(go/nogo) * reward_block(yes/no) * switch_block(yes/no) + (1|subject_eeg)
%
% Requires files: ./average_r/switch_*_beh_eeg_data.mat
% Each file must contain: eeg_beh_data_final_monster (table) with columns:
%   Time, subject_eeg, trial_type_eeg, accuracy_eeg, reward_eeg,
%   condition_eeg, block_trial_eeg
%
% Output:
%   analysis/triallevel_glmm_full_dataset.csv
%   analysis/glme_trialtype_reward_switch_full.mat
%   analysis/glme_trialtype_reward_switch_fixed_effects.csv

clear; clc;

%% ---------------- USER SETTINGS ----------------
EPOCH_START_TIME = -200;       % epoch start marker in your data
DATA_DIR = fullfile(pwd, 'average_r');
OUT_DIR  = fullfile(pwd, 'analysis');
PATTERN  = 'switch_*_beh_eeg_data.mat';
% ------------------------------------------------

if ~exist(OUT_DIR,'dir'); mkdir(OUT_DIR); end

files = dir(fullfile(DATA_DIR, PATTERN));
assert(~isempty(files), "No files found: %s", fullfile(DATA_DIR, PATTERN));

neededCols = {'Time','subject_eeg','trial_type_eeg','accuracy_eeg','reward_eeg','condition_eeg','block_trial_eeg'};

%% Step 1: Build ONE ROW PER TRIAL across all subjects (minimal filtering)
all_trials = table();

for i = 1:numel(files)
    fp = fullfile(files(i).folder, files(i).name);
    S = load(fp);

    if ~isfield(S, 'eeg_beh_data_final_monster')
        error("Missing eeg_beh_data_final_monster in %s", files(i).name);
    end

    T = S.eeg_beh_data_final_monster;

    missing = setdiff(neededCols, T.Properties.VariableNames);
    if ~isempty(missing)
        error("Missing required columns in %s: %s", files(i).name, strjoin(missing, ', '));
    end

    % trial_uid via epoch starts
    T.trial_uid = cumsum(T.Time == EPOCH_START_TIME);

    % Collapse to one row per trial_uid (take first row of each trial)
    Tsmall = T(:, {'subject_eeg','trial_uid','trial_type_eeg','accuracy_eeg','reward_eeg','condition_eeg','block_trial_eeg'});
    [~, ia] = unique(Tsmall.trial_uid, 'stable');
    Ttrial = Tsmall(ia, :);

    all_trials = [all_trials; Ttrial]; %#ok<AGROW>
end

fprintf("\nBuilt trial-level dataset: %d trials\n", height(all_trials));

%% Step 2: Define variables for the model
% Outcome: accuracy already 1/0
T = all_trials;

% ---- trial_type(go/nogo) ----
% Based on your earlier script: trial_type_eeg == 1 means NoGo
T.trial_type = strings(height(T),1);
T.trial_type(T.trial_type_eeg == 1) = "nogo";
T.trial_type(T.trial_type_eeg ~= 1) = "go";

% ---- reward_block(yes/no) ----
% reward_eeg seems to be "rewarded"/"unrewarded" (string/cellstr)
r = string(T.reward_eeg);
T.reward_block = strings(height(T),1);
T.reward_block(r == "rewarded")   = "yes";
T.reward_block(r == "unrewarded") = "no";

% ---- switch_block(yes/no) ----
% condition_eeg seems to contain "switch"/"repeat" and sometimes "none"
c = string(T.condition_eeg);
T.switch_block = strings(height(T),1);
T.switch_block(c == "switch") = "yes";
T.switch_block(c ~= "switch") = "no";

% Minimal cleaning (still "don't filter too much", but drop truly unusable rows):
bad_acc = isnan(T.accuracy_eeg);
bad_rwd = ~(T.reward_block=="yes" | T.reward_block=="no");
bad_tt  = ~(T.trial_type=="go" | T.trial_type=="nogo");

% If you have condition == "none", switch_block becomes "no" above; that may be OK,
% but often "none" is a placeholder. If you want to KEEP them, set DROP_NONE=false.
DROP_NONE = true;
bad_none = (c == "none");

toDrop = bad_acc | bad_rwd | bad_tt | (DROP_NONE & bad_none);

if any(toDrop)
    if DROP_NONE
        extra_msg = " or condition=='none'";
    else
        extra_msg = "";
    end

    fprintf("\nDropping %d/%d trials (missing/invalid fields%s)\n", ...
        sum(toDrop), height(T), extra_msg);
end
T = T(~toDrop,:);

% Keep only the needed columns for modeling
Tmodel = table();
Tmodel.subject_eeg  = string(T.subject_eeg);
Tmodel.trial_uid    = T.trial_uid;
Tmodel.block_trial  = T.block_trial_eeg;
Tmodel.accuracy     = double(T.accuracy_eeg);

% Categorical coding with explicit reference levels
Tmodel.trial_type   = categorical(string(T.trial_type),  ["go","nogo"]);  % ref = go
Tmodel.reward_block = categorical(string(T.reward_block),["no","yes"]);   % ref = no
Tmodel.switch_block = categorical(string(T.switch_block),["no","yes"]);   % ref = no

% subject random intercept needs categorical/grouping
Tmodel.subject_eeg  = categorical(Tmodel.subject_eeg);

fprintf("\nModeling dataset size: %d trials, %d subjects\n", height(Tmodel), numel(categories(Tmodel.subject_eeg)));

%% ============================================================
% Exclude Subject 8 (consistent with behavioral analysis)
%% ============================================================

Tmodel = Tmodel(string(Tmodel.subject_eeg) ~= "8", :);

fprintf("\nAfter excluding Subject 8:\n");
fprintf("Modeling dataset size: %d trials, %d subjects\n", ...
    height(Tmodel), numel(categories(Tmodel.subject_eeg)));

% Save dataset you actually modeled
outCSV = fullfile(OUT_DIR, 'triallevel_glmm_full_dataset.csv');
writetable(Tmodel, outCSV);
fprintf("Saved: %s\n", outCSV);

%% Step 3: Fit GLMM
% accuracy is Bernoulli (0/1). fitglme expects numeric response for Binomial.
formula = 'accuracy ~ trial_type*reward_block*switch_block + (1|subject_eeg)';

glme_full = fitglme(Tmodel, formula, ...
    'Distribution','Binomial', 'Link','logit');

fprintf("\n===== GLME Model: %s =====\n", formula);
disp(glme_full);

fprintf("\nANOVA (marginal tests):\n");
disp(anova(glme_full));

%% Step 4: Export fixed effects + save model  (ROBUST)
coefObj = glme_full.Coefficients;

% Convert to table depending on type
if istable(coefObj)
    coefTable = coefObj;
elseif isa(coefObj,'dataset')
    coefTable = dataset2table(coefObj);
else
    % Fallback: try to force conversion
    coefTable = struct2table(coefObj);
end

outCoefCSV = fullfile(OUT_DIR, 'glme_trialtype_reward_switch_fixed_effects.csv');
writetable(coefTable, outCoefCSV);
fprintf("\nSaved fixed effects: %s\n", outCoefCSV);

outMAT = fullfile(OUT_DIR, 'glme_trialtype_reward_switch_full.mat');
save(outMAT, 'glme_full', 'Tmodel', 'formula');
fprintf("Saved model + data: %s\n", outMAT);