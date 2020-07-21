function Test1

% General Settings
global BpodSystem
COM_AI = 'COM4';
COM_AO = 'COM5';

% Load parameters (use defaults if not defined otherwise)
S = BpodSystem.ProtocolSettings;
S = defaults(S,'maxTrials',     1000);  % Maximum number of trials
S = defaults(S,'fsAO',          1E3);	% Sampling Rate (analog output)
S = defaults(S,'fsAI',          1E3);	% Sampling Rate (analog input)
S = defaults(S,'dWaitBase',     5);     % Wait Period (base)
S = defaults(S,'dWaitVar',      .5);    % Wait Period (+/-)
S = defaults(S,'dVib',          .5);    % Duration of vibration
S = defaults(S,'tempSlopeIn',   2);     % Temperature/Voltage ratio (in)
S = defaults(S,'tempSlopeOut',  4);     % Temperature/Voltage ratio (out)
S = defaults(S,'tempBase',      32);    % Temperature baseline (?C)
S = defaults(S,'tempStimRamp',  .1);    % Duration of temperature ramp (s)

% TODO: Configure Bpod Main Module

% Configure Analog Output Module
AO = BpodWavePlayer(COM_AO);
AO.SamplingRate = S.fsAO;
AO.loadWaveform(1, pulse(S.fsAO,1,.1,5))        % temperature ramp
AO.loadWaveform(2, pulse(S.fsAO,S.dVib,0,5)) 	% vibration
AO.loadWaveform(3, pulse(S.fsAO,.01,0,5))       % "TTL"
AO.BpodEvents{1} = 'off';
AO.TriggerProfileEnable = 'On';
AO.TriggerProfiles(1,1) = 1; % Profile 1: Temperature Stimulus on AO1
AO.TriggerProfiles(2,2) = 2; % Profile 2: Vibration Stimulus on AO2
AO.TriggerProfiles(3,3) = 3; % Profile 3: "TTL" on AO3 = 2P Acquisition Stop
AO.TriggerProfiles(4,4) = 3; % Profile 4: "TTL" on AO4 = 2P Next File
Waveforms = AO.Waveforms;

% Configure Analog Input Module
AI = BpodAnalogIn(COM_AI);
AI.nActiveChannels  = 1;            % Number of channels to read
AI.InputRange{1}    = '-10V:10V';   % Input range (V)
AI.SamplingRate     = S.fsAI;       % Sampling rate for all channels (Hz)

% Configure DIO Module

% prepare plots
hFig = figure(...
    'NumberTitle',  'off', ...
    'DockControls', 'off', ...
    'ToolBar',      'none', ...
    'MenuBar',      'none', ...
    'Visible',      'off');
hAx = axes(hFig, ...
    'NextPlot',     'add', ...
    'TickDir',      'out', ...
    'Box',          'off');
hPlotAO = plot(hAx,NaN,NaN,'color',[.8 .8 .8]);
hPlotAI = plot(hAx,NaN,NaN,'k');
xEvent1 = xline(0,'-b','Paw Imaging');
xEvent2 = xline(0,'-r','Widefield');
xlabel(hAx,'Time (s)')
ylabel(hAx,['Temperature (' char(176) 'C)'])
xlim([-5 2])

% helper functions
volt2degIN  = @(v) v * S.tempSlopeIn  + S.tempBase;
volt2degOUT = @(v) v * S.tempSlopeOut + S.tempBase;

% prepare state machine & start first trial
TrialManager  = TrialManagerObject;
[sma,S_Trial] = prepareStateMachine(1,S);
TrialManager.startTrial(sma);

% main loop
for thisTrial = 1:S.maxTrials
    
    % prepare next trial's state machine
    [sma,S_NextTrial] = prepareStateMachine(thisTrial+1,S);
    
    % get this trial's data
    raw = TrialManager.getTrialData;
    
    if ~isempty(fieldnames(raw))
        AIdata = AI.getData();
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,raw);
        BpodSystem.Data.TrialSettings(thisTrial) = S_Trial;
        BpodSystem.Data.AnalogInput(thisTrial) = AIdata;
        SaveBpodSessionData;
        
        % update plots
        set(hFig,'Name',sprintf('Trial %d',thisTrial),'Visible','on')
        title(hAx,sprintf('Trial %d',thisTrial))
        states = BpodSystem.Data.RawEvents.Trial{thisTrial}.States;
        events = BpodSystem.Data.RawEvents.Trial{thisTrial}.Events;
        t0     = states.Stimulus(1);
        hPlotAI.XData = AIdata.x - t0;
        hPlotAI.YData = volt2degIN(AIdata.y);
        hPlotAO.XData = (0:(numel(Waveforms{1})-1)) ./ S.fsAO;
        hPlotAO.YData = volt2degOUT(Waveforms{1});
        xEvent1.Value = events.GlobalTimer1_Start - t0;
        xEvent2.Value = events.GlobalTimer2_Start - t0;
    end
    
    HandlePauseCondition;               % check if user pressed PAUSE
    if BpodSystem.Status.BeingUsed == 0 % check if user pressed STOP
        break;
    end
    if thisTrial == S.maxTrials         % check if we reached last trial
        break;
    end

    % start next trial
    S_Trial = S_NextTrial;
    TrialManager.startTrial(sma);
