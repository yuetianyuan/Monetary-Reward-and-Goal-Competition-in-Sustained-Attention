%% c4_n2pc_2x2x2_anova_trialtype_condition_reward.m
% 2 × 2 × 2 repeated-measures ANOVA:
% TrialType (go, nogo)
% × Condition (repeat, switch)
% × Reward (rewarded, unrewarded)
%
% DV: N2pc amplitude
%
% N2pc definition:
%   - measured at P7/P8
%   - contra minus ipsi
%   - negative peak searched within 200–400 ms
%   - mean amplitude computed in ±50 ms around the individual negative peak
%
% Participants:
%   - Subjects 1–30
%
% Interpretation:
%   More negative N2pc = stronger lateralized attentional selection

clear; clc; close all;

%% ================================
% Settings
%% ================================

avgDir = fullfile(pwd, 'average_r');
outDir = fullfile(pwd, 'analysis');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

subjects_to_include = setdiff(1:30, 8);

searchWin   = [200 400];
peakHalfWin = 50;
blockRange  = [1 20];

cluster_right = {'P8'};
cluster_left  = {'P7'};

trialtype_levels = {'go','nogo'};
condition_levels = {'repeat','switch'};
reward_levels    = {'rewarded','unrewarded'};

anova_all = table();

%% ================================
% Build subject-level N2pc table
%% ================================

for subj = subjects_to_include

    fp = fullfile(avgDir, sprintf('switch_%d_beh_eeg_data.mat', subj));

    if ~exist(fp, 'file')
        warning('File not found: %s. Skipping subject %d.', fp, subj);
        continue
    end

    S = load(fp);

    if ~isfield(S, 'eeg_beh_data_final_monster')
        warning('Missing eeg_beh_data_final_monster for subject %d. Skipping.', subj);
        continue
    end

    T = S.eeg_beh_data_final_monster;

    T.trial_uid = cumsum(T.Time == -200);

    right_data = mean(T{:, cluster_right}, 2, 'omitnan');
    left_data  = mean(T{:, cluster_left},  2, 'omitnan');

    contra = nan(height(T), 1);
    ipsi   = nan(height(T), 1);

    contra(T.side_gonogo_eeg == 0) = right_data(T.side_gonogo_eeg == 0);
    ipsi(T.side_gonogo_eeg == 0)   = left_data(T.side_gonogo_eeg == 0);

    contra(T.side_gonogo_eeg == 1) = left_data(T.side_gonogo_eeg == 1);
    ipsi(T.side_gonogo_eeg == 1)   = right_data(T.side_gonogo_eeg == 1);

    T.n2pc = contra - ipsi;

    T.trialtype = strings(height(T), 1);
    T.trialtype(T.trial_type_eeg == 0) = "go";
    T.trialtype(T.trial_type_eeg == 1) = "nogo";

    idx = T.block_trial_eeg >= blockRange(1) ...
        & T.block_trial_eeg <= blockRange(2) ...
        & ~strcmp(string(T.condition_eeg), 'none') ...
        & T.trialtype ~= "";

    Tin = T(idx, :);

    [G, ttype, cond, rew, time] = findgroups( ...
        string(Tin.trialtype), ...
        string(Tin.condition_eeg), ...
        string(Tin.reward_eeg), ...
        Tin.Time);

    mean_wave = splitapply(@mean, Tin.n2pc, G);

    wave_tbl = table(ttype, cond, rew, time, mean_wave, ...
        'VariableNames', {'trialtype','condition','reward','time','n2pc'});

    subj_rows = table();

    for t = 1:numel(trialtype_levels)
        for c = 1:numel(condition_levels)
            for r = 1:numel(reward_levels)

                thisTrialType = trialtype_levels{t};
                thisCond      = condition_levels{c};
                thisRew       = reward_levels{r};

                widx = strcmp(wave_tbl.trialtype, thisTrialType) & ...
                       strcmp(wave_tbl.condition, thisCond) & ...
                       strcmp(wave_tbl.reward, thisRew);

                w = wave_tbl(widx, :);

                subj_val = NaN;
                peak_lat = NaN;

                if ~isempty(w)

                    [times_sorted, ord] = sort(w.time);
                    amps_sorted = w.n2pc(ord);

                    sidx = times_sorted >= searchWin(1) & ...
                           times_sorted <= searchWin(2);

                    if any(sidx)

                        search_times = times_sorted(sidx);
                        search_amps  = amps_sorted(sidx);

                        [~, minIdx] = min(search_amps);
                        this_peak_time = search_times(minIdx);
                        peak_lat = this_peak_time;

                        avg_idx = times_sorted >= (this_peak_time - peakHalfWin) & ...
                                  times_sorted <= (this_peak_time + peakHalfWin);

                        subj_val = mean(amps_sorted(avg_idx), 'omitnan');
                    end
                end

                tmp = table( ...
                    string(subj), ...
                    string(thisTrialType), ...
                    string(thisCond), ...
                    string(thisRew), ...
                    subj_val, ...
                    peak_lat, ...
                    'VariableNames', {'subject','trialtype','condition','reward','n2pc','peak_latency_ms'});

                subj_rows = [subj_rows; tmp];

            end
        end
    end

    anova_all = [anova_all; subj_rows];

