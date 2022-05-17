function plot_responses()

global BpodSystem

persistent hfig
if isempty(hfig) || ~isvalid(hfig)
    hfig = figure(...
        'Name','Results', ...
        'NumberTitle','Off',...
        'ToolBar','none', ...
        'MenuBar','none');
end
if numel(hfig.Children)
    hax = hfig.Children(1);
else
    hax = axes;
end

tPress = nan(1,numel(BpodSystem.Data.RawEvents.Trial));
for ii = 1:numel(tPress)
    if isfield(BpodSystem.Data.RawEvents.Trial{ii}.Events,'Button1_Press')
        tPress(ii) = BpodSystem.Data.RawEvents.Trial{ii}.Events.Button1_Press(1);
    end
end

s = BpodSystem.Data.TrialSettings(1);
r = linspace(s.Baseline,s.Amplitude+s.Baseline,s.SamplingRateOut*s.Duration/1000);
t = linspace(0,s.Duration/1000,s.SamplingRateOut*s.Duration/1000);
tempPress = (tPress/(s.Duration/1000))*s.Amplitude+s.Baseline;

histogram(hax,tempPress,(0:.5:s.Amplitude)+s.Baseline);
xlim(hax,sort([s.Amplitude+s.Baseline s.Baseline]))
xlabel(hax,'temperature [°C]')
ylabel(hax,'count')
m = nanmedian(tempPress);
if ~isnan(m)
    xline(hax,m);
end
for ii = 1:numel(tPress)
    if ~isnan(tPress(ii))
        xline(hax,tPress(ii));
    end
end

m = nanmedian(tempPress);
title(hax,sprintf('Trial %d/%d, Median: %0.2f°C',...
    BpodSystem.Data.nTrials,BpodSystem.Data.TrialSettings(1).nTrials,m))