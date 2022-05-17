function StepperTest1
global BpodSystem

%% Setup
S = BpodSystem.ProtocolSettings;
if isempty(fieldnames(S))
    S.Acceleration = 1600;%intmax('int16');
    S.Speed = 1600;
    S.Degrees = 180;
end

%% Helper Functions for Stepper Commands
helper =  @(id,val) [uint8(id) typecast(int16(val),'uint8')];
deg2steps = @(deg) 3200/360*deg;

%% Configure Stepper Motor Module
ModuleWrite('Stepper1', helper('P',0))
ModuleWrite('Stepper1', helper('A',S.Acceleration))
ModuleWrite('Stepper1', helper('V',S.Speed))

%% Load Serial Messages
LoadSerialMessages('Stepper1', {helper('P',deg2steps(S.Degrees)),helper('P',0)});

%% Run State Machine
sma = NewStateMachine();
sma = AddState(sma, 'Name', 'A', ...
    'Timer', 0,...
    'StateChangeConditions', {'Stepper1_Stop', 'B'},...
    'OutputActions', {'Stepper1', 1}); 
sma = AddState(sma, 'Name', 'B', ...
    'Timer', 0,...
    'StateChangeConditions', {'Stepper1_Stop', 'A'},...
    'OutputActions', {'Stepper1', 2}); 

SendStateMatrix(sma);
RunStateMatrix;

HandlePauseCondition;
if BpodSystem.Status.BeingUsed == 0
    return
end
