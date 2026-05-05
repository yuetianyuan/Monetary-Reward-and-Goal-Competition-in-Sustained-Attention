%% ================================
% Efficient MVPA preprocessing
% DO NOT combine full EEG tables
% Extract trial-level features file by file
% ================================

clear; clc;

data_dir = '/Users/yuetianyuan/Desktop/RAW_EEG/average_r';
files = dir(fullfile(data_dir, 'switch_*_beh_eeg_data.mat'));

electrodes = {'Fp1','Fz','F3','F7','CP5','FC5','FC1','C3','PO3', ...
              'PO7','CP1','Pz','P3','P7','O1','Oz','O2','P4', ...
              'P8','PO8','CP2','Cz','C4','PO4','CP6','FC6', ...
              'FC2','F4','F8','Fp2'};

time_win = [0 500];

X = [];
y = [];
subj = [];
trial_info = table();

for f = 1:length(files)

    fprintf('Processing %s\n', files(f).name);

    S = load(fullfile(data_dir, files(f).name));
    T = S.eeg_beh_data_final_monster;

    token = regexp(files(f).name, 'switch_(\d+)_beh_eeg_data.mat', 'tokens');
    subject_id = str2double(token{1}{1});

    % trial id within this subject only
    T.trial_uid = cumsum(T.Time == -200);

    % keep only decoding window
    T_win = T(T.Time >= time_win(1) & T.Time <= time_win(2), :);

    trial_ids = unique(T_win.trial_uid);

    X_sub = [];
    y_sub = [];
    subj_sub = [];

    for i = 1:length(trial_ids)

        rows = T_win(T_win.trial_uid == trial_ids(i), :);

        if isempty(rows)
            continue
        end

        reward_label = string(rows.reward_eeg(1));

        if reward_label ~= "rewarded" && reward_label ~= "unrewarded"
            continue
        end

        feat = zeros(1, length(electrodes));

        for e = 1:length(electrodes)
            feat(e) = mean(rows.(electrodes{e}), 'omitnan');
        end

        X_sub = [X_sub; feat];

        if reward_label == "rewarded"
            y_sub = [y_sub; 1];
        else
            y_sub = [y_sub; 0];
        end

        subj_sub = [subj_sub; subject_id];
    end

    X = [X; X_sub];
    y = [y; y_sub];
    subj = [subj; subj_sub];

    clear S T T_win X_sub y_sub subj_sub rows
end

%% Clean
valid = all(~isnan(X), 2) & ~isnan(y);

X = X(valid, :);
y = y(valid);
subj = subj(valid);

fprintf('\nDone.\n');
fprintf('Trials used: %d\n', length(y));
fprintf('Rewarded: %d\n', sum(y == 1));
fprintf('Unrewarded: %d\n', sum(y == 0));
fprintf('Subjects: %d\n', numel(unique(subj)));

%% Save small MVPA-ready dataset
save(fullfile(data_dir, 'MVPA_reward_features_0_500ms.mat'), ...
    'X', 'y', 'subj', 'electrodes', 'time_win', '-v7.3');
%% ================================
% Decode reward vs unrewarded
% Excluding subject 8
% ================================

clear; clc;

data_dir = '/Users/yuetianyuan/Desktop/RAW_EEG/average_r';
load(fullfile(data_dir, 'MVPA_reward_features_0_500ms.mat'));

%% Exclude subject 8
exclude_sub = 8;

keep_idx = subj ~= exclude_sub;

X = X(keep_idx, :);
y = y(keep_idx);
subj = subj(keep_idx);

fprintf('Excluded subject %d\n', exclude_sub);
fprintf('Remaining subjects: %d\n', numel(unique(subj)));

%% LOSO decoding
subjects = unique(subj);
acc_subj = zeros(length(subjects), 1);

for s = 1:length(subjects)

    test_subj = subjects(s);

    train_idx = subj ~= test_subj;
    test_idx  = subj == test_subj;

    X_train = X(train_idx, :);
    y_train = y(train_idx);

    X_test = X(test_idx, :);
    y_test = y(test_idx);

    % Z-score using training data only
    mu = mean(X_train, 1);
    sigma = std(X_train, 0, 1);
    sigma(sigma == 0) = 1;

    X_train_z = (X_train - mu) ./ sigma;
    X_test_z  = (X_test - mu) ./ sigma;

    Mdl = fitcsvm(X_train_z, y_train, ...
        'KernelFunction', 'linear', ...
        'ClassNames', [0 1]);

    y_pred = predict(Mdl, X_test_z);

    acc_subj(s) = mean(y_pred == y_test);

    fprintf('Subject %d accuracy = %.3f\n', test_subj, acc_subj(s));
end

%% Group test
mean_acc = mean(acc_subj);
sem_acc = std(acc_subj) / sqrt(length(acc_subj));

[~, p, ~, stats] = ttest(acc_subj, 0.5);

fprintf('\nMean LOSO accuracy = %.3f\n', mean_acc);
fprintf('SEM = %.3f\n', sem_acc);
fprintf('t(%d) = %.3f, p = %.4f\n', stats.df, stats.tstat, p);