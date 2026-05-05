%% c5_p3_2x2x2_anova_trialtype_condition_reward.m
% 2 × 2 × 2 repeated-measures ANOVA:
% TrialType (go, nogo)
% × Condition (repeat, switch)
% × Reward (rewarded, unrewarded)
%
% DV: P3 amplitude at Pz
%
% P3 definition:
%   - electrode: Pz
%   - positive peak searched within 300–700 ms
%   - mean amplitude computed in ±50 ms around individual peak
%
% Participants: 1–30

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

searchWin   = [300 700];
peakHalfWin = 50;
blockRange  = [1 20];

electrode = {'Pz'};

trialtype_levels = {'go','nogo'};
condition_levels = {'repeat','switch'};
reward_levels    = {'rewarded','unrewarded'};

anova_all = table();

%% ================================
% Loop over subjects
%% ================================

for subj = subjects_to_include

    fp = fullfile(avgDir, sprintf('switch_%d_beh_eeg_data.mat', subj));

    if ~exist(fp, 'file')
        warning('Missing subject %d', subj);
        continue
    end

    S = load(fp);
    T = S.eeg_beh_data_final_monster;

    %% TrialType
    T.trialtype = strings(height(T),1);
    T.trialtype(T.trial_type_eeg == 0) = "go";
    T.trialtype(T.trial_type_eeg == 1) = "nogo";

    %% Inclusion mask
    idx = T.block_trial_eeg >= blockRange(1) ...
        & T.block_trial_eeg <= blockRange(2) ...
        & ~strcmp(string(T.condition_eeg), 'none') ...
        & T.trialtype ~= "";

    Tin = T(idx,:);

    %% Extract Pz signal
    p3_signal = Tin{:, electrode};

    %% Group waveform
    [G, ttype, cond, rew, time] = findgroups( ...
        string(Tin.trialtype), ...
        string(Tin.condition_eeg), ...
        string(Tin.reward_eeg), ...
        Tin.Time);

    mean_wave = splitapply(@mean, p3_signal, G);

    wave_tbl = table(ttype, cond, rew, time, mean_wave, ...
        'VariableNames', {'trialtype','condition','reward','time','p3'});

    %% Extract peak per cell
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

                w = wave_tbl(widx,:);

                subj_val = NaN;
                peak_lat = NaN;

                if ~isempty(w)

                    [times_sorted, ord] = sort(w.time);
                    amps_sorted = w.p3(ord);

                    % Search POSITIVE peak
                    sidx = times_sorted >= searchWin(1) & ...
                           times_sorted <= searchWin(2);

                    if any(sidx)

                        search_times = times_sorted(sidx);
                        search_amps  = amps_sorted(sidx);

                        [~, maxIdx] = max(search_amps);
                        this_peak_time = search_times(maxIdx);
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
                    'VariableNames', {'subject','trialtype','condition','reward','p3','peak_latency_ms'});

                subj_rows = [subj_rows; tmp];

            end
        end
    end

    anova_all = [anova_all; subj_rows];

end

%% ================================
% Save long format
%% ================================

writetable(anova_all, fullfile(outDir, 'p3_long.csv'));

%% ================================
% Reshape to wide
%% ================================

anova_all.trialtype = categorical(anova_all.trialtype, {'go','nogo'});
anova_all.condition = categorical(anova_all.condition, {'repeat','switch'});
anova_all.reward    = categorical(anova_all.reward, {'rewarded','unrewarded'});

anova_all.cellname = strcat( ...
    string(anova_all.trialtype), "_", ...
    string(anova_all.condition), "_", ...
    string(anova_all.reward));

anova_wide = unstack( ...
    anova_all(:, {'subject','cellname','p3'}), ...
    'p3','cellname');

disp(anova_wide.Properties.VariableNames');

%% ================================
% Within design
%% ================================

within = table( ...
    categorical({'go';'go';'go';'go';'nogo';'nogo';'nogo';'nogo'}, {'go','nogo'}), ...
    categorical({'repeat';'repeat';'switch';'switch';'repeat';'repeat';'switch';'switch'}, {'repeat','switch'}), ...
    categorical({'rewarded';'unrewarded';'rewarded';'unrewarded';'rewarded';'unrewarded';'rewarded';'unrewarded'}, {'rewarded','unrewarded'}), ...
    'VariableNames', {'TrialType','Condition','Reward'});

%% ================================
% Run ANOVA
%% ================================

dvNames = anova_wide.Properties.VariableNames(2:end);
formula = [strjoin(dvNames, ',') ' ~ 1'];

rm = fitrm(anova_wide, formula, 'WithinDesign', within);
ranova_results = ranova(rm, 'WithinModel', 'TrialType*Condition*Reward');

disp('================ P3 2x2x2 RM ANOVA RESULTS ================');
disp(ranova_results);

writetable(ranova_results, fullfile(outDir, 'p3_ranova.csv'));

disp('Done: P3 analysis complete.');



%% Follow-up comparisons for P3

% TrialType effect within each Condition
mc_trialtype_by_condition = multcompare(rm, 'TrialType', 'By', 'Condition');
disp('========= TrialType within Condition =========');
disp(mc_trialtype_by_condition);

% TrialType effect within each Reward
mc_trialtype_by_reward = multcompare(rm, 'TrialType', 'By', 'Reward');
disp('========= TrialType within Reward =========');
disp(mc_trialtype_by_reward);
tely 
% Condition effect within each TrialType
mc_condition_by_trialtype = multcompare(rm, 'Condition', 'By', 'TrialType');
disp('========= Condition within TrialType =========');
disp(mc_condition_by_trialtype);

% Reward effect within each TrialType
mc_reward_by_trialtype = multcompare(rm, 'Reward', 'By', 'TrialType');
disp('========= Reward within TrialType =========');
disp(mc_reward_by_trialtype);

save(fullfile(outDir, 'p3_2x2x2_simple_effects.mat'), ...
    'mc_trialtype_by_condition', ...
    'mc_trialtype_by_reward', ...
    'mc_condition_by_trialtype', ...
    'mc_reward_by_trialtype');