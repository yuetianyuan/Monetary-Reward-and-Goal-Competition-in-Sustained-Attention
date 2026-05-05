%% ============================================================
% Behavior ANOVA + Plot
% Exclude Subject 8 from main analysis
%% ============================================================

avgDir = fullfile(pwd, 'average_r');
files = dir(fullfile(avgDir, 'switch_*_beh_eeg_data.mat'));

anova_all = table();

for i = 1:numel(files)

    % Load subject file
    S = load(fullfile(files(i).folder, files(i).name));
    T = S.eeg_beh_data_final_monster;

    % Create unique trial id from epoch start
    T.trial_uid = cumsum(T.Time == -200);

    % Collapse to trial level
    Tsmall = T(:, {'subject_eeg','trial_uid','trial_type_eeg', ...
        'accuracy_eeg','reward_eeg','condition_eeg'});

    [~, ia] = unique(Tsmall.trial_uid, 'stable');
    Ttrial = Tsmall(ia, :);

    % Keep NoGo only + exclude condition none
    Tnogo = Ttrial(Ttrial.trial_type_eeg == 1 & ...
        ~strcmp(Ttrial.condition_eeg,'none'), :);

    % Compute NoGo error rate by condition x reward
    [G, cond, rew] = findgroups(string(Tnogo.condition_eeg), ...
        string(Tnogo.reward_eeg));

    errRate = splitapply(@mean, 1 - Tnogo.accuracy_eeg, G);

    subj = repmat(string(Tnogo.subject_eeg(1)), numel(errRate), 1);

    subj_table = table(subj, cond, rew, errRate, ...
        'VariableNames', {'subject','condition','reward','nogo_error_rate'});

    anova_all = [anova_all; subj_table];
end

%% Save full table before exclusion

outDir = fullfile(pwd, 'analysis');
if ~exist(outDir,'dir'); mkdir(outDir); end

writetable(anova_all, fullfile(outDir, 'behavior_anova_table_FULL_with_subject8.csv'));
save(fullfile(outDir, 'behavior_anova_table_FULL_with_subject8.mat'), 'anova_all');

disp("Saved full table with Subject 8 included");

%% ============================================================
% Exclude Subject 8 for main analysis
%% ============================================================

anova_clean = anova_all(string(anova_all.subject) ~= "8", :);

disp("Excluded Subject 8 from main analysis");
disp("Number of subjects included:");
disp(numel(unique(anova_clean.subject)));

%% Prepare variables

anova_clean.condition = categorical(anova_clean.condition, {'repeat','switch'});
anova_clean.reward    = categorical(anova_clean.reward, {'rewarded','unrewarded'});

anova_clean.cond_reward = strcat(string(anova_clean.condition), "_", ...
    string(anova_clean.reward));

% Save clean table
writetable(anova_clean, fullfile(outDir, 'behavior_anova_table_CLEAN_no_subject8.csv'));
save(fullfile(outDir, 'behavior_anova_table_CLEAN_no_subject8.mat'), 'anova_clean');

%% ============================================================
% Repeated-measures ANOVA
%% ============================================================

anova_long = anova_clean(:, {'subject','cond_reward','nogo_error_rate'});
anova_wide = unstack(anova_long, 'nogo_error_rate', 'cond_reward');

within = table( ...
    categorical({'repeat'; 'repeat'; 'switch'; 'switch'}), ...
    categorical({'rewarded'; 'unrewarded'; 'rewarded'; 'unrewarded'}), ...
    'VariableNames', {'Condition','Reward'});

rm = fitrm( ...
    anova_wide, ...
    'repeat_rewarded,repeat_unrewarded,switch_rewarded,switch_unrewarded ~ 1', ...
    'WithinDesign', within);

ranova_results = ranova(rm, 'WithinModel', 'Condition*Reward');

disp("===== RM ANOVA RESULTS WITHOUT SUBJECT 8 =====");
disp(ranova_results);

save(fullfile(outDir, 'ranova_results_CLEAN_no_subject8.mat'), 'ranova_results');
writetable(ranova_results, fullfile(outDir, 'ranova_results_CLEAN_no_subject8.csv'));

%% ============================================================
% Simple effects
%% ============================================================

mc_cond_by_rew = multcompare(rm, 'Condition', 'By', 'Reward');
mc_rew_by_cond = multcompare(rm, 'Reward', 'By', 'Condition');

disp("===== Simple effect of Condition within Reward =====");
disp(mc_cond_by_rew);

disp("===== Simple effect of Reward within Condition =====");
disp(mc_rew_by_cond);

writetable(mc_cond_by_rew, fullfile(outDir, 'simple_condition_by_reward_CLEAN.csv'));
writetable(mc_rew_by_cond, fullfile(outDir, 'simple_reward_by_condition_CLEAN.csv'));

%% ============================================================
% Descriptive statistics without Subject 8
%% ============================================================

[G, condition, reward] = findgroups(anova_clean.condition, anova_clean.reward);

M  = splitapply(@mean, anova_clean.nogo_error_rate, G);
SD = splitapply(@std,  anova_clean.nogo_error_rate, G);
N  = splitapply(@numel, anova_clean.nogo_error_rate, G);

desc_summary_clean = table(condition, reward, M, SD, N);

disp("===== Descriptives without Subject 8 =====");
disp(desc_summary_clean);

writetable(desc_summary_clean, fullfile(outDir, 'nogo_descriptives_CLEAN_no_subject8.csv'));

%% ============================================================
% Remove ALL points (including boxchart outliers)
%% ============================================================

close all;

figure('Color','w'); hold on;

b = boxchart(anova_clean.reward, anova_clean.nogo_error_rate, ...
    'GroupByColor', anova_clean.condition, ...
    'BoxWidth', 0.45, ...
    'LineWidth', 1.3);

% 🔥 KEY LINE: remove outlier markers
set(b, 'MarkerStyle', 'none');

xlabel('Reward Condition');
ylabel('No-Go Error Rate');

xticklabels({'Rewarded','Unrewarded'});

legend({'Repeat','Switch'}, ...
    'Location','northwest', ...
    'Box','off');

title('No-Go Error Rates by Reward and Task Condition');

ylim([0 0.6]);

set(gca, ...
    'FontSize', 13, ...
    'LineWidth', 1.3, ...
    'TickDir','out');

box off;
grid on;