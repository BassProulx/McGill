function groupAna(p,figOption,verbose)
if ~exist('verbose','var')
    verbose = 1;
end
if ~exist('figOption','var') || isempty(figOption)
    figOption.save = 0;
    figOption.subj = 1; % 'all' or subjInd
end
lw = 1.5;

%% Define paths
subjList = {'02jp' '03sk' '04sp' '05bm' '06sb' '07bj'};
if ismac
    repoPath = '/Users/sebastienproulx/OneDrive - McGill University/dataBig';
else
    repoPath = 'C:\Users\sebas\OneDrive - McGill University\dataBig';
end
        funPath = fullfile(repoPath,'C-derived\DecodingHR\fun');
            inDir  = 'd';
%make sure everything is forward slash for mac, linux pc compatibility
for tmp = {'repoPath' 'funPath' 'inDir'}
    eval([char(tmp) '(strfind(' char(tmp) ',''\''))=''/'';']);
end
clear tmp


%% Load data
dAll = cell(size(subjList,2),1);
for subjInd = 1:size(subjList,2)
    subj = subjList{subjInd};
    curFile = fullfile(funPath,inDir,[subj '.mat']);
    if verbose; disp(['loading: ' curFile]); end
    load(curFile,'res')
    dAll{subjInd} = res; clear res
end
d = dAll; clear dAll
% load featSel2
curFile = fullfile(funPath,inDir,'featSel.mat');
load(curFile,'featSel2');
for subjInd = 1:size(subjList,2)
    for sessInd = 1:2
        sess = ['sess' num2str(sessInd)];
        d{subjInd}.(sess).featSel2 = featSel2{subjInd,sessInd}; featSel2{subjInd,sessInd} = {};
    end
end
clear featSel2



x.sin = nan(length(subjList),3,1,2);
x.hr = nan(length(subjList),3,12,2);
for subjInd = 1:length(subjList)
    for sessInd = 1:2
        %% Average "feature-"selected voxels
        sess = ['sess' num2str(sessInd)];
        sessFeat = ['sess' num2str(~(sessInd-1)+1)];
        indIn = d{subjInd}.(sessFeat).featSel2.indIn;
        
%         ind = true(size(d{subjInd}.(sess).sin,1),1);
%         % activated voxels
%         ind = ind & d{subjInd}.(sessFeat).featSel.F.act.p < p.act.threshVal;
%         % non vein activated voxels
%         veinMap = mean(d{subjInd}.(sessFeat).featSel.vein.map(:,:),2);
%         ind = ind & veinMap<prctile(veinMap(ind),100-p.vein.percentile);
        
        xSin = mean(d{subjInd}.(sess).sin(indIn,:,:,:,:,:),1);
        xHr = mean(d{subjInd}.(sess).hr(indIn,:,:,:,:,:),1);
        
        %% Subtract base from hr
        xHr = xHr - mean(xHr,6);
        
        %% Average runs
        x.sin(subjInd,:,:,sessInd) = mean(xSin,4);
        x.hr(subjInd,:,:,sessInd) = mean(xHr,4);
    end
end
x.info = 'subj x cond[grat1,grat2,plaid] x time x sess';

%% Plot response vectors
sinRespPlot(x,figOption);

%% Plot response time courses
hrPlot(x,figOption)

%% Stats
sinRespStats(x);

function hrPlot(x,figOption)
% Average sessions
x.hr = mean(x.hr,4);
% Remove random subject effet
[x.hr] = normHr(x);

t = (1:size(x.hr,3))-1;
% offset = mean(x.hr(:));
figure('WindowStyle','docked');
for condInd = 1:size(x.hr,2)
    y = squeeze(x.hr(:,condInd,:));
%     y = y-yBase;
%     h1 = plot(t,y); hold on
%     h2 = plot(t,repmat(yBase,size(t))); hold on
%     for i = 1:length(h1)
%         h2(i).Color = h1(i).Color;
%     end
    yMean = mean(y,1);
    yErr = std(y,[],1)./sqrt(size(y,1));
    hErr(condInd) = errorbar(t,yMean,yErr); hold on
