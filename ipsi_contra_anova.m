%% c4b_contra_ipsi_followup_anova.m
% Follow-up ANOVAs for CONTRA and IPSI
% based on the same peak-centered window used for N2pc
%
% Design:
%   Condition (switch/repeat) × Reward (rewarded/unrewarded)
%
% DVs:
%   1) Contra amplitude
%   2) Ipsi amplitude
%
% Peak definition:
%   - first find N2pc negative peak within 200–400 ms
%   - then compute mean CONTRA and IPSI amplitude in ±50 ms around that peak

clear; clc;

%% ================================
% (1) Locate subject files
%% ================================
avgDir = fullfile(pwd, 'average_r');
files = dir(fullfile(avgDir, 'switch_*_beh_eeg_data.mat'));

if isempty(files)
    error('No subject files found in average_r/');
end

%% ================================
% (2) Analysis parameters
%% ================================
searchWin   = [200 400];   % peak search window (ms)
peakHalfWin = 50;          % ±50 ms around individual negative peak
blockRange  = [1 20];

USE_TRIALS = "go_correct";
% options:
%   "go_correct"
%   "nogo_correct"
%   "nogo_error"

%% ================================
% (3) Electrodes for N2pc
%% ================================
cluster_right = {'P8'};
cluster_left  = {'P7'};

cell_conditions = {'repeat','repeat','switch','switch'};
cell_rewards    = {'rewarded','unrewarded','rewarded','unrewarded'};

anova_all_contra = table();
anova_all_ipsi   = table();

