%% glmm_nogo_accuracy_trialnum_reward_switch.m
% Trial-level mixed-effects logistic regression on NoGo trials only
%
% Model:
%   accuracy ~ trial_num_c * reward_block * switch_block + (1|subject_eeg)
%
% Outcome:
%   accuracy = 1 for correct NoGo withholding
%   accuracy = 0 for NoGo error
%
% Predictors:
%   trial_num_c   = centered trial position within block
%   reward_block  = rewarded / unrewarded
%   switch_block  = switch / repeat
%
% Requires:
%   ./average_r/switch_*_beh_eeg_data.mat
% Each file must contain:
%   eeg_beh_data_final_monster

clear; clc;

%% ---------------- USER SETTINGS ----------------
EPOCH_START_TIME = -200;
DATA_DIR = fullfile(pwd, 'average_r');
OUT_DIR  = fullfile(pwd, 'analysis');
PATTERN  = 'switch_*_beh_eeg_data.mat';

CENTER_TRIAL_NUM = true;   % recommended
DROP_NONE = true;          % drop condition_eeg == 'none'
% ------------------------------------------------

if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

files = dir(fullfile(DATA_DIR, PATTERN));
assert(~isempty(files), "No files found: %s", fullfile(DATA_DIR, PATTERN));

neededCols = {'Time','subject_eeg','trial_type_eeg','accuracy_eeg', ...
              'reward_eeg','condition_eeg','block_trial_eeg'};

%% Step 1: Build one row per trial across all subjects
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

    % Create trial UID from epoch starts
    T.trial_uid = cumsum(T.Time == EPOCH_START_TIME);

    % Keep one row per trial
    Tsmall = T(:, {'subject_eeg','trial_uid','trial_type_eeg','accuracy_eeg', ...
                   'reward_eeg','condition_eeg','block_trial_eeg'});
    [~, ia] = unique(Tsmall.trial_uid, 'stable');
    Ttrial = Tsmall(ia, :);

    all_trials = [all_trials; Ttrial]; %#ok<AGROW>
end

fprintf('\nBuilt trial-level dataset: %d trials\n', height(all_trials));

%% Step 2: Keep NoGo trials only
T = all_trials;
T = T(T.trial_type_eeg == 1, :);

fprintf('Kept NoGo trials only: %d trials\n', height(T));

%% Step 3: Recode predictors
% reward
r = string(T.reward_eeg);
T.reward_block = strings(height(T),1);
T.reward_block(r == "rewarded")   = "yes";
T.reward_block(r == "unrewarded") = "no";

% switch
c = string(T.condition_eeg);
T.switch_block = strings(height(T),1);
T.switch_block(c == "switch") = "yes";
T.switch_block(c == "repeat") = "no";

% trial number within block
T.trial_num = double(T.block_trial_eeg);

%% Step 4: Minimal cleaning
bad_acc   = isnan(T.accuracy_eeg);
bad_trial = isnan(T.trial_num);
bad_rwd   = ~(T.reward_block == "yes" | T.reward_block == "no");
bad_sw    = ~(T.switch_block == "yes" | T.switch_block == "no");
bad_none  = (c == "none");

toDrop = bad_acc | bad_trial | bad_rwd | bad_sw | (DROP_NONE & bad_none);

if any(toDrop)
    if DROP_NONE
        extra_msg = " or condition=='none'";
    else
        extra_msg = "";
    end
    fprintf('Dropping %d/%d NoGo trials (missing/invalid fields%s)\n', ...
        sum(toDrop), height(T), extra_msg);
end

T = T(~toDrop, :);

%% Step 5: Build model table
Tmodel = table();
Tmodel.subject_eeg = categorical(string(T.subject_eeg));
Tmodel.trial_uid   = T.trial_uid;
Tmodel.accuracy    = double(T.accuracy_eeg);   % 1 = correct NoGo, 0 = error
Tmodel.trial_num   = double(T.trial_num);

if CENTER_TRIAL_NUM
    Tmodel.trial_num_c = Tmodel.trial_num - mean(Tmodel.trial_num, 'omitnan');
    trial_var = 'trial_num_c';
else
    trial_var = 'trial_num';
end

Tmodel.reward_block = categorical(string(T.reward_block), ["no","yes"]); % ref = no
Tmodel.switch_block = categorical(string(T.switch_block), ["no","yes"]); % ref = no

%% ============================================================
% Exclude Subject 8 for consistency with behavioral analysis
%% ============================================================

Tmodel = Tmodel(string(Tmodel.subject_eeg) ~= "8", :);

% Remove unused categorical subject level
Tmodel.subject_eeg = removecats(Tmodel.subject_eeg);

fprintf('\nAfter excluding Subject 8:\n');
fprintf('Modeling dataset size: %d NoGo trials, %d subjects\n', ...
    height(Tmodel), numel(categories(Tmodel.subject_eeg)));

%% Save modeled dataset
outCSV = fullfile(OUT_DIR, 'triallevel_glmm_nogo_dataset.csv');
writetable(Tmodel, outCSV);
fprintf('Saved: %s\n', outCSV);

%% Step 6: Fit GLMM
formula = sprintf('accuracy ~ %s*reward_block*switch_block + (1|subject_eeg)', trial_var);

glme_nogo = fitglme(Tmodel, formula, ...
    'Distribution', 'Binomial', ...
    'Link', 'logit');

fprintf('\n===== NoGo GLME Model: %s =====\n', formula);
disp(glme_nogo);

fprintf('\nANOVA (marginal tests):\n');
disp(anova(glme_nogo));

%% Step 7: Export fixed effects and save model
try
    coefTable = dataset2table(glme_nogo.Coefficients);
catch
    coefObj = glme_nogo.Coefficients;

    if istable(coefObj)
        coefTable = coefObj;
    elseif isstruct(coefObj)
        coefTable = struct2table(coefObj(:));
    else
        coefTable = table( ...
            string(glme_nogo.CoefficientNames(:)), ...
            glme_nogo.fixedEffects(:), ...
            'VariableNames', {'Name','Estimate'});
    end
end

outCoefCSV = fullfile(OUT_DIR, 'glme_nogo_trialnum_reward_switch_fixed_effects.csv');
writetable(coefTable, outCoefCSV);
fprintf('\nSaved fixed effects: %s\n', outCoefCSV);

outMAT = fullfile(OUT_DIR, 'glme_nogo_trialnum_reward_switch.mat');
save(outMAT, 'glme_nogo', 'Tmodel', 'formula');
fprintf('Saved model + data: %s\n', outMAT);