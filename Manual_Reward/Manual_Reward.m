function Manual_Reward   
global BpodSystem
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

%% Setup (runs once before the first trial)
MaxTrials = 10000;

S.RewardAmount   = 3;                               % [?l]
S.RewardTime     = GetValveTimes(S.RewardAmount,1); % [s]
S.PostRewardTime = 0.1;                             % [s]

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    fprintf('\nTrial %d: ',currentTrial)
    sma = NewStateMachine();
    sma = AddState(sma, ...
        'Name',                  'Wait', ...
        'Timer',                 0, ...
        'StateChangeConditions', {'Port1Out', 'Reward'},...
        'OutputActions',         {});
    sma = AddState(sma, ...
     	'Name',                  'Reward', ...
        'Timer',                 S.RewardTime, ...
        'StateChangeConditions', {'Tup', 'Refractory'},...
        'OutputActions',         {'Valve',    1, ...
                                  'SoftCode', 1, ...
                                  'BNC1',     1});
    sma = AddState(sma, ...
     	'Name',                  'Refractory', ...
        'Timer',                 S.PostRewardTime, ...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions',         {'BNC1',     0});
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    % Package and save the trial's data
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.TrialSettings(currentTrial) = S;
        SaveBpodSessionData;
    end
    
    HandlePauseCondition;
    if BpodSystem.Status.BeingUsed == 0
        fprintf('\n')
        return
    end
end