end

% clean up
clear AI AO
close(hFig)

end

function [sma,S] = prepareStateMachine(currentTrial,S)

% Load Serial Messages
LoadSerialMessages('AnalogIn1', { ...
    ['L' 1], ...    % 1: Start logging analog data
    ['L' 0]});      % 2: Stop  logging analog data
LoadSerialMessages('WavePlayer1', { ...
    ['P' 0], ...    % 1: Play trigger profile 0
    ['P' 1], ...    % 2: Play trigger profile 1
    ['P' 2], ...    % 3: Play trigger profile 2
    ['P' 3]});      % 4: Play trigger profile 3
LoadSerialMessages('DIO1', {...
    [19 0], ...     % 1: DIO 19 low
    [19 1], ...     % 2: DIO 19 high
    [20 0], ...     % 3: DIO 20 low
    [20 1], ...     % 4: DIO 20 high
    [21 0], ...     % 5: DIO 21 low
    [21 1], ...     % 6: DIO 21 high
    [22 0], ...     % 7: DIO 22 low
    [22 1]});       % 8: DIO 22 high

% Define timer durations
S.dWait = S.dWaitBase + 2*rand*S.dWaitVar - S.dWaitVar;
S.tStartImagePaw       = S.dWait - 2;
S.tStartImageWidefield = S.dWait - 3 + rand*4-2;

% Create new State Matrix
sma = NewStateMatrix();

% Define Global Timers
sma = SetGlobalTimer(sma, ...
    'TimerID',      1, ...
    'Duration',     .1, ...
    'OnsetDelay',   S.tStartImagePaw, ...
    'Channel',      'BNC1');
sma = SetGlobalTimer(sma, ...
    'TimerID',      2, ...
    'Duration',     .1, ...
    'OnsetDelay',   S.tStartImageWidefield, ...
    'Channel',      'BNC2');

% Define States
sma = AddState(sma, ...
    'Name',                     'Start', ...
    'Timer',                    0, ...
    'StateChangeConditions',    {'Tup', 'StartTimer1'}, ...
    'OutputActions',            {'AnalogIn1', 1, ...
                                 'DIO1', 2});           % DIO 19: High
sma = AddState(sma, ...
    'Name',                     'StartTimer1', ...
    'Timer',                    0, ...
    'StateChangeConditions',    {'Tup', 'StartTimer2'}, ...
    'OutputActions',            {'GlobalTimerTrig', 1});
sma = AddState(sma, ...
    'Name',                     'StartTimer2', ...
    'Timer',                    0, ...
    'StateChangeConditions',    {'Tup', 'PreStimulus'}, ...
    'OutputActions',            {'GlobalTimerTrig', 2});

sma = AddState(sma, ...
    'Name',                     'PreStimulus', ...
    'Timer',                    S.dWait, ...
    'StateChangeConditions',    {'Tup', 'Stimulus'}, ...
    'OutputActions',            {});
sma = AddState(sma, ...
    'Name',                     'Stimulus', ...
    'Timer',                    1, ...
    'StateChangeConditions',    {'Tup', 'PostStimulus'}, ...
    'OutputActions',            {'WavePlayer1', 1, ...
                                 'DIO1', 1});
sma = AddState(sma, ...
    'Name',                     'PostStimulus', ...
    'Timer',                    1, ...
    'StateChangeConditions',    {'Tup', 'Stop'}, ...
    'OutputActions',            {});

sma = AddState(sma, ...
    'Name',                     'Stop', ...
    'Timer',                    0, ...
    'StateChangeConditions',    {'Tup', 'exit'}, ...
    'OutputActions',            {'AnalogIn1', 2});
end

function struct = defaults(struct,field,value)
if ~isfield(struct,field)
    struct.(field) = value;
end
end

function out = pulse(fs,dPulse,dRamp,amplitude)
out = [ones(1,round(dPulse * fs)) 0] .* amplitude;
if dRamp > 0
    nRamp = round(dRamp*fs);
    tmp   = ones(1,nRamp) / nRamp;
    out   = conv(out,tmp);
end
end
