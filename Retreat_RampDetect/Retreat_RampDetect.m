function Retreat_RampDetect
global BpodSystem
clc

% if ~exist('PsychtoolboxVersion','file')
%     error('Please install Psychtoolbox-3')
% end

% Define parameters and trial structure
S = BpodSystem.ProtocolSettings;
if isempty(S) || isempty(fieldnames(S))
    S.nTrials = 5;
    S.Duration = 30000;
    S.Amplitude = 20;
    S.Baseline = 32;
end
S.Gain = 0.5;
S.SamplingRateOut = 1000;

% Configure WavePlayer Module
W = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1);
W.OutputRange = '-10V:10V';
W.SamplingRate = S.SamplingRateOut;
W.TriggerProfileEnable = 'On';
W.BpodEvents{1} = 'On';
S.waveformBase = linspace(0,1,S.SamplingRateOut*S.Duration/1000);
W.TriggerProfiles = zeros(64,4);
for ii = 1:numel(S.Amplitude)
    S.waveformActual{ii} = S.waveformBase * S.Amplitude(ii) * S.Gain;
    W.loadWaveform(ii,S.waveformActual{ii});
    W.TriggerProfiles(ii,1) = ii;
    LoadSerialMessages('WavePlayer1', {['P' ii-1]}, ii);
end
clear W

% Add softcode handler
BpodSystem.SoftCodeHandlerFunction = 'softcodeFcn';


%% Main loop (runs once per trial)
for currentTrial = 1:S.nTrials
    
    % Assemble state machine
    sma = NewStateMachine();
    sma = AddState(sma, ...
        'Name',                 'Start', ...
        'Timer',                0.01, ...
        'StateChangeConditions', { ...
            'Button1_Press',    'Abort', ...
            'Tup',              'Wait'}, ...
        'OutputActions', { ...
            'SoftCode',         1, ...
            'WavePlayer1',      1});
    sma = AddState(sma, ...
        'Name',                 'Wait', ...
        'Timer',                0, ...
        'StateChangeConditions', { ...
            'Button1_Press',    'Abort', ...
            'WavePlayer1_1',    'Bye'}, ...
        'OutputActions', {}); 
    sma = AddState(sma, ...
        'Name',                 'Abort', ...
        'Timer',                0, ...
        'StateChangeConditions', { ...
            'Tup',              'Bye'}, ...
        'OutputActions', { ...
            'WavePlayer1',      'X', ...
            'SoftCode',         2});
    sma = AddState(sma, ...
        'Name',                 'Bye', ...
        'Timer',                0, ...
        'StateChangeConditions', { ...
            'Tup',              'exit'}, ...
        'OutputActions', { ...
            'SoftCode',         3});
    SendStateMatrix(sma);

    % Start first trial by pressing button
    if currentTrial == 1
        disp('<strong>Press and release button to start paradigm.</strong>')
        BpodSystem.StartModuleRelay('Button1');
        while ~BpodSystem.SerialPort.bytesAvailable || ModuleRead('Button1',1) ~= 1
            pause(0.1)
        end
        BpodSystem.StopModuleRelay;
        disp('Starting paradigm ...')
        pause(1)
    end    
    fprintf('\n<strong>Trial %d</strong>\n',currentTrial)
    
    % Run the trial and return events
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.TrialSettings(currentTrial) = S;
        SaveBpodSessionData;
        
        % Update online plots
        plot_responses
    end
    
    pause(5)
    
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