%% ================================
% (4) Loop over subjects
%% ================================
for i = 1:numel(files)

    S = load(fullfile(files(i).folder, files(i).name));
    T = S.eeg_beh_data_final_monster;

    % ---- Trial UID
    T.trial_uid = cumsum(T.Time == -200);

    % ---- Electrode data
    right_data = mean(T{:, cluster_right}, 2, 'omitnan');
    left_data  = mean(T{:, cluster_left},  2, 'omitnan');

    % ---- Contra / ipsi
    contra = nan(height(T),1);
    ipsi   = nan(height(T),1);

    % side_gonogo_eeg == 0 -> target on LEFT
    contra(T.side_gonogo_eeg == 0) = right_data(T.side_gonogo_eeg == 0);
    ipsi(T.side_gonogo_eeg == 0)   = left_data(T.side_gonogo_eeg == 0);

    % side_gonogo_eeg == 1 -> target on RIGHT
    contra(T.side_gonogo_eeg == 1) = left_data(T.side_gonogo_eeg == 1);
    ipsi(T.side_gonogo_eeg == 1)   = right_data(T.side_gonogo_eeg == 1);

    T.contra = contra;
    T.ipsi   = ipsi;
    T.n2pc   = contra - ipsi;

    % ---- Trial-type filters
    go_correct   = (T.trial_type_eeg == 0) & (T.accuracy_eeg == 1);
    nogo_correct = (T.trial_type_eeg == 1) & (T.accuracy_eeg == 1);
    nogo_error   = (T.trial_type_eeg == 1) & (T.accuracy_eeg == 0);

    switch USE_TRIALS
        case "go_correct"
            base_idx = go_correct;
        case "nogo_correct"
            base_idx = nogo_correct;
        case "nogo_error"
            base_idx = nogo_error;
        otherwise
            error("Unknown USE_TRIALS option");
    end

    % ---- Inclusion mask
    idx = base_idx ...
        & T.block_trial_eeg >= blockRange(1) ...
        & T.block_trial_eeg <= blockRange(2) ...
        & ~strcmp(T.condition_eeg, 'none');

    Tin = T(idx, :);

    % ---- Subject x Condition x Reward waveform
    [G, cond, rew, time] = findgroups( ...
        string(Tin.condition_eeg), ...
        string(Tin.reward_eeg), ...
        Tin.Time);

    mean_n2pc   = splitapply(@mean, Tin.n2pc,   G);
    mean_contra = splitapply(@mean, Tin.contra, G);
    mean_ipsi   = splitapply(@mean, Tin.ipsi,   G);

    wave_tbl = table(cond, rew, time, mean_n2pc, mean_contra, mean_ipsi, ...
        'VariableNames', {'condition','reward','time','n2pc','contra','ipsi'});

    % ---- Extract peak-centered means for each cell
    subj_vals_n2pc   = nan(4,1);
    subj_vals_contra = nan(4,1);
    subj_vals_ipsi   = nan(4,1);
    peak_lat         = nan(4,1);

    for c = 1:4
        thisCond = cell_conditions{c};
        thisRew  = cell_rewards{c};

        widx = strcmp(wave_tbl.condition, thisCond) & ...
               strcmp(wave_tbl.reward, thisRew);

        w = wave_tbl(widx, :);

        if isempty(w)
            continue;
        end

        % sort by time
        [times_sorted, ord] = sort(w.time);
        n2pc_sorted   = w.n2pc(ord);
        contra_sorted = w.contra(ord);
        ipsi_sorted   = w.ipsi(ord);

        % search N2pc negative peak within 200-400 ms
        sidx = times_sorted >= searchWin(1) & times_sorted <= searchWin(2);

        if ~any(sidx)
            continue;
        end

        search_times = times_sorted(sidx);
        search_n2pc  = n2pc_sorted(sidx);

        [~, minIdx] = min(search_n2pc);
        this_peak_time = search_times(minIdx);
        peak_lat(c) = this_peak_time;

        % average in ±50 ms around the N2pc peak
        avg_idx = times_sorted >= (this_peak_time - peakHalfWin) & ...
                  times_sorted <= (this_peak_time + peakHalfWin);

        subj_vals_n2pc(c)   = mean(n2pc_sorted(avg_idx),   'omitnan');
        subj_vals_contra(c) = mean(contra_sorted(avg_idx), 'omitnan');
        subj_vals_ipsi(c)   = mean(ipsi_sorted(avg_idx),   'omitnan');
    end

    % ---- Save subject rows: CONTRA
    subj = repmat(string(T.subject_eeg(1)), 4, 1);

    subj_table_contra = table( ...
        subj, ...
        string(cell_conditions(:)), ...
        string(cell_rewards(:)), ...
        subj_vals_contra, ...
        peak_lat, ...
        'VariableNames', {'subject','condition','reward','contra','peak_latency_ms'});

    anova_all_contra = [anova_all_contra; subj_table_contra];

    % ---- Save subject rows: IPSI
    subj_table_ipsi = table( ...
        subj, ...
        string(cell_conditions(:)), ...
        string(cell_rewards(:)), ...
        subj_vals_ipsi, ...
        peak_lat, ...
        'VariableNames', {'subject','condition','reward','ipsi','peak_latency_ms'});

    anova_all_ipsi = [anova_all_ipsi; subj_table_ipsi];
end

%% ================================
% (5) Save long tables
%% ================================
outDir = fullfile(pwd, 'analysis');
if ~exist(outDir,'dir'); mkdir(outDir); end

save(fullfile(outDir, 'contra_peak_anova_long.mat'), 'anova_all_contra');
writetable(anova_all_contra, fullfile(outDir, 'contra_peak_anova_long.csv'));

save(fullfile(outDir, 'ipsi_peak_anova_long.mat'), 'anova_all_ipsi');
writetable(anova_all_ipsi, fullfile(outDir, 'ipsi_peak_anova_long.csv'));

disp('Saved long-format CONTRA and IPSI tables');

%% ================================
% (6) CONTRA: reshape to wide
%% ================================
anova_all_contra.condition = categorical(anova_all_contra.condition, {'repeat','switch'});
anova_all_contra.reward    = categorical(anova_all_contra.reward, {'rewarded','unrewarded'});