end
set(hErr,'CapSize',0)
xlabel('time from stimulus onset (sec)')
ylabel('%BOLD change')
hLeg = legend({'grat1' 'grat2' 'plaid'});
hLeg.Box = 'off';
grid on



function sinRespPlot(x,figOption)
colors = [  0         0.4470    0.7410
            0.8500    0.3250    0.0980
            0.9290    0.6940    0.1250];
% Average sessions
x.sin = mean(x.sin,4);
% Remove subject effect
theta = wrapToPi(angle(x.sin) - angle(mean(x.sin(:,:),2)) + angle(mean(x.sin(:))));
rho = abs(x.sin) ./ abs(mean(x.sin(:,:),2)) .* abs(mean(x.sin(:)));
[u,v] = pol2cart(theta,rho);
x.sin = complex(u,v);

% Scatters
fGroup(1) = figure('WindowStyle','docked');
subplot(2,1,1)
for condInd = 1:3
    h(condInd) = polarplot(angle(x.sin(:,condInd)),abs(x.sin(:,condInd)),'o'); hold on
    h(condInd).Color = colors(condInd,:);
    hM(condInd) = polarplot(angle(mean(x.sin(:,condInd),1)),abs(mean(x.sin(:,condInd),1)),'o'); hold on
    hM(condInd).Color = colors(condInd,:);
    hM(condInd).MarkerFaceColor = colors(condInd,:);
    hM(condInd).MarkerEdgeColor = 'w';
end
set(h,'Marker','.')
set(hM,'MarkerEdgeColor','auto')
set(hM,'MarkerFaceColor','w')
set(hM,'LineWidth',2)
uistack(hM,'top')
hl = legend(char({'grat1' 'grat2' 'plaid'}),'Location','east');
hl.Color = 'none';
hl.Box = 'off';
title('Group Response (subject effect removed)')
ax = gca;
ax.ThetaTickLabel = 12-ax.ThetaTick(1:end)/360*12;
ax.ThetaTickLabel(1,:) = '0 ';
ax.ThetaAxis.Label.String = {'delay' '(sec)'};
ax.ThetaAxis.Label.Rotation = 0;
ax.ThetaAxis.Label.HorizontalAlignment = 'left';
ax.RAxis.Label.String = 'amp (%BOLD)';
ax.RAxis.Label.Rotation = 80;

subplot(2,1,2)
for condInd = 1:3
    h(condInd) = scatter(real(x.sin(:,condInd)),imag(x.sin(:,condInd)),'.'); hold on
    h(condInd).CData = colors(condInd,:);
    hM(condInd) = scatter(real(mean(x.sin(:,condInd),1)),imag(mean(x.sin(:,condInd),1)),'o'); hold on
    hM(condInd).CData = colors(condInd,:);
    hM(condInd).MarkerFaceColor = 'w';
    hM(condInd).MarkerEdgeColor = colors(condInd,:);
end
set(hM,'LineWidth',2)
ax = gca;
ax.PlotBoxAspectRatio = [1 1 1];
ax.DataAspectRatio = [1 1 1];

