clear all
close all

dataRepo_in = 'C:\Users\sebas\OneDrive - McGill University\dataBig';
dataRepo_out = dataRepo_out;
dataDir = 'C-derived\DecodingHR';
dataLevel = 'z';
fileList = {'02jp_sess1' '03sk_sess1' '04sp_sess1' '05bm_sess1' '06sb_sess1' '07bj_sess1';...
            '02jp_sess2' '03sk_sess2' '04sp_sess2' '05bm_sess2' '06sb_sess2' '07bj_sess2'}';
fileList


% Load complex numbers representing the sinusoidal response
data = loadData(dataRepo,dataDir,dataLevel,fileList)
data.ori1

% Average voxels in cartesian space
dataP = avVox(data);
dataP.ori1
rLim = getRlim(dataP);

% Plot single subjects
plotSubj(dataP,1,1);
% for subjInd = 1:6
%     plotSubj(dataP,subjInd,1,rLim);
%     plotSubj(dataP,subjInd,2,rLim);
% end

% % Remove session effects (in cartesian space)
% sessMeans = mean(getSessMeans(dataP),1);
% subjMeans = mean(sessMeans,3);
% condList = fields(dataP);
% for condInd = 1:length(condList)
%     for subjInd = 1:6
%         for sessInd = 1:2
%             dataP.(condList{condInd}){subjInd,sessInd} = dataP.(condList{condInd}){subjInd,sessInd} - sessMeans(:,subjInd,sessInd);
%             dataP.(condList{condInd}){subjInd,sessInd} = dataP.(condList{condInd}){subjInd,sessInd} + subjMeans(:,subjInd);
%         end
%     end
% end

% % Plot single subjects
% for subjInd = 1:6
%     plotSubj(dataP,subjInd,1,rLim);
%     plotSubj(dataP,subjInd,2,rLim);
% end

% Get session means (in cartesian space)
sessMeans = getSessMeans(dataP); % cond[ori1 ori2 plaid ori] x subj x sess

% Get subject means in cartesian space then move to polar space
subjMeans = mean(sessMeans,3);

% Move to polar space
subjMeans_theta = angle(subjMeans);
subjMeans_rho = abs(subjMeans);


% Compare amplitudes
condInd = 4; % 1; 2; [1 2];
disp('amplitude')
[H,P,CI,STATS] = ttest(mean(subjMeans_rho(condInd,:),1),subjMeans_rho(3,:));
[STATS.tstat P]
[P,H,STATS] = signrank(mean(subjMeans_rho(condInd,:),1),subjMeans_rho(3,:));
[STATS.signedrank P]
% Compare delays
disp('delay')
[H,P,CI,STATS] = ttest(mean(subjMeans_theta(condInd,:),1),subjMeans_theta(3,:));
[STATS.tstat P]
[P,H,STATS] = signrank(mean(subjMeans_theta(condInd,:),1),subjMeans_theta(3,:));
[STATS.signedrank P]
[P,F] = circ_htest(mean(subjMeans_theta(condInd,:),1),subjMeans_theta(3,:));
[F P]

% 
% 
% % ori1
% %% Compare amplitudes
% disp('amplitude')
% [H,P,CI,STATS] = ttest(abs(subjMeans(1,:)),abs(subjMeans(3,:)));
% P
% [P,H,STATS] = signrank(abs(subjMeans(1,:)),abs(subjMeans(3,:)));
% P
% %% Compare delays
% disp('delay')
% [H,P,CI,STATS] = ttest(angle(subjMeans(1,:)),angle(subjMeans(3,:)));
% P
% [P,H,STATS] = signrank(angle(subjMeans(1,:)),angle(subjMeans(3,:)));
% P
% [P,F] = circ_htest(angle(subjMeans(1,:)),angle(subjMeans(3,:)));
% P