anova_all_contra.cond_reward = strcat( ...
    string(anova_all_contra.condition), "_", string(anova_all_contra.reward));

anova_wide_contra = unstack( ...
    anova_all_contra(:, {'subject','cond_reward','contra'}), ...
    'contra', 'cond_reward');

disp('Wide CONTRA table columns:');
disp(anova_wide_contra.Properties.VariableNames);

%% ================================
% (7) IPSI: reshape to wide
%% ================================
anova_all_ipsi.condition = categorical(anova_all_ipsi.condition, {'repeat','switch'});
anova_all_ipsi.reward    = categorical(anova_all_ipsi.reward, {'rewarded','unrewarded'});

anova_all_ipsi.cond_reward = strcat( ...
    string(anova_all_ipsi.condition), "_", string(anova_all_ipsi.reward));

anova_wide_ipsi = unstack( ...
    anova_all_ipsi(:, {'subject','cond_reward','ipsi'}), ...
    'ipsi', 'cond_reward');

disp('Wide IPSI table columns:');
disp(anova_wide_ipsi.Properties.VariableNames);

%% ================================
% (8) Define within-subject design
%% ================================
within = table( ...
    categorical({'repeat';'repeat';'switch';'switch'}), ...
    categorical({'rewarded';'unrewarded';'rewarded';'unrewarded'}), ...
    'VariableNames', {'Condition','Reward'});

%% ================================
% (9) CONTRA: run 2x2 RM ANOVA
%% ================================
rm_contra = fitrm( ...
    anova_wide_contra, ...
    'repeat_rewarded,repeat_unrewarded,switch_rewarded,switch_unrewarded ~ 1', ...
    'WithinDesign', within);

ranova_contra = ranova(rm_contra, 'WithinModel', 'Condition*Reward');

disp('================ CONTRA RM ANOVA RESULTS ================');
disp(ranova_contra);

save(fullfile(outDir, 'contra_peak_ranova.mat'), 'ranova_contra');
writetable(ranova_contra, fullfile(outDir, 'contra_peak_ranova.csv'));

%% ================================
% (10) CONTRA simple effects
%% ================================
mc_contra_reward_by_condition = multcompare(rm_contra, 'Reward', 'By', 'Condition');
disp('========= CONTRA: Reward within Condition =========');
disp(mc_contra_reward_by_condition);

mc_contra_condition_by_reward = multcompare(rm_contra, 'Condition', 'By', 'Reward');

save(fullfile(outDir, 'contra_peak_simple_effects.mat'), ...
    'mc_contra_reward_by_condition','mc_contra_condition_by_reward');

%% ================================
% (11) IPSI: run 2x2 RM ANOVA
%% ================================
rm_ipsi = fitrm( ...
    anova_wide_ipsi, ...
    'repeat_rewarded,repeat_unrewarded,switch_rewarded,switch_unrewarded ~ 1', ...
    'WithinDesign', within);

ranova_ipsi = ranova(rm_ipsi, 'WithinModel', 'Condition*Reward');

disp('================ IPSI RM ANOVA RESULTS ================');
disp(ranova_ipsi);

save(fullfile(outDir, 'ipsi_peak_ranova.mat'), 'ranova_ipsi');
writetable(ranova_ipsi, fullfile(outDir, 'ipsi_peak_ranova.csv'));

%% ================================
% (12) IPSI simple effects
%% ================================
mc_ipsi_reward_by_condition = multcompare(rm_ipsi, 'Reward', 'By', 'Condition');
disp('========= IPSI: Reward within Condition =========');
disp(mc_ipsi_reward_by_condition);

mc_ipsi_condition_by_reward = multcompare(rm_ipsi, 'Condition', 'By', 'Reward');

save(fullfile(outDir, 'ipsi_peak_simple_effects.mat'), ...
    'mc_ipsi_reward_by_condition','mc_ipsi_condition_by_reward');

disp('Done: CONTRA and IPSI follow-up ANOVAs complete.');