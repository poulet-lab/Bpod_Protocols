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

t0 = cellfun(@(x) x.Events.WavePlayer1_1(1),BpodSystem.Data.RawEvents.Trial);
t1 = cellfun(@(x) x.Events.WavePlayer1_1(2),BpodSystem.Data.RawEvents.Trial);
tPress = nan(1,numel(BpodSystem.Data.RawEvents.Trial));
for ii = 1:numel(tPress)
    if isfield(BpodSystem.Data.RawEvents.Trial{ii}.Events,'Button1_Press')
        tmp = BpodSystem.Data.RawEvents.Trial{ii}.Events.Button1_Press;
        idx = find(tmp>t0(ii) & tmp<t1(ii),1);
        if ~isempty(idx)
            tPress(ii) = tmp(idx);
        end
    end
end

histogram(hax,tPress-t0,0:.1:round(max(t1-t0)));
xlim(hax,[0 round(max(t1-t0))])
xlabel(hax,'time relative to onset [s]')
ylabel(hax,'count')
m = nanmedian(tPress-t0);
if ~isnan(m)
    xline(hax,m);
end
title(hax,sprintf('Trial %d/%d, Hits: %d/%d (%0.0f%%), Median Latency: %0.2fs',...
    BpodSystem.Data.nTrials,BpodSystem.Data.TrialSettings(1).nTrials,...
    sum(~isnan(tPress)),numel(tPress),sum(~isnan(tPress))/numel(tPress)*100,m))