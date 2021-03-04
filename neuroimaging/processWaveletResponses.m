function processWaveletResponses(figOption,verbose)
actuallyRun = 1;
if ~actuallyRun
    disp(['skipping ' mfilename])
    return
end
if ~exist('verbose','var')
    verbose = 1;
end
if exist('figOption','var')
    if ~isfield(figOption,'subj')
        figOption.subj = [];
    end
    if ~isfield(figOption,'save')
        figOption.save = 0;
    end
else
    figOption.subj = [];
    figOption.save = 0;
end


%% Define paths
subjList = {'02jp' '03sk' '04sp' '05bm' '06sb' '07bj'};
if ismac
    repoPath = '/Users/sebastienproulx/OneDrive - McGill University/dataBig';
else
    repoPath = 'C:\Users\sebas\OneDrive - McGill University\dataBig';
end
        funPath = fullfile(repoPath,'C-derived\DecodingHR\fun');
            inDirPrev  = 'c';
            inDir  = 'd';
            outDir = 'd';
%make sure everything is forward slash for mac, linux pc compatibility
for tmp = {'repoPath' 'funPath' 'inDirPrev' 'inDir' 'outDir'}
    eval([char(tmp) '(strfind(' char(tmp) ',''\''))=''/'';']);
end
clear tmp

%% Run
if actuallyRun
    for subjInd = 1:length(subjList)
        % Load data
        subj = subjList{subjInd};
        disp([subj ': loading'])
%         load(fullfile(funPath,inDir,[subj '.mat']))
        load(fullfile(funPath,inDirPrev,[subj '.mat']),'p')
        load(fullfile(funPath,inDir,[subj '_dDtrd.mat']),'dDtrd')
        d = dDtrd;
        % Run wave
        for sessInd = 1:2
            sess = ['sess' num2str(sessInd)];
            disp([subj ': processing wavelet (sess' num2str(sessInd) '/2)'])
            
            
            error('code wavelet');
            
            
            
            sz = size(d.(sess).data{1});
            frqInd = 1;
            cfs = nan([sz(1:3) length(d.(sess).data) sz(end)]);
            for i = 1:length(d.(sess).data)
                disp(['Run' num2str(i) '/' num2str(length(d.(sess).data))])
                showFig = (figOption.subj==subjInd || figOption.subj == inf) && i == 1;
                tic
                [cfsTmp,t,good,wave,wave_t,frq,waveEnergy] = getWaves(d.(sess).data{i},showFig); d.(sess).data{i} = [];
                toc
                cfs(:,:,:,i,:) = cfsTmp(:,:,:,:,frqInd);
            end
            t = permute(t,[1 2 3 5 4]);
            good = permute(good(:,:,:,:,frqInd),[1 2 3 5 4]);
            wave = permute(wave,[1 2 3 5 4]);
            wave_t = permute(wave_t,[1 2 3 5 4]);
            frq = permute(frq(:,:,:,:,frqInd),[1 2 3 5 4]);
            
            
            
            
            res.(sess) = runGLMs(d.fun(1,sessInd),p,0);
%             dDtrd.(sess) = rmfield(d.fun(sessInd),{'data' 'design' 'extraRegr'});
%             dDtrd.(sess).data = res.(sess).dataDtrd;
%             res.(sess) = rmfield(res.(sess),'dataDtrd');
        end
        % Save
        disp([subj ': saving responses'])
        if ~exist(fullfile(funPath,outDir),'dir')
            mkdir(fullfile(funPath,outDir))
        end
        save(fullfile(funPath,outDir,[subj '.mat']),'res')
        clear res
        disp([subj ': saving detrended data'])
        if ~exist(fullfile(funPath,outDir),'dir')
            mkdir(fullfile(funPath,outDir))
        end
        save(fullfile(funPath,outDir,[subj '_dDtrd.mat']),'dDtrd')
        clear dDtrd
        disp([subj ': saved to ''' fullfile(funPath,outDir) ''''])
    end
end


function [cfs,t,good,wave,wave_t,frq,waveEnergy] = getWaves(data,verbose)
if ~exist('verbose','var')
    verbose = 0;
end

% Prep
data = permute(data,[4 1 2 3]);
sz = size(data);
t = (0:sz(1)-1)';

stimPeriod = 12;
Fs = 1;
n = length(t);
fb = cwtfilterbank('SignalLength',n,'SamplingFrequency',Fs,...
    'FrequencyLimits',[1 2].*1/stimPeriod,...
    'VoicesPerOctave',4,...
    'Wavelet','Morse',...
    'TimeBandwidth',4);
voxInd=1;
[~,frq,coi,~,~] = cwt(data(:,voxInd),'filterbank',fb);
[~,b] = min(abs(frq-1/stimPeriod));
bFund = b(1);
[~,b] = min(abs(frq-1/stimPeriod*2));
bMod = b(1);
frq = frq([bFund bMod],:);
good = true([length(frq) sz(1)]);
for i = 1:size(good,1)
    good(i,t>=interp1(coi(end/4*3:end),t(end/4*3:end),frq(i))) = false;
    good(i,t<=interp1(coi(1:end/4),t(1:end/4),frq(i))) = false;
end

% Wavelet decomposition
cfs = nan([2 sz]);
parfor voxInd = 1:prod(sz(2:end))
    [cfsTmp,~,~,~,~] = cwt(data(:,voxInd),'filterbank',fb);
    cfs(:,:,voxInd) = cfsTmp([bFund bMod],:);
end
%rotate time series
if verbose
    figure('WindowStyle','docked');
    subplot(2,1,1)
    plot(t,angle(mean(cfs(1,:,:),3))); hold on
    ylabel('delay (rad)')
    subplot(2,1,2)
    plot(t,abs(mean(cfs(1,:,:),3))); hold on
    ylabel('amplitude (BOLD)')
    xlabel('time (sec)')
    legend({'raw' 'rotated'})
end
theta = wrapToPi(angle(cfs) - (t/stimPeriod*2*pi)');
rho = abs(cfs);
[u,v] = pol2cart(theta,rho); clear theta rho
cfs = complex(u,v);
if verbose
    subplot(2,1,1)
    plot(t,angle(mean(cfs(1,:,:),3))); hold on
    subplot(2,1,2)
    plot(t,abs(mean(cfs(1,:,:),3))); hold on
end


cfs = permute(cfs,[3 4 5 2 1]);
frq = permute(frq,[2 3 4 5 1]);
good = permute(good,[3 4 5 2 1]);
t = permute(t,[2 3 4 1 5]);

% Wavelet info
fac = 100;
fb = cwtfilterbank('SignalLength',n*fac,'SamplingFrequency',Fs*fac,...
    'FrequencyLimits',[1 2].*1/stimPeriod,...
    'VoicesPerOctave',4,...
    'Wavelet','Morse',...
    'TimeBandwidth',4);
%wavelet time-domain profile
[wave,wave_t] = wavelets(fb);
wave = permute(wave([bFund bMod],:),[3 4 5 2 1]);
wave_t = permute(wave_t,[3 4 5 2 1]);
spsi = waveletsupport(fb,0.3e-4);
ind = wave_t>=spsi(bFund,:).Begin & wave_t<=spsi(bFund,:).End;
wave_t = wave_t(ind);
wave = wave(ind);
%wavelet time-domain energy at stimulus period
thresh = 0.02:0.0001:0.021;
TimeSupport = nan([1 length(thresh)]);
for i = 1:length(thresh)
    spsi = waveletsupport(fb,thresh(i));
    TimeSupport(:,i) = spsi(bFund,:).TimeSupport;
end
[~,bb] = min(abs(TimeSupport-stimPeriod));
waveEnergy = (1-2*thresh(bb))*100;