end

%% ================================
% Save long-format table
%% ================================

save(fullfile(outDir, 'n2pc_go_nogo_condition_reward_long.mat'), 'anova_all');
writetable(anova_all, fullfile(outDir, 'n2pc_go_nogo_condition_reward_long.csv'));

disp('Saved long-format 2x2x2 N2pc table');
disp(head(anova_all));

%% ================================
% Categorical coding and wide format
%% ================================

anova_all.trialtype = categorical(anova_all.trialtype, {'go','nogo'});
anova_all.condition = categorical(anova_all.condition, {'repeat','switch'});
anova_all.reward    = categorical(anova_all.reward, {'rewarded','unrewarded'});

anova_all.cellname = strcat( ...
    string(anova_all.trialtype), "_", ...
    string(anova_all.condition), "_", ...
    string(anova_all.reward));

anova_wide = unstack( ...
    anova_all(:, {'subject','cellname','n2pc'}), ...
    'n2pc', 'cellname');

disp('Actual wide table columns:');
disp(anova_wide.Properties.VariableNames');

%% ================================
% Define within-subject design
%% ================================

within = table( ...
    categorical({ ...
        'go'; 'go'; 'go'; 'go'; ...
        'nogo'; 'nogo'; 'nogo'; 'nogo'}, ...
        {'go','nogo'}), ...
    categorical({ ...
        'repeat'; 'repeat'; 'switch'; 'switch'; ...
        'repeat'; 'repeat'; 'switch'; 'switch'}, ...
        {'repeat','switch'}), ...
    categorical({ ...
        'rewarded'; 'unrewarded'; 'rewarded'; 'unrewarded'; ...
        'rewarded'; 'unrewarded'; 'rewarded'; 'unrewarded'}, ...
        {'rewarded','unrewarded'}), ...
    'VariableNames', {'TrialType','Condition','Reward'});

%% ================================
% Run 2 × 2 × 2 RM ANOVA safely
%% ================================

dvNames = { ...
    'go_repeat_rewarded', ...
    'go_repeat_unrewarded', ...
    'go_switch_rewarded', ...
    'go_switch_unrewarded', ...
    'nogo_repeat_rewarded', ...
    'nogo_repeat_unrewarded', ...
    'nogo_switch_rewarded', ...
    'nogo_switch_unrewarded'};

missingVars = setdiff(dvNames, anova_wide.Properties.VariableNames);

if ~isempty(missingVars)
    disp("Missing variables from anova_wide:");
    disp(missingVars');
    disp("Actual variables are:");
    disp(anova_wide.Properties.VariableNames');
    error("fitrm stopped because formula variables do not match anova_wide columns.");
end

formula_rm = [strjoin(dvNames, ',') ' ~ 1'];

rm = fitrm(anova_wide, formula_rm, 'WithinDesign', within);

ranova_results = ranova(rm, 'WithinModel', 'TrialType*Condition*Reward');

disp('================ 2 x 2 x 2 N2pc RM ANOVA RESULTS ================');
disp(ranova_results);

save(fullfile(outDir, 'n2pc_go_nogo_condition_reward_ranova.mat'), 'ranova_results');
writetable(ranova_results, fullfile(outDir, 'n2pc_go_nogo_condition_reward_ranova.csv'));

%% ================================
% Simple effects / follow-up comparisons
%% ================================

mc_trialtype_by_condition = multcompare(rm, 'TrialType', 'By', 'Condition');
disp('========= TrialType within Condition =========');
disp(mc_trialtype_by_condition);

mc_trialtype_by_reward = multcompare(rm, 'TrialType', 'By', 'Reward');
disp('========= TrialType within Reward =========');
disp(mc_trialtype_by_reward);

mc_condition_by_trialtype = multcompare(rm, 'Condition', 'By', 'TrialType');
disp('========= Condition within TrialType =========');
disp(mc_condition_by_trialtype);

mc_reward_by_trialtype = multcompare(rm, 'Reward', 'By', 'TrialType');
disp('========= Reward within TrialType =========');
disp(mc_reward_by_trialtype);

save(fullfile(outDir, 'n2pc_go_nogo_condition_reward_simple_effects.mat'), ...
    'mc_trialtype_by_condition', ...
    'mc_trialtype_by_reward', ...
    'mc_condition_by_trialtype', ...
    'mc_reward_by_trialtype');

disp('Done: 2x2x2 N2pc ANOVA complete.');