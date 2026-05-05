% within-subject design GOAL SWITCHING CPT w/ Reward- Sept 2025
% Written by Matthieu Chidharom, PhD

try
    clear all;          % clear all matlab vars
    Screen('CloseAll'); % close any open psychtoolbox windows
    commandwindow
    StartTime=datestr(now);
    rng('shuffle')

    %%  DEMOGRAPHIC QUESTIONS

    promptTitle         = 'Experimental Setup Information';
    prompt              = {'Subject number:', 'Condition:','Color:','Reward:','Eye Track? (0 or 1)','Output:'};
    promptNumAnsLines   = 1;
    promptDefaultAns    = {'99','1','1','1','1', 'raw_switch_eeg_v2_R/'};
    answer              = inputdlg(prompt, promptTitle, promptNumAnsLines, promptDefaultAns);
    [expt.subjNum, expt.condition, expt.color, expt.reward, expt.eyetracker, expt.saveDir] = deal(answer{:});

    subjNum = str2num(expt.subjNum);
    condition = str2num(expt.condition);
    cue_color_condition = str2num(expt.color);
    reward_condition = str2num(expt.reward);
    time=datestr(now,'mmddyy_HHMM');

    Outfile=[expt.saveDir 'switch_eeg_v2_R_' num2str(subjNum) '_' time];


    p.subNum = str2num(expt.subjNum);
    p.eyeTrack=str2num(expt.eyetracker);


    %% IMPORTANT VARIBLES
    Screen('Preference', 'SkipSyncTests', 1)
    bgColour=[230 230 230];
    textColour=[0 0 0];

    % Get the screen numbers
    screens = Screen('Screens');
    screenNumber = max(screens);
    [w, mainWindowRect]= Screen('OpenWindow',screenNumber-1,bgColour);
    expt.winPtr = w;

    % Obtention de la taille de l'Ã©cran
    screenSize = get(0, 'ScreenSize');
    screenWidth = screenSize(3);% Largeur de l'Ã©cran
    screenHeight = screenSize(4);% Hauteur de l'Ã©cran
    centerx = screenWidth / 2;% Calcul des coordonnÃ©es du centre
    centery = screenHeight / 2;

    %     centerx=1280; %BIG SCREEN = 960 - Laptop = 720
    %     centery=720; %BIG SCREEN = 540 - Laptop = 450

    PriorityLevel= MaxPriority(w);
    Priority(PriorityLevel);
    timing=Screen('GetFlipInterval',w);% get the flip rate of current monitor.
    timingcorrection=timing/2; %this ensures proper timing of the flips by making sure the command has enough time to execute before the next screen refresh
    [oldFontName,oldFontNumber]=Screen('TextFont', w, 'Helvetica');
    oldTextSize=Screen('TextSize', w, 24);

    % Set up keyboard presses
    KbName('UnifyKeyNames'); quitkey=KbName('q');spacekey=KbName('space');nkey=KbName('n'); bkey=KbName('b'); ckey=KbName('c'); pkey=KbName('p'); skey=KbName('s');
    escape = KbName('ESCAPE');  % Mac == 'ESCAPE' % PC == 'esc'

    feedback={'A well deserved break!'; 'Keep on truckin!';  'Perseverance is key!'; 'Go Science, go!';};


    %% -------------------------------------------------------------------------
    % Important options
    %-------------------------------------------------------------------------

    p.date_time = clock;
    p.is_PC = ispc;  % 1 = use PC settings (hide taskbar) (ispc function detects if it's a pc or not)
    p.portCodes = 1;  %1 = use p.portCodes (we're in the booth) = connect to the eeg port/ 0 if no eeg booth
    p.windowed = 0; % 1 = small win for easy debugging!
    p.eyeMode = 0; % using eye tracker
    if p.portCodes == 1
        % run the script to configure the parallel port
        config_io;
        % write a value to the default LPT1 printer output port (at 0x378)
        % This is the port address!
        event_port = hex2dec('D050');
    end
    % Manually hide the task bar so it doesn't pop up because of flipping
    % the PTB screen during GetMouse:
    if p.is_PC
        ShowHideWinTaskbarMex(0);
    end

    %% EYE-TRACKING SETUP

    %----------------------------------------------------
    % Initiate the Eyetracker.
    %----------------------------------------------------
    % STEP 1
    % Initialization of the connection with the Eyelink Gazetracker.
    % exit program if this fails.
    if p.eyeTrack
        if EyelinkInit()~= 1;return;end
    end
    %----------------------------------------------------
    % Now that the display is built, send experiment details to the eye tracker
    %----------------------------------------------------
    if p.eyeTrack
        EyeLinkDefaults=EyelinkInitDefaults(w); % How does inputting info here help?
        % force remote mode

        if p.eyeMode

            % remote mode
            Eyelink('command', 'elcl_select_configuration = RTABLER'); % remote mode
            Eyelink('command', 'calibration_type = HV5'); % 5-pt calibration

        else
            % chin rest
            Eyelink('command', 'elcl_select_configuration = MTABLER'); % chin rest
            Eyelink('command', 'calibration_type = HV9'); % 9-pt calibration

        end


        Eyelink('command','sample_rate = %d',1000)%Set sampling rate
        % stamp header in EDF file
        Eyelink('command', 'add_file_preamble_text','DWR_Pupil_2015');
        % Setting the proper recording resolution, proper calibration type,
        % as well as the data file content;
        %%[width, height]=Screen('WindowSize', s);
        screenSize=get(0,'ScreenSize');
        width=screenSize(3);
        height=screenSize(4);
        Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
        Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);
        % make sure that we get gaze data from the Eyelink
        %Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');
        % set EDF file contents using the file_sample_data and
        % file-event_filter commands
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,HTARGET,GAZERES,STATUS,INPUT');
        % set link data thtough link_sample_data and link_event_filter
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
        % proportion commands to adjust size of calibrated area
        Eyelink('command', 'calibration_area_proportion 0.5 0.5')
        Eyelink('command', 'validation_area_proportion 0.5 0.5')

        % get host tracker version
        [v,vs]=Eyelink('GetTrackerVersion');

        fprintf('Running experiment on a ''%s'' tracker.\n', vs );
        fprintf('Running experiment on version ''%d''.\n', v );

        % open file to record data to
        edfFile = ['SW_' num2str(p.subNum) '.edf']; % File name MUST BE LESS THAN 8 characters!!!!!
        Eyelink('Openfile', edfFile);
    end



    %% SET UP

    % main variables
    cue_dur = 0.5;
    cue_stim_dur = 0.3;
    trial_dur  = 1; % time of the trial
    stim_dur = 0.5;
    freq_nogo = 0.20; % Fréquence des NoGo
    blink_time = 0.7;
    fixation_point_time = 0.3;
    totalReward = 0;

    % Initialisation des variables de switching
    nb_mini_blocks = 128;  %128 -- 2560 trials in total
    nb_trials_mini_blocks = 20; %20
    ntrials = nb_mini_blocks*nb_trials_mini_blocks;

    pair_patterns = [1 2; 2 1; 1 1; 2 2];% Créer des paires de mini-blocks alternant switch et repeat -  Une paire contient un switch suivi d'un repeat (ex: [1 2], [2 1])
    num_pairs = nb_mini_blocks / 2;  % Calculer le nombre de paires nécessaires

    repeats_per_pair = num_pairs / size(pair_patterns, 1);% Assurer un équilibre parfait entre les switchs et les repeats % Chaque paire de types est répétée le même nombre de fois

    if mod(repeats_per_pair, 1) ~= 0
        error('Le nombre total de mini-blocks doit être un multiple de 4 pour équilibrer les patterns');
    end

    task_sets = repmat(pair_patterns, repeats_per_pair, 1);% Créer la liste complète des mini-blocks
    task_sets = task_sets(randperm(size(task_sets, 1)), :);  % Mélanger les paires correctement
    task_sets = reshape(task_sets', 1, []);  % Transformer en un seul vecteur

    task_set_type = repmat(task_sets, nb_trials_mini_blocks, 1);% Création de la variable task_set_type
    task_set_type = task_set_type(:)';  % Transformer en vecteur ligne

    condition_changes = diff(task_sets) ~= 0;% Calcul du nombre de switch et de repeat pour vérification
    num_switch = sum(condition_changes);
    num_repeat = nb_mini_blocks - num_switch - 1;  % -1 car le premier block n'a pas de précédent


    % Initialisation de cue_onset
    cue_onset = zeros(1, ntrials);

    % Parcourir les indices de début de chaque mini-block
    for i = 1:nb_trials_mini_blocks:ntrials
        if task_set_type(i) == 1
            cue_onset(i) = 1; % Marquer avec 1 si le task_set_type est 1
        elseif task_set_type(i) == 2
            cue_onset(i) = 2; % Marquer avec 2 si le task_set_type est 2
        end
    end


    % color des cues
    if cue_color_condition == 1
        cue_color_task_set_1 = [0 0 255]; % Bleu pour task_set_1
        cue_color_task_set_2 = [255 0 0]; % Rouge pour task_set_2
    elseif cue_color_condition == 2
        cue_color_task_set_1 = [255 0 0]; % Rouge pour task_set_1
        cue_color_task_set_2 = [0 0 255]; % Bleu pour task_set_2
    else
        error('Invalid cue color condition. Please set to either 1 or 2.');
    end

    cue_size = 100;  % Taille du carré (en pixels)
    cue_rect = [0 0 cue_size cue_size];  % Taille du rectangle

    % Position du carré au centre de l'écran
    [screenXpixels, screenYpixels] = Screen('WindowSize', w);  % Dimensions de l'écran
    centerX = screenXpixels / 2;
    centerY = screenYpixels / 2;
    centeredRect = CenterRectOnPointd(cue_rect, centerX, centerY);


    %% STIMULI

    %Fixation cross
    fix1dur      =.5;%time each fixation point should be presented for
    fixsize = 5;
    fixloc=[centerx-.5*fixsize, centerx+.5*fixsize, centerx, centerx;   centery, centery, centery-.5*fixsize, centery+.5*fixsize];
    fixwidth  = 3;
    fixcol=[0 0 0];
    %fixcol=[180 180 180];


    % Reminder and lure = absent
    reminder_trial = zeros(1, ntrials)
    lure_trial= zeros(1, ntrials)

    % Calculer le nombre de NoGo pour chaque task set
    num_nogo = round(ntrials * freq_nogo);

    trial_type_taskset_1 = zeros(1, ntrials);% Initialisation des vecteurs de type de trial pour chaque task set
    trial_type_taskset_2 = zeros(1, ntrials);

    nogo_indices_set_1 = randperm(ntrials, num_nogo);% Sélection aléatoire des indices NoGo pour chaque task set
    nogo_indices_set_2 = randperm(ntrials, num_nogo);

    trial_type_taskset_1(nogo_indices_set_1) = 1; % Affecter 1 pour les NoGo dans task_set_1
    trial_type_taskset_2(nogo_indices_set_2) = 1; % Affecter 1 pour les NoGo dans task_set_2




    switch condition
        case 1
            task_set_1.goCategory = 'even';
            task_set_1.nogoCategory = 'odd'; % La catégorie opposée à 'even'
            task_set_2.goCategory = 'consonant';
            task_set_2.nogoCategory = 'vowel'; % La catégorie opposée à 'male'
        case 2
            task_set_1.goCategory = 'even';
            task_set_1.nogoCategory = 'odd';
            task_set_2.goCategory = 'vowel';
            task_set_2.nogoCategory = 'consonant'; % La catégorie opposée à 'vowel'
        case 3
            task_set_1.goCategory = 'odd';
            task_set_1.nogoCategory = 'even'; % La catégorie opposée à 'odd'
            task_set_2.goCategory = 'consonant';
            task_set_2.nogoCategory = 'vowel';
        case 4
            task_set_1.goCategory = 'odd';
            task_set_1.nogoCategory = 'even';
            task_set_2.goCategory = 'vowel';
            task_set_2.nogoCategory = 'consonant';
        otherwise
            error('Condition value out of range. It must be between 1 and 4.');
    end




    % Définir les catégories pour task_set_1 et task_set_2
    goCategory_taskset_1 = task_set_1.goCategory;  % Par exemple 'indoor'
    nogoCategory_taskset_1 = task_set_1.nogoCategory;  % Par exemple 'outdoor'

    goCategory_taskset_2 = task_set_2.goCategory;  % Par exemple 'male'
    nogoCategory_taskset_2 = task_set_2.nogoCategory;  % Par exemple 'female'

    % Charger les images pour les essais Go pour task_set_1
    imageFilesGoJPG_set_1 = dir(fullfile(goCategory_taskset_1, '*.jpg'));
    imageFilesGoJPEG_set_1 = dir(fullfile(goCategory_taskset_1, '*.jpeg'));
    imageFilesGo_set_1 = [imageFilesGoJPG_set_1; imageFilesGoJPEG_set_1];  % Concaténer les résultats en un seul tableau
    allGoImages_set_1 = {imageFilesGo_set_1.name};  % Liste des noms des images Go

    % Charger les images pour les essais NoGo pour task_set_1
    imageFilesNoGoJPG_set_1 = dir(fullfile(nogoCategory_taskset_1, '*.jpg'));
    imageFilesNoGoJPEG_set_1 = dir(fullfile(nogoCategory_taskset_1, '*.jpeg'));
    imageFilesNoGo_set_1 = [imageFilesNoGoJPG_set_1; imageFilesNoGoJPEG_set_1];
    allNoGoImages_set_1 = {imageFilesNoGo_set_1.name};

    % Charger les images pour les essais Go pour task_set_2
    imageFilesGoJPG_set_2 = dir(fullfile(goCategory_taskset_2, '*.jpg'));
    imageFilesGoJPEG_set_2 = dir(fullfile(goCategory_taskset_2, '*.jpeg'));
    imageFilesGo_set_2 = [imageFilesGoJPG_set_2; imageFilesGoJPEG_set_2];  % Concaténer les résultats en un seul tableau
    allGoImages_set_2 = {imageFilesGo_set_2.name};  % Liste des noms des images Go

    % Charger les images pour les essais NoGo pour task_set_2
    imageFilesNoGoJPG_set_2 = dir(fullfile(nogoCategory_taskset_2, '*.jpg'));
    imageFilesNoGoJPEG_set_2 = dir(fullfile(nogoCategory_taskset_2, '*.jpeg'));
    imageFilesNoGo_set_2 = [imageFilesNoGoJPG_set_2; imageFilesNoGoJPEG_set_2];
    allNoGoImages_set_2 = {imageFilesNoGo_set_2.name};



    % go-nogo appearence side (0=left & 1=right)
    side_gonogo = [zeros(1, ntrials / 2), ones(1, ntrials / 2)]; % Initialiser side_gonogo avec la moitié des valeurs à 0 et l'autre moitié à 1
    shuffledIndices = randperm(ntrials);% Mélanger aléatoirement side_gonogo
    side_gonogo = side_gonogo(shuffledIndices);



    % Paramètres de l'image (largeur et hauteur)
    imageSize = 300;
    offsetFromCenter = 200;% Décalage à partir du centre
    rightImageCenterX = centerx + offsetFromCenter; % % Calculer les coordonnées pour centrer le milieu des images horizontalement // Centre de l'image de droite
    leftImageCenterX = centerx - offsetFromCenter;  % // Centre de l'image de gauche
    imageCenterY = centery;% Calculer les coordonnées pour centrer le milieu des images verticalement
    destRect_right = [rightImageCenterX - (imageSize / 2), imageCenterY - (imageSize / 2), rightImageCenterX + (imageSize / 2), imageCenterY + (imageSize / 2)]; % Image de droite
    destRect_left = [leftImageCenterX - (imageSize / 2), imageCenterY - (imageSize / 2), leftImageCenterX + (imageSize / 2), imageCenterY + (imageSize / 2)];   % Image de gauche

    % Couleur du contour (noir)
    borderColor = [0 0 0];

    % Largeur du contour
    borderWidth = 10; % Vous pouvez ajuster cette valeur pour changer l'épaisseur du contour



    % Supposons que 'respond' est défini pour chaque tt et indique si le sujet a appuyé sur un bouton (1) ou non (0)
    %     accuracy_taskset_1 = zeros(1, ntrials); % Initialiser l'accuracy pour le task set 1
    %     accuracy_taskset_2 = zeros(1, ntrials); % Initialiser l'accuracy pour le task set 2


    %%  set up the eeg triggers

    % Initialize the trigger_onset variable
    trigger_onset = zeros(1, ntrials);


    for i = 1:ntrials
        % Handle each trial type and side condition
        if task_set_type(i) == 1 && trial_type_taskset_1(i) == 0 && side_gonogo(i) == 0 %
            trigger_onset(i) = 1;  % go trial task 1 appears on the left
        elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 0 && side_gonogo(i) == 1 %
            trigger_onset(i) = 2;  % go trial task 1 appears on the right
        elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 1 && side_gonogo(i) == 0 %
            trigger_onset(i) = 3;  % nogo trial task 1 appears on the left
        elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 1 && side_gonogo(i) == 1 %
            trigger_onset(i) = 4;  % nogo trial task 1 appears on the right
        elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 0 && side_gonogo(i) == 0 %
            trigger_onset(i) = 5;  % go trial task 1 appears on the left
        elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 0 && side_gonogo(i) == 1 %
            trigger_onset(i) = 6;  % go trial task 1 appears on the right
        elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 1 && side_gonogo(i) == 0 %
            trigger_onset(i) = 7;  % nogo trial task 1 appears on the left
        elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 1 && side_gonogo(i) == 1 %
            trigger_onset(i) = 8;  % nogo trial task 1 appears on the right
        end
    end


    %-----------------------------------------
    %% Calibrate the eyeTracker
    %-----------------------------------------


    if p.eyeTrack
        EyelinkDoTrackerSetup(EyeLinkDefaults);
    end


    %% Initial Screen
    Screen('FillRect', w, bgColour);
    [vbl, SOT]= Screen('Flip',w);
    SetMouse(0,0);
    WaitSecs(1);

    %% TRIALS
    if subjNum == 99
        runtrials = 20;
        freq_nogo = 0.20; % Fréquence des NoGo (15%) . doit etre un nb pair
        reminder_trial = zeros(1, ntrials); % dont show reminder during training
        lure_trial= zeros(1, ntrials);
        ntrials=runtrials;
        trial_type = zeros(1, ntrials);
        num_nogo = round(ntrials * freq_nogo); %Déterminer le nombre d'essais NoGo
        nogo_indices = randperm(ntrials, num_nogo); % Sélectionner aléatoirement des indices pour les NoGo
        trial_type(nogo_indices) = 1;% Affecter les NoGo dans trial_type

        nb_mini_blocks = 8;  % Assurer un nombre pair pour faciliter l'équilibrage
        nb_trials_mini_blocks = 5;


        pair_patterns = [1 2; 2 1; 1 1; 2 2];% Créer des paires de mini-blocks alternant switch et repeat -  Une paire contient un switch suivi d'un repeat (ex: [1 2], [2 1])
        num_pairs = nb_mini_blocks / 2;  % Calculer le nombre de paires nécessaires


        repeats_per_pair = num_pairs / size(pair_patterns, 1);% Assurer un équilibre parfait entre les switchs et les repeats % Chaque paire de types est répétée le même nombre de fois

        if mod(repeats_per_pair, 1) ~= 0
            error('Le nombre total de mini-blocks doit être un multiple de 4 pour équilibrer les patterns');
        end

        task_sets = repmat(pair_patterns, repeats_per_pair, 1);% Créer la liste complète des mini-blocks
        task_sets = task_sets(randperm(size(task_sets, 1)), :);  % Mélanger les paires correctement
        task_sets = reshape(task_sets', 1, []);  % Transformer en un seul vecteur

        task_set_type = repmat(task_sets, nb_trials_mini_blocks, 1);% Création de la variable task_set_type
        task_set_type = task_set_type(:)';  % Transformer en vecteur ligne

        condition_changes = diff(task_sets) ~= 0;% Calcul du nombre de switch et de repeat pour vérification
        num_switch = sum(condition_changes);
        num_repeat = nb_mini_blocks - num_switch - 1;  % -1 car le premier block n'a pas de précédent


        % Initialisation de cue_onset
        cue_onset = zeros(1, ntrials);

        % Parcourir les indices de début de chaque mini-block
        for i = 1:nb_trials_mini_blocks:ntrials
            if task_set_type(i) == 1
                cue_onset(i) = 1; % Marquer avec 1 si le task_set_type est 1
            elseif task_set_type(i) == 2
                cue_onset(i) = 2; % Marquer avec 2 si le task_set_type est 2
            end
        end


        % Initialize the trigger_onset variable
        trigger_onset = zeros(1, ntrials);

        % Redefinir les triggers
        for i = 1:ntrials
            % Handle each trial type and side condition
            if task_set_type(i) == 1 && trial_type_taskset_1(i) == 0 && side_gonogo(i) == 0 %
                trigger_onset(i) = 1;  % go trial task 1 appears on the left
            elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 0 && side_gonogo(i) == 1 %
                trigger_onset(i) = 2;  % go trial task 1 appears on the right
            elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 1 && side_gonogo(i) == 0 %
                trigger_onset(i) = 3;  % nogo trial task 1 appears on the left
            elseif task_set_type(i) == 1 && trial_type_taskset_1(i) == 1 && side_gonogo(i) == 1 %
                trigger_onset(i) = 4;  % nogo trial task 1 appears on the right
            elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 0 && side_gonogo(i) == 0 %
                trigger_onset(i) = 5;  % go trial task 1 appears on the left
            elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 0 && side_gonogo(i) == 1 %
                trigger_onset(i) = 6;  % go trial task 1 appears on the right
            elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 1 && side_gonogo(i) == 0 %
                trigger_onset(i) = 7;  % nogo trial task 1 appears on the left
            elseif task_set_type(i) == 2 && trial_type_taskset_2(i) == 1 && side_gonogo(i) == 1 %
                trigger_onset(i) = 8;  % nogo trial task 1 appears on the right
            end
        end


    else
        runtrials = ntrials;
    end


    %% Supposons que runtrials est défini et contient le nombre total d'essais à exécuter


    % SETUP
    if subjNum ~= 99 % if it's not the practice
        instructionMessage = sprintf('EXPERIMENTER: START RECORDING EEG!\n\nFile name: switch_EEG_R_%d', subjNum);
        % Ajouter la phrase "Press the uparrow to begin."
        instructionMessage = [instructionMessage '\n\n Press MAGIC KEY when ready!'];

        % Afficher la consigne au sujet
        DrawFormattedText(w, instructionMessage, 'center', centery, [0 255 0]);
        [vbl, SOT] = Screen('Flip', w);


        junk=NaN;
        while isnan(junk)
            [kd,sec,kc]=KbCheck;
            if (kd==1) && (kc(KbName('s'))==1)
                junk=1;
            end
        end
        Screen('FillRect',w,bgColour);
        [vbl, SOT]=Screen('Flip',w);
    end


    %----------------------------------------------
    if p.portCodes % Experiment start
        outp(event_port,100);
    end
    if p.eyeTrack
        Eyelink('message', 'SYNC 100');
    end
    %----------------------------------------------


    for tt = 1:runtrials
        display(tt);  % Affiche le numéro de l'essai courant

        if tt==1

            % Condition et instructions en fonction de la variable 'condition'
            switch condition
                case 1
                    instructionMessageSet1 = 'Press for even numbers and not odd.';
                    instructionMessageSet2 = 'Press for consonants letters and not vowel.';
                    colorSet1 = cue_color_task_set_1;
                    colorSet2 = cue_color_task_set_2;
                case 2
                    instructionMessageSet1 = 'Press for even numbers and not odd.';
                    instructionMessageSet2 = 'Press for vowel letters and not for consonant.';
                    colorSet1 = cue_color_task_set_1;
                    colorSet2 = cue_color_task_set_2;
                case 3
                    instructionMessageSet1 = 'Press for odd number and not even.';
                    instructionMessageSet2 = 'Press for consonant letters and not for vowel.';
                    colorSet1 = cue_color_task_set_1;
                    colorSet2 = cue_color_task_set_2;
                case 4
                    instructionMessageSet1 = 'Press for odd numbers and not even.';
                    instructionMessageSet2 = 'Press for vowel letters and not for consonant.';
                    colorSet1 = cue_color_task_set_1;
                    colorSet2 = cue_color_task_set_2;
                otherwise
                    error('Invalid condition value. Please set to either 1, 2, 3, or 4.');
            end

            % Affichage des instructions pour task_set_1
            DrawFormattedText(w, instructionMessageSet1, 'center', centery-100, cue_color_task_set_1);

            % Affichage des instructions pour task_set_2
            DrawFormattedText(w, [instructionMessageSet2], 'center',  centery-50, cue_color_task_set_2);
            DrawFormattedText(w, ['\nPress the spacebar to begin.'], 'center',  centery, textColour);

            % Rafraîchir l'écran pour afficher les deux instructions
            Screen('Flip', w);

            % Attente de la réponse du participant pour commencer
            junk = NaN;
            while isnan(junk)
                [kd, sec, kc] = KbCheck;
                if (kd == 1) && (kc(KbName('space')) == 1)
                    junk = 1;  % Sortie de la boucle si la barre d'espace est pressée
                end
            end
            Screen('FillRect', w, bgColour);  % Nettoyage de l'écran
            Screen('Flip', w);

        end


        if tt==641 ||  tt==1281 ||  tt==1921 %tt==641 ||  tt==1281 ||  tt==1921

            display('The experimenter can pause the experiment now by pressing the ''space'' and ''p'' keys');
            junk=GetSecs;
            pause=0;
            pauseplease=0;

            while GetSecs-junk<10 && pause==0
                stuff= num2str(10-(round(GetSecs-junk)));
                %                 string=['Take a short break.' ' ' ' ' stuff];
                %                 DrawFormattedText(w, string,'center', 'center', textColour ,74);
                val=0;
                val3=size(find(accuracy==1),2)/tt*100;
                %                 string2=[feedback{RandSel(size(feedback,1),1)} '\n\n Your average accuracy was ' num2str(val3) '%.'...
                %                     '\n\n Your current reward is $ ' num2str(totalReward) '.'...
                %                     '\n\n Try to keep improving on your tasks!'];

                feedbackMessage = sprintf('Take a short break.\nYour accuracy: %.2f%%\nYour reward: $%.2f', val3, totalReward);
                DrawFormattedText(w, feedbackMessage, 'center', 'center', textColour);
                [vbl, SOT]=Screen('Flip',w);

                %                 DrawFormattedText(w, string2, 'center', 200, textColour, 74);


                % Attente de la réponse du participant pour commencer
                junk = NaN;
                while isnan(junk)
                    [kd, sec, kc] = KbCheck;
                    if (kd == 1) && (kc(KbName('space')) == 1)
                        junk = 1;  % Sortie de la boucle si la barre d'espace est pressée
                    end
                end
                Screen('FillRect', w, bgColour);  % Nettoyage de l'écran
                Screen('Flip', w);


                %-----------------------------------------
                %% Calibrate the eyeTracker
                %-----------------------------------------

                if p.eyeTrack
                    EyelinkDoTrackerSetup(EyeLinkDefaults);
                end


                %-----------------------------------------
                %% Get Ready
                %-----------------------------------------



                % Condition et instructions en fonction de la variable 'condition'
                switch condition
                    case 1
                        instructionMessageSet1 = 'Press for even numbers and not odd.';
                        instructionMessageSet2 = 'Press for consonants letters and not vowel.';
                        colorSet1 = cue_color_task_set_1;
                        colorSet2 = cue_color_task_set_2;
                    case 2
                        instructionMessageSet1 = 'Press for even numbers and not odd.';
                        instructionMessageSet2 = 'Press for vowel letters and not for consonant.';
                        colorSet1 = cue_color_task_set_1;
                        colorSet2 = cue_color_task_set_2;
                    case 3
                        instructionMessageSet1 = 'Press for odd number and not even.';
                        instructionMessageSet2 = 'Press for consonant letters and not for vowel.';
                        colorSet1 = cue_color_task_set_1;
                        colorSet2 = cue_color_task_set_2;
                    case 4
                        instructionMessageSet1 = 'Press for odd numbers and not even.';
                        instructionMessageSet2 = 'Press for vowel letters and not for consonant.';
                        colorSet1 = cue_color_task_set_1;
                        colorSet2 = cue_color_task_set_2;
                    otherwise
                        error('Invalid condition value. Please set to either 1, 2, 3, or 4.');
                end



                % Affichage des instructions pour task_set_1
                DrawFormattedText(w, instructionMessageSet1, 'center', centery-100, cue_color_task_set_1);

                % Affichage des instructions pour task_set_2
                DrawFormattedText(w, [instructionMessageSet2], 'center',  centery-50, cue_color_task_set_2);
                DrawFormattedText(w, ['\nPress the spacebar to begin.'], 'center',  centery, textColour);


                % Rafraîchir l'écran pour afficher les deux instructions
                Screen('Flip', w);

                % Attente de la réponse du participant pour commencer
                junk = NaN;
                while isnan(junk)
                    [kd, sec, kc] = KbCheck;
                    if (kd == 1) && (kc(KbName('space')) == 1)
                        junk = 1;  % Sortie de la boucle si la barre d'espace est pressée
                    end
                end
                Screen('FillRect', w, bgColour);  % Nettoyage de l'écran
                Screen('Flip', w);

                WaitSecs(2);


            end


            SetMouse(0,0);
        end






        %%%% start recording eye-tracking for each trial
        if p.eyeTrack
            Eyelink('Command', 'set_idle_mode');
            Eyelink('StartRecording');
            Eyelink('message', 'TRIAL %d', tt);
        end



        % Display fixation BASELINE ICI POUR EVITER LES PB d'EYE TRACKING
        Screen('DrawLines', w, fixloc, fixwidth, fixcol);
        Screen('Flip', w); % Afficher la croix de fixation sans les stimuli
        WaitSecs(fixation_point_time);


        if cue_onset(tt) == 1
            % Dessiner un carré de la couleur de task_set_1
            Screen('FillRect', w, cue_color_task_set_1, centeredRect);
            Screen('Flip', w);

            if p.portCodes
                outp(event_port,11);
            end

            if p.eyeTrack
                Eyelink('message', 'cue_onset1');
                Eyelink('message', 'SYNC 11');
            end

            WaitSecs(cue_dur);  % Attendre 'cue_dur' secondes
            % Display fixation
            Screen('DrawLines', w, fixloc, fixwidth, fixcol);
            Screen('Flip', w); % Afficher la croix de fixation sans les stimuli
            WaitSecs(cue_stim_dur);

        elseif cue_onset(tt) == 2
            % Dessiner un carré de la couleur de task_set_2
            Screen('FillRect', w, cue_color_task_set_2, centeredRect);
            Screen('Flip', w);

            if p.portCodes
                outp(event_port,12);
            end

            if p.eyeTrack
                Eyelink('message', 'cue_onset2');
                Eyelink('message', 'SYNC 12');
            end


            WaitSecs(cue_dur);  % Attendre 'cue_dur' secondes
            % Display fixation
            Screen('DrawLines', w, fixloc, fixwidth, fixcol);
            Screen('Flip', w); % Afficher la croix de fixation sans les stimuli
            WaitSecs(cue_stim_dur);

        elseif cue_onset(tt) == 0
            Screen('FillRect', w, bgColour);
            Screen('DrawLines', w, fixloc, fixwidth, fixcol);
            vbl = Screen('Flip', w); % Actualiser l'écran

            if p.portCodes
                outp(event_port,13);
            end

            if p.eyeTrack
                Eyelink('message', 'no_cue_onset3');
                Eyelink('message', 'SYNC 13');
            end


        end

        % Display fixation
        Screen('FillRect', w, bgColour);
        Screen('DrawLines', w, fixloc, fixwidth, fixcol);





        % Sélectionner une image Go ou  NoGo de manière aléatoire


        % Gérer les essais pour task_set_1
        if trial_type_taskset_1(tt) == 0 % Go trial
            randomGoIndex = randi(length(allGoImages_set_1));  % Sélectionner un indice aléatoire pour Go
            selectedImageGoName = allGoImages_set_1{randomGoIndex};  % Sélectionner le nom de l'image Go
            imageMatrixGo_taskset_1 = imread(fullfile(goCategory_taskset_1, selectedImageGoName));  % Charger l'image Go
            image_go_nogo_taskset_1{tt} = selectedImageGoName;
        elseif trial_type_taskset_1(tt) == 1 % NoGo trial
            randomNoGoIndex = randi(length(allNoGoImages_set_1));  % Sélectionner un indice aléatoire pour NoGo
            selectedImageNoGoName = allNoGoImages_set_1{randomNoGoIndex};  % Sélectionner le nom de l'image NoGo
            imageMatrixNoGo_taskset_1 = imread(fullfile(nogoCategory_taskset_1, selectedImageNoGoName));  % Charger l'image NoGo
            image_go_nogo_taskset_1{tt} = selectedImageNoGoName;
        end

        % Gérer les essais pour task_set_2
        if trial_type_taskset_2(tt) == 0 % Go trial
            randomGoIndex = randi(length(allGoImages_set_2));  % Sélectionner un indice aléatoire pour Go
            selectedImageGoName = allGoImages_set_2{randomGoIndex};  % Sélectionner le nom de l'image Go
            imageMatrixGo_taskset_2 = imread(fullfile(goCategory_taskset_2, selectedImageGoName));  % Charger l'image Go
            image_go_nogo_taskset_2{tt} = selectedImageGoName;
        elseif trial_type_taskset_2(tt) == 1 % NoGo trial
            randomNoGoIndex = randi(length(allNoGoImages_set_2));  % Sélectionner un indice aléatoire pour NoGo
            selectedImageNoGoName = allNoGoImages_set_2{randomNoGoIndex};  % Sélectionner le nom de l'image NoGo
            imageMatrixNoGo_taskset_2 = imread(fullfile(nogoCategory_taskset_2, selectedImageNoGoName));  % Charger l'image NoGo
            image_go_nogo_taskset_2{tt} = selectedImageNoGoName;
        end


        % Vérification de la position principale et du type de task set
        if side_gonogo(tt) == 0  % Si la présentation principale est à gauche
            if task_set_type(tt) == 1  % Si task set 1 est principal
                if trial_type_taskset_1(tt) == 0  % Go pour task set 1
                    Screen('PutImage', w, imageMatrixGo_taskset_1, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 1
                    Screen('PutImage', w, imageMatrixNoGo_taskset_1, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                end

                if trial_type_taskset_2(tt) == 0  % Go pour task set 2
                    Screen('PutImage', w, imageMatrixGo_taskset_2, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 2
                    Screen('PutImage', w, imageMatrixNoGo_taskset_2, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                end
            else  % Si task set 2 est principal
                if trial_type_taskset_2(tt) == 0  % Go pour task set 2
                    Screen('PutImage', w, imageMatrixGo_taskset_2, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 2
                    Screen('PutImage', w, imageMatrixNoGo_taskset_2, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                end
                if trial_type_taskset_1(tt) == 0  % Go pour task set 1
                    Screen('PutImage', w, imageMatrixGo_taskset_1, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 1
                    Screen('PutImage', w, imageMatrixNoGo_taskset_1, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                end
            end

        else  % Si la présentation principale est à droite
            if task_set_type(tt) == 1  % Si task set 1 est principal
                if trial_type_taskset_1(tt) == 0  % Go pour task set 1
                    Screen('PutImage', w, imageMatrixGo_taskset_1, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 1
                    Screen('PutImage', w, imageMatrixNoGo_taskset_1, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir

                end
                if trial_type_taskset_2(tt) == 0  % Go pour task set 2
                    Screen('PutImage', w, imageMatrixGo_taskset_2, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                else  % NoGo pour task set 2
                    Screen('PutImage', w, imageMatrixNoGo_taskset_2, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir
                end
            else  % Si task set 2 est principal
                if trial_type_taskset_2(tt) == 0  % Go pour task set 2
                    Screen('PutImage', w, imageMatrixGo_taskset_2, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir

                else  % NoGo pour task set 2
                    Screen('PutImage', w, imageMatrixNoGo_taskset_2, destRect_right);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir

                end
                if trial_type_taskset_1(tt) == 0  % Go pour task set 1
                    Screen('PutImage', w, imageMatrixGo_taskset_1, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir

                else  % NoGo pour task set 1
                    Screen('PutImage', w, imageMatrixNoGo_taskset_1, destRect_left);
                    Screen('FrameRect', w, borderColor, destRect_left, borderWidth); % Ajout du contour noir
                    Screen('FrameRect', w, borderColor, destRect_right, borderWidth); % Ajout du contour noir

                end
            end
        end

        Screen('DrawLines', w, fixloc, fixwidth, fixcol, [centerx centery]);
        [vbl, SOT] = Screen('Flip', w); % Afficher les stimuli et la croix de fixation

        %-----------------------------------------------------------------
        % Let port know the go and nogo onset
        %-----------------------------------------------------------------
        if p.portCodes
            outp(event_port,trigger_onset(tt));
        end

        %-----------------------------------------------------------------
        % Let eyetracker know the go and nogo onset
        %-----------------------------------------------------------------
        if p.eyeTrack
            Eyelink('message', 'stim_onset');
            Eyelink('message', ['SYNC ' num2str(trigger_onset(tt))]);

        end


        startTime = SOT; % Début de l'essai

        reactionTime(tt) = 0; % Initialiser le temps de réaction à NaN pour indiquer aucune réaction initialement
        respond = 0;

        % Attendre 'stim_dur' secondes sans bloquer l'enregistrement des réactions
        stimEndTime = startTime + stim_dur;
        while GetSecs < stimEndTime
            [keyIsDown, secs, keyCode] = KbCheck;
            if keyIsDown && keyCode(KbName('space')) && respond == 0
                reactionTime(tt) = secs - startTime; % Enregistrer le temps de réaction
                respond = 1;
                if reactionTime(tt)> 0.005 % prevent the response trigger to delete the stimulus trigger
                    if p.portCodes
                        outp(event_port,77);
                        if p.eyeTrack
                            Eyelink('message', 'response');
                        end
                    end
                elseif reactionTime(tt)< 0.005
                    WaitSecs(0.005);
                    if p.portCodes
                        outp(event_port,77);
                        if p.eyeTrack
                            Eyelink('message', 'response');
                        end
                    end
                end
            elseif keyCode(escape) % if escape is pressed, bail out
                % Save data file at the end of each block
                save(Outfile);
                Screen('CloseAll');
                return;
            end
        end


        % images disappear after stim_dur
        Screen('Flip', w);

        % Display fixation
        Screen('DrawLines', w, fixloc, fixwidth, fixcol);
        Screen('Flip', w); % Afficher la croix de fixation sans les stimuli


        % Poursuivre la capture des temps de réaction jusqu'à 'endTime'
        endTime = startTime + trial_dur;
        while GetSecs < endTime
            [keyIsDown, secs, keyCode] = KbCheck;
            if keyIsDown && keyCode(KbName('space')) && respond == 0
                reactionTime(tt) = secs - startTime; % Enregistrer le temps de réaction si pas déjà fait
                respond = 1; % Éviter plusieurs enregistrements
                if p.portCodes
                    outp(event_port,77);
                    if p.eyeTrack
                        Eyelink('message', 'response');
                    end
                end

            elseif keyCode(escape) % if escape is pressed, bail out
                % Save data file at the end of each block
                save(Outfile);
                Screen('CloseAll');
                return;
            end
        end

        % Calculer l'accuracy pour le task set 1
        if (task_set_type(tt) == 1 && trial_type_taskset_1(tt) == 0 && respond == 1 ) || (task_set_type(tt) == 1 && trial_type_taskset_1(tt) == 1 && respond == 0) || (task_set_type(tt) == 2 && trial_type_taskset_2(tt) == 0 && respond == 1) || (task_set_type(tt) == 2 && trial_type_taskset_2(tt) == 1 && respond == 0)
            accuracy(tt) = 1; % Bonne réponse
        else
            accuracy(tt) = 0; % Mauvaise réponse
        end


        % Feedback pour les essais Go et Nogo
        if reward_condition == 1 && task_set_type(tt) == 1 && trial_type_taskset_1(tt) == 0 && accuracy(tt) == 0  % Go pour task set 1
            totalReward = totalReward - 0.04;
            Screen('DrawLines', w, fixloc, fixwidth, [255 0 0]);  % Point de fixation rouge
            DrawFormattedText(w, '- $.04', 'center', centery - 50, [255 0 0]);  % Texte rouge au-dessus du point de fixation
        elseif reward_condition == 1 && task_set_type(tt) == 1 && trial_type_taskset_1(tt) == 1 && accuracy(tt) == 1  % Go pour task set 1
            totalReward = totalReward + 0.04;
            Screen('DrawLines', w, fixloc, fixwidth, [0 255 0]);  % Point de fixation vert
            DrawFormattedText(w, '+ $.04', 'center', centery - 50, [0 255 0]);  % Texte vert au-dessus du point de fixation
        elseif reward_condition == 2 && task_set_type(tt) == 2 && trial_type_taskset_2(tt) == 0 && accuracy(tt) == 0  % Go pour task set 1
            totalReward = totalReward - 0.04;
            Screen('DrawLines', w, fixloc, fixwidth, [255 0 0]);  % Point de fixation rouge
            DrawFormattedText(w, '- $.04', 'center', centery - 50, [255 0 0]);  % Texte rouge au-dessus du point de fixation
        elseif reward_condition == 2 && task_set_type(tt) == 2 && trial_type_taskset_2(tt) == 1 && accuracy(tt) == 1  % Go pour task set 1
            totalReward = totalReward + 0.04;
            Screen('DrawLines', w, fixloc, fixwidth, [0 255 0]);  % Point de fixation vert
            DrawFormattedText(w, '+ $.04', 'center', centery - 50, [0 255 0]);  % Texte vert au-dessus du point de fixation
        else
            Screen('DrawLines', w, fixloc, fixwidth, fixcol);  % Point de fixation rouge
            DrawFormattedText(w, '$.00', 'center', centery - 50, fixcol);  % Texte rouge au-dessus du point de fixation
        end


        % Afficher le feedback à l'écran
        Screen('Flip', w);

        if p.portCodes
            outp(event_port,88);
            if p.eyeTrack
                Eyelink('message', 'feedback');
            end
        end

        % Attendre un bref  moment pour que le participant puisse voir le feedback
        WaitSecs(0.150);

        % Assurez-vous que le "endTime" pour l'essai courant prend en compte ce délai de feedback
        endTime = GetSecs + (trial_dur - stim_dur - 0.15);

        % Display fixation
        Screen('DrawLines', w, fixloc, fixwidth, fixcol);
        Screen('Flip', w); % Afficher la croix de fixation sans les stimuli
        WaitSecs(0.250);


        % Display fixation
        Screen('DrawLines', w, fixloc, fixwidth, [255 255 0]);
        Screen('Flip', w); % Afficher la croix de fixation sans les stimuli
        WaitSecs(blink_time);



        %-----------------------------
        % End recording of eyetracker
        %-----------------------------
        if p.eyeTrack
            Eyelink('StopRecording');
        end

    end

    %-----------------------------
    % Experiment end
    %-----------------------------

    if p.portCodes
        outp(event_port,200);
    end

    if p.eyeTrack
        Eyelink('message', 'SYNC 200');
    end



    total_reward_2 = totalReward;

    if total_reward_2 > 10
        total_reward_2 = 10;
    elseif total_reward_2 < 0
        total_reward_2 = 0;
    else     total_reward_2 = totalReward
    end



    % Après avoir défini task_set_type, trial_type_taskset_1 et _2 :
    trial_type = zeros(1, ntrials);
    for i = 1:ntrials
        if task_set_type(i) == 1
            trial_type(i) = trial_type_taskset_1(i);
        else
            trial_type(i) = trial_type_taskset_2(i);
        end
    end

    %Feedback message
    nogo_correct=size(find(accuracy==1),2)/size((trial_type==1),2)*100;
    meanRT=(mean(reactionTime(find(accuracy==1 & trial_type==0))))*1000;
    feedbackMessage = sprintf('Your accuracy: %.2f%%\nYour speed: %.2f ms\nYour reward: $%.2f', nogo_correct, meanRT,totalReward);
    DrawFormattedText(w, feedbackMessage, 'center', 'center', textColour);
    Screen('Flip', w);

    % Attente de la réponse du participant pour commencer
    junk = NaN;
    while isnan(junk)
        [kd, sec, kc] = KbCheck;
        if (kd == 1) && (kc(KbName('space')) == 1)
            junk = 1;  % Sortie de la boucle si la barre d'espace est pressée
        end
    end
    Screen('FillRect', w, bgColour);  % Nettoyage de l'écran
    Screen('Flip', w);




    %% END OF THE EXPERIMENT
    % Save the output file
    save(Outfile);

    % Fin de l'expérience
    WaitSecs(1);
    DrawFormattedText(w, 'Well done! Please wait for the experimenter.','center', centery, textColour);
    Screen('Flip', w);
    WaitSecs(4);

    % Restore priority level
    Priority(0);

    % Stop recording eye data
    if p.eyeTrack
        Eyelink('StopRecording');

        % Display message about transferring data
        Screen('TextSize', w, 24);
        DrawFormattedText(w, 'TRANSFERRING EYE DATA.', centerx, centery, [255 255 255]);
        Screen('Flip', w);

        % Close eyetracking file
        Eyelink('CloseFile');

        % Attempt to receive the data file
        try
            fprintf('Receiving data file ''%s''\n', edfFile );
            status = Eyelink('ReceiveFile');
            if status > 0
                fprintf('ReceiveFile status %d\n', status);
            end
            if exist(edfFile, 'file') == 2
                fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
            end
        catch rdf
            fprintf('Problem receiving data file ''%s''\n', edfFile );
            rdf;
        end

        % Shut down the EyeLink connection
        Eyelink('ShutDown');
    end

    % Close all screens
    Screen('CloseAll');

catch ME
    % Error handling
    sca; % Close all screens
    Eyelink('Shutdown'); % Ensure EyeLink is shut down
    fprintf('Error: %s\n', lasterr);
end