if figOption.save
    error('double-check that')
    filename = fullfile(pwd,mfilename);
    if ~exist(filename,'dir'); mkdir(filename); end
    filename = fullfile(filename,'cartesian');
    fGroup(1).Color = 'none';
    set(findobj(fGroup(1).Children,'type','Axes'),'color','none')
    set(findobj(fGroup(1).Children,'type','PolarAxes'),'color','none')
    curFile = filename;
    curExt = 'svg';
    saveas(fGroup(1),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
    fGroup(1).Color = 'w';
    curExt = 'fig';
    saveas(fGroup(1),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
    curExt = 'jpg';
    saveas(fGroup(1),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
end

% Bars
fGroup(2) = figure('WindowStyle','docked'); clear hB hErr
for condInd = 1:3
    hB(condInd) = bar(condInd,abs(mean(x.sin(:,condInd),1))); hold on
    hB(condInd).FaceColor = colors(condInd,:);
    hErr(condInd) = errorbar(condInd,abs(mean(x.sin(:,condInd),1)),std(abs(x.sin(:,condInd)),[],1)); hold on
    hErr(condInd).LineStyle = 'none';
    hErr(condInd).Marker = 'none';
    hErr(condInd).Color = 'k';
end
ax = gca;
ylabel({'Response amplitude' '(%BOLD)'})
ax.XTick = 1:3;
ax.XTickLabel = {'grat1' 'grat2' 'plaid'};
f = gcf;
f.Color = 'w';
box off
amp = [hB.YData];
disp('***')
disp(['amp (plaid-grat) = ' num2str(amp(3)-mean(amp(1:2)),'%0.3f%%BOLD')])
disp(['amp (grat2-grat1) = ' num2str(amp(2)-amp(1),'%0.3f%%BOLD')])
disp('***')

fGroup(3) = figure('WindowStyle','docked'); clear hB hErr
for condInd = 1:3
    hB(condInd) = barh(condInd,mean(rad2sec(angle(x.sin(:,condInd))),1)); hold on
    hB(condInd).FaceColor = colors(condInd,:);
    hErr(condInd) = errorbar(mean(rad2sec(angle(x.sin(:,condInd))),1),condInd,[],[],std(rad2sec(angle(x.sin(:,condInd))),[],1),std(rad2sec(angle(x.sin(:,condInd))),[],1)); hold on
    hErr(condInd).LineStyle = 'none';
    hErr(condInd).Marker = 'none';
    hErr(condInd).Color = 'k';
end
ax = gca;
xlabel({'Response delay' '(sec)'})
ax.YTick = 1:3;
ax.YTickLabel = {'grat1' 'grat2' 'plaid'};
f = gcf;
f.Color = 'w';
box off
delay = [hB.YData];
hTxt = text(0,hB(3).XData+hB(3).BarWidth/2,['plaid-grat = ' num2str(delay(3)-mean(delay(1:2)),'%0.3fsec')],'VerticalAlignment','bottom');
disp('***')
disp(['delay (plaid-grat) = ' num2str(delay(3)-mean(delay(1:2)),'%0.3fs')])
disp(['delay (ori2-ori1) = ' num2str(delay(2)-delay(1),'%0.3fs')])
disp('***')

if figOption.save
    error('double-check that')
    filename = fullfile(pwd,mfilename);
    if ~exist(filename,'dir'); mkdir(filename); end
    filename = fullfile(filename,'amp');
    fGroup(2).Color = 'none';
    set(findobj(fGroup(2).Children,'type','Axes'),'color','none')
    curFile = filename;
    curExt = 'svg';
    saveas(fGroup(2),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
    fGroup(2).Color = 'w';
    curExt = 'fig';
    saveas(fGroup(2),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
    curExt = 'jpg';
    saveas(fGroup(2),[curFile '.' curExt]); if verbose; disp([curFile '.' curExt]); end
end

function thetaSec = rad2sec(thetaRad)
thetaSec = -thetaRad/pi*6;

function sinRespStats(x)
% Average sessions
x.sin = mean(x.sin,4);
% Center delay
theta = wrapToPi(angle(x.sin)-angle(mean(x.sin(:))));
rho = abs(x.sin);
[u,v] = pol2cart(theta,rho);
x.sin = complex(u,v);

% Stats on 2D response vector (conservative)
disp('---------------')
disp('2D Response Vector')
disp('---------------')
disp('Grat vs Plaid:')
X = cat(1,mean(x.sin(:,1:2),2),x.sin(:,3));
stats = T2Hot2d([real(X) imag(X)],0.05);
disp('Hotelling''s T^2 multivariate test')
disp([' T^2=' num2str(stats.T2,'%0.2f')]);
disp([' p=' num2str(stats.P,'%0.2f')]);
disp('Ori1 vs Ori2:')
X = cat(1,x.sin(:,1),x.sin(:,2));
stats = T2Hot2d([real(X) imag(X)],0.05);
disp(' Hotelling''s T^2 multivariate test')
disp([' T^2=' num2str(stats.T2,'%0.2f') '; p=' num2str(stats.P,'%0.2f')]);


disp('---------------')
disp('Amplitude')
disp('---------------')

disp('Ori1 vs Ori2 vs Plaid (Friedman''s test for K-related-samples):')
[P,TABLE,~] = friedman(abs(x.sin(:,1:3)),1,'off');
disp(['Chi^2(df=3' num2str(TABLE{2,3}) ') = ' num2str(TABLE{2,5},'%0.1f')]);
disp(['p            = ' num2str(P,'%0.3f')]);

disp('Grat vs Plaid (one-tailed):')
X = abs(mean(x.sin(:,1:2),2)); Y = abs(x.sin(:,3));
[~,P,~,STATS] = ttest(X,Y,'tail','right');
disp(' Student''s t-test')
disp([' t=' num2str(STATS.tstat,'%0.2f') '; one-sided p=' num2str(P,'%0.2f')]);
[P,~,STATS] = signrank(X,Y,'tail','right');
disp(' Wilcoxon signed rank test')
disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; one-sided p=' num2str(P,'%0.2f')]);
disp('Ori1 vs Ori2:')
X = abs(x.sin(:,1)); Y = abs(x.sin(:,2));
[~,P,~,STATS] = ttest(X,Y);
disp(' Student''s t-test')
disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
[P,~,STATS] = signrank(X,Y);
disp(' Wilcoxon signed rank test')
disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);

allPairs = [1 2; 1 3; 2 3];
P = nan(size(allPairs,1),1);
sRank = nan(size(allPairs,1),1);
for pairInd = 1:size(allPairs,1)
    X = abs(x.sin(:,allPairs(pairInd,1))); Y = abs(x.sin(:,allPairs(pairInd,2)));
    [P(pairInd),~,STATS] = signrank(X,Y);
    sRank(pairInd) = STATS.signedrank;
end



disp('---------------')
disp('Delay')
disp('---------------')

disp('Ori1 vs Ori2 vs Plaid (Friedman''s test for K-related-samples):')
[P,TABLE,~] = friedman(angle(x.sin(:,1:3)),1,'off');
disp(['Chi^2(df=3' num2str(TABLE{2,3}) ') = ' num2str(TABLE{2,5},'%0.1f')]);
disp(['p            = ' num2str(P,'%0.3f')]);

disp('Grat vs Plaid (one-tailed):')
X = angle(mean(x.sin(:,1:2),2)); Y = angle(x.sin(:,3));
[~,P,~,STATS] = ttest(X,Y,'tail','right');
disp(' Student''s t-test')
disp([' t=' num2str(STATS.tstat,'%0.2f') '; one-sided p=' num2str(P,'%0.2f')]);
[P,~,STATS] = signrank(X,Y,'tail','right');
disp(' Wilcoxon signed rank test')
disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; one-sided p=' num2str(P,'%0.2f')]);
disp('Ori1 vs Ori2:')
X = angle(x.sin(:,1)); Y = angle(x.sin(:,2));
[~,P,~,STATS] = ttest(X,Y);
disp(' Student''s t-test')
disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
[P,~,STATS] = signrank(X,Y);
disp(' Wilcoxon signed rank test')
disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);

allPairs = [1 2; 1 3; 2 3];
P = nan(size(allPairs,1),1);
sRank = nan(size(allPairs,1),1);
for pairInd = 1:size(allPairs,1)
    X = angle(x.sin(:,allPairs(pairInd,1))); Y = angle(x.sin(:,allPairs(pairInd,2)));
    [P(pairInd),~,STATS] = signrank(X,Y);
    sRank(pairInd) = STATS.signedrank;
end



function [hr,thetaShift,rhoScale] = normHr(x)
interpMethod = 'cubic'; % cubic convolution as implemented in Matlab2020b
rhoGroup = abs(mean(x.sin(:)));
thetaGroup = angle(mean(x.sin(:)));
tPts = 12;
deltaSec = 1;
tSec = linspace(0,(tPts-1)*deltaSec,tPts);
deltaSec2 = 0.001;
tPts2 = tPts*(deltaSec/deltaSec2);
tSec2 = linspace(0,(tPts2-1)*deltaSec2,tPts2);

deltaRad2 = deltaSec2/(tPts2*deltaSec2)*2*pi;

hr = nan(size(x.hr));
ind = 1:size(tSec,2);
indPreppend = size(tSec,2)/2:size(tSec,2);
indAppend = 1:size(tSec,2)/2;
tSecPreppend = -length(indPreppend)*deltaSec:deltaSec:tSec(1)-deltaSec;
tSecAppend = tSec(end)+deltaSec:deltaSec:tSec(end)+length(indAppend)*deltaSec;
indPreppend2 = size(tSec2,2)/2:size(tSec2,2);
indAppend2 = 1:size(tSec2,2)/2;
tSecPreppend2 = -length(indPreppend2)*deltaSec2:deltaSec2:tSec2(1)-deltaSec2;
tSecAppend2 = tSec2(end)+deltaSec2:deltaSec2:tSec2(end)+length(indAppend2)*deltaSec2;
thetaShift = nan(size(x.sin,1),1);
rhoScale = nan(size(x.sin,1),1);
for subjInd = 1:size(x.sin,1)
    curSin = x.sin(subjInd,:,:,:);
    curSin = mean(curSin,4);
    curHr = permute(x.hr(subjInd,:,:,:),[3 2 4 1]);
    thetaShift(subjInd) = -( thetaGroup-angle(mean(curSin,2)) );
    rhoScale(subjInd) = abs(mean(curSin,2)) .*rhoGroup;
    for i = 1:prod(size(curHr,[2 3]))
        % Upsample
        tmp2 = interp1([tSecPreppend tSec tSecAppend],curHr([indPreppend ind indAppend],i),[tSecPreppend2 tSec2 tSecAppend2],interpMethod);
        % Rotate
        tmp2 = circshift(tmp2,round(thetaShift(subjInd)./deltaRad2));
        % Scale
        tmp2 = tmp2./rhoScale(subjInd);
        % Downsample
        tmp = interp1([tSecPreppend2 tSec2 tSecAppend2],tmp2,[tSecPreppend tSec tSecAppend],interpMethod);
        curHr(:,i) = tmp(length(tSecPreppend)+1:length([tSecPreppend tSec]));
    end
    hr(subjInd,:,:,:) = permute(curHr,[4 2 1 3]);
end








% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 

% %% Stats
% xDataMean = mean(xData(:));
% 
% amp = abs(xData);
% delay = angle(xData);
% delay = wrapToPi(delay - angle(xDataMean));
% % delay = -(delay + angle(Xmean))/pi*6;
% 
% 
% % On cartesian space (conservative)
% disp('---------------')
% disp('Cartesian Space')
% disp('---------------')
% disp('Ori vs Plaid:')
% X = cat(1,xData(:,4),xData(:,3));
% stats = T2Hot2d([real(X) imag(X)],0.05);
% disp('Hotelling''s T^2 multivariate test')
% disp([' T^2=' num2str(stats.T2,'%0.2f')]);
% disp([' p=' num2str(stats.P,'%0.2f')]);
% disp('Ori1 vs Ori2:')
% X = cat(1,xData(:,1),xData(:,2));
% stats = T2Hot2d([real(X) imag(X)],0.05);
% disp(' Hotelling''s T^2 multivariate test')
% disp([' T^2=' num2str(stats.T2,'%0.2f') '; p=' num2str(stats.P,'%0.2f')]);
% 
% % Amplitude in polar space
% disp('---------------')
% disp('Polar Amplitude')
% disp('---------------')
% disp('Ori vs Plaid (one-tailed):')
% x = amp(:,4); y = amp(:,3);
% [H,P,CI,STATS] = ttest(x,y,'tail','right');
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y,'tail','right');
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% disp('Ori1 vs Ori2:')
% x = amp(:,1); y = amp(:,2);
% [H,P,CI,STATS] = ttest(x,y);
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y);
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% 
% disp('Ori1 vs Ori2 vs Plaid (Friedman''s test for K-related-samples):')
% [P,TABLE,~] = friedman(amp(:,1:3),1,'off');
% disp(['Chi^2(df=3' num2str(TABLE{2,3}) ') = ' num2str(TABLE{2,5},'%0.1f')]);
% disp(['p            = ' num2str(P,'%0.3f')]);
% 
% 
% % Compare delays
% disp('-----------')
% disp('Polar Delay')
% disp('-----------')
% disp('Ori vs Plaid (one-tail):')
% x = delay(:,4); y = delay(:,3);
% [H,P,CI,STATS] = ttest(x,y,'tail','right');
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y,'tail','right');
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,F] = circ_htest(x,y);
% disp(' Hotelling''s test for angular means')
% disp([' F=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P/2,'%0.2f')]);
% disp('Ori1 vs Ori2:')
% x = delay(:,1); y = delay(:,2);
% [H,P,CI,STATS] = ttest(x,y);
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y);
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,F] = circ_htest(x,y);
% disp(' Hotelling''s test for angular means')
% disp([' F=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% 
% disp('Ori1 vs Plaid (one-tail):')
% x = delay(:,1); y = delay(:,3);
% [H,P,CI,STATS] = ttest(x,y,'tail','right');
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y,'tail','right');
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,F] = circ_htest(x,y);
% disp(' Hotelling''s test for angular means')
% disp([' F=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P/2,'%0.2f')]);
% 
% disp('Ori2 vs Plaid (one-tail):')
% x = delay(:,2); y = delay(:,3);
% [H,P,CI,STATS] = ttest(x,y,'tail','right');
% disp(' Student''s t-test')
% disp([' t=' num2str(STATS.tstat,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,H,STATS] = signrank(x,y,'tail','right');
% disp(' Wilcoxon signed rank test')
% disp([' signed rank=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P,'%0.2f')]);
% [P,F] = circ_htest(x,y);
% disp(' Hotelling''s test for angular means')
% disp([' F=' num2str(STATS.signedrank,'%0.2f') '; p=' num2str(P/2,'%0.2f')]);
% 
% disp('Ori1 vs Ori2 vs Plais (Friedman''s test for K-related-samples):')
% [P,TABLE,~] = friedman(delay(:,1:3),1,'off');
% disp(['Chi^2(df=3' num2str(TABLE{2,3}) ') = ' num2str(TABLE{2,5},'%0.1f')]);
% disp(['p            = ' num2str(P,'%0.3f')]);
% 
% 
% %% Correlations
% % Between-subject correlation
% xData = [];
% xLabel = [];
% for subjInd = 1:length(subjList)
%     for sessInd = 1:2
% 
%         tmp = squeeze(d{subjInd}.(['sess' num2str(sessInd)]).sin);
%         tmp = mean(tmp,1);
%         xData = cat(1,xData,tmp);
%         sz = size(tmp);
%         xLabel = cat(1,xLabel,[ones(sz(1),1).*subjInd ones(sz(1),1).*sessInd]);
%     end
% %     xData = cat(1,xData(1:end-2,:),mean(xData(end-1:end,:),1));
% %     xLabel = cat(1,xLabel(1:end-2,:),xLabel(end,:));
% end
% xData = cat(2,mean(xData(:,1:2),2),xData(:,3));
% xDataMean = mean(xData(:));
% 
% amp = abs(xData);
% delay = angle(xData);
% delay = wrapToPi(delay - angle(xDataMean));
% delay = -(delay + angle(xDataMean))/pi*6;
% 
% fCorr1 = figure('WindowStyle','docked');
% x = delay(:,2)-delay(:,1);
% y = amp(:,2) - amp(:,1);
% hScat = scatter(x,y);
% [R,P] = corr(x,y,'type','Pearson','tail','left');
% xlabel('delay (plaid - ori) in sec')
% ylabel('amp (plaid - ori)')
% refFit = polyfit(x,y,1);
% title({'Subj*Sess' ['Pearson''s R=' num2str(R,'%0.2f') '; one-tailed p=' num2str(P,'%0.3f') '; slope=' num2str(refFit(1),'%0.2f')]})
% refline
% set(gca,'PlotBoxAspectRatio',[1 1 1])
% 
% xLabel = xLabel(:,1);
% cMap = jet(length(subjList));
% cData = nan(length(x),3);
% for subjInd = 1:length(subjList)
%     cData(xLabel==subjInd,:) = repmat(cMap(subjInd,:),[sum(xLabel==subjInd) 1]);
% end
% hScat.CData = cData;
% hScat.MarkerFaceColor = hScat.MarkerEdgeColor;
% 
% if figOption.save
%     writeFig(fCorr1,mfilename,'diffCorr_subjAndSess',verbose)
% end
% 
% 
% %average sessions
% fCorr2 = figure('WindowStyle','docked');
% delay = mean(cat(3,delay(1:2:end,:),delay(2:2:end,:)),3);
% amp = mean(cat(3,amp(1:2:end,:),amp(2:2:end,:)),3);
% x = delay(:,2)-delay(:,1);
% y = amp(:,2) - amp(:,1);
% hScat = scatter(x,y);
% [R,P] = corr(x,y,'type','Spearman','tail','left');
% xlabel('delay (plaid - ori) in sec')
% ylabel('amp (plaid - ori)')
% refFit = polyfit(x,y,1);
% title({'Subj*Sess' ['Spearman''s R=' num2str(R,'%0.2f') '; one-tailed p=' num2str(P,'%0.3f') '; slope=' num2str(refFit(1),'%0.2f')]})
% refline
% set(gca,'PlotBoxAspectRatio',[1 1 1])
% hScat.MarkerFaceColor = 'k';
% hScat.MarkerEdgeColor = 'w';
% 
% if figOption.save
%     writeFig(fCorr2,mfilename,'diffCorr_subj',verbose)
% end
% 
% % Between-run correlation
% %get grand mean
% xData = [];
% for subjInd = 1:length(subjList)
%     for sessInd = 1:2
%         for condInd = 1:3
%             tmp = squeeze(d{subjInd}.(['sess' num2str(sessInd)]).sin);
%             xData = [xData; tmp(:)];
%         end
%     end
% end
% xDataMean = mean(xData);
% %remove subject*sess*cond effects
% xData = [];
% for subjInd = 1:length(subjList)
%     for sessInd = 1:2
%         for condInd = 1:3
%             tmp = squeeze(d{subjInd}.(['sess' num2str(sessInd)]).sin);
%             tmp = tmp - mean(tmp,1) + xDataMean;
%             xData = [xData; tmp(:)];
%         end
%     end
% end
% amp = abs(xData);
% delay = wrapToPi(angle(xData) - angle(xDataMean));
% delay = -delay/pi*6;
% delay = delay + (-angle(xDataMean)/pi*6);
% 
% 
% fCorr3 = figure('WindowStyle','docked');
% x = delay;
% y = amp;
% hScat = scatter(x,y);
% [R,P] = corr(x,y,'tail','left');
% xlabel('delay (sec)')
% ylabel('amp (%BOLD)')
% refFit = polyfit(x,y,1);
% title({'Individual Runs, subj*sess*cond effect removed' ['Pearson''s R=' num2str(R,'%0.2f') '; one-tailed p=' num2str(P,'%0.3f') '; slope=' num2str(refFit(1),'%0.2f')]})
% refline;
% hScat.SizeData = hScat.SizeData/4;
% hScat.MarkerFaceColor = 'k';
% hScat.MarkerEdgeColor = 'w';
% set(gca,'PlotBoxAspectRatio',[1 1 1])
% 
% if figOption.save
%     writeFig(fCorr3,mfilename,'run2runCorr',verbose)
% end
% 
% %% Reorder for notebook
% fList = [fGroup([1 3 2]) fCorr1 fCorr2 fCorr3]';
% delete(fList(4))
% if ~verbose
%     fList(4) = [];
% end
% set(0,'Children',flipud(fList))



