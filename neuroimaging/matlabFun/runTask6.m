function [ output_args ] = runTask6(allFile,altPerm,altMainDir)

for taskInd = 1:length(allFile)
    clearvars -except taskInd allFile plotIt doPerm dataDirOut altPerm altMainDir
    display(['Performing ' char(allFile{taskInd})])
    load(allFile{taskInd})
    
    %% Do SVM if not already done
    stopIt = 0;
    stopThis = 0;
    if ~exist('svm','var')
        stopIt = 1;
        
        %% Load data, compile it and threshold it
        %Compile it
        switch fitType
            case 'SinCos'
                %Load mask (and brain for reference)
                a = load_nii(fullfile(dataDirIn,'run1c_masking',[maskName '.nii.gz']));
                metric.mask = flipdim(permute(a.img,[3 1 2 4]),1); clear a
                metric.mask(:,:,1) = zeros(size(metric.mask,1),size(metric.mask,2));% Remove corrupted slices
                metric.mask(:,:,end) = zeros(size(metric.mask,1),size(metric.mask,2));% Remove corrupted slices
                a = load_nii(fullfile(dataDirIn,'run1a_preprocessing','trun101_preprocessed.nii.gz'));
                metric.brain = mean(flipdim(permute(a.img,[3 1 2 4]),1),4); clear a
                
                %Load data of interest
                load(fullfile(dataDirIn,['eqSess_' upper(maskName) fitType '_' p.split '_' p.motionParam p.sm '.mat']),'results')
                
%                 %Recopute delay and amp from parameters for the mixed
%                 %designs since they were not computed correctly in
%                 %GLMsinCos.m (ok in GLMsinCos2.m)
%                 numruns = length(results.inputs.design);
%                 [results.OLS.mixed.delay, results.OLS.mixed.amp] = cart2pol(results.OLS.mixed.parameters(:,:,:,1:2:numruns*2),results.OLS.mixed.parameters(:,:,:,2:2:numruns*2));
%                 [results.OLS.mixed_sessRm.delay, results.OLS.mixed_sessRm.amp] = cart2pol(results.OLS.mixed_sessRm.parameters(:,:,:,1:2:numruns*2),results.OLS.mixed_sessRm.parameters(:,:,:,2:2:numruns*2));
                
                
                %Define some flags to extract data correctly
                ind = find(results.mask);
                switch p.preSelection
                    case 'sess1'
                        Ffield2 = 'Fcond3sess1';
%                         nReg = 2*length(results.inputs.design)/3/2;
                    case 'sess2'
                        Ffield2 = 'Fcond3sess2';
%                         nReg = 2*length(results.inputs.design)/3/2;
                    otherwise
                        error('did not program this yet')
                end
                nRuns = length(results.inputs.datasize)/3;
                nPtsPerRun = results.inputs.datasize{1}(4);
                
                %Get F values (and put it in full VOI)
                if p.regSession
                    Ffield1 = 'mixed_sessReg';
                else
                    Ffield1 = 'mixed';
                end
%                 %rescale F value because degrees of freedom were not set
%                 %correctly in GLMsinCos.m (ok in GLMsinCos2.m)
%                 Fstruct = results.OLS.(Ffield1).(Ffield2);
%                 F_orig = Fstruct.val.F;
%                 pFull = Fstruct.df.pFull;
%                 pReduced = Fstruct.df.pReduced;
%                 n = Fstruct.df.n;
%                 dfRatio_orig = (n - pFull) / (pFull - pReduced);
%                 RSSratio_orig = F_orig / dfRatio_orig;
%                 pReduced = pFull-nReg;
%                 dfRatio_new = (n - pFull) / (pFull - pReduced);
%                 RSSratio_new = RSSratio_orig;
%                 Fnew = RSSratio_new*dfRatio_new;
%                 Fstruct.val.F = Fnew;
%                 Fstruct.df.pReduced = pReduced;
%                 results.OLS.(Ffield1).(Ffield2) = Fstruct;
                
                metric.allExp.F = nan(size(metric.mask));
                metric.allExp.F(ind) = results.OLS.(Ffield1).(Ffield2).val.F;
                
                %Get amp and delay (and put it in full VOI)
                if p.regSession
                    Ffield1 = 'mixed_sessReg';
                else
                    Ffield1 = 'mixed';
                end
                for cond = 1:3
                    tmpAmp = results.OLS.(Ffield1).amp(:,:,:,1+(cond-1)*nRuns:cond*nRuns);
                    tmpDelay = results.OLS.(Ffield1).delay(:,:,:,1+(cond-1)*nRuns:cond*nRuns);
                    for run = 1:nRuns
                        tmp = nan(size(metric.mask));
                        tmp(ind) = tmpAmp(:,:,:,run);
                        metric.allRuns.amp(:,:,:,run,cond) = tmp;
                        tmp = nan(size(metric.mask));
                        tmp(ind) = tmpDelay(:,:,:,run);
                        metric.allRuns.delay(:,:,:,run,cond) = tmp;
                    end
                end
                
                %Preselect session
                switch p.preSelection
                    case 'sess1'
                        metric.allRuns.amp = metric.allRuns.amp(:,:,:,1:end/2,:);
                        metric.allRuns.delay = metric.allRuns.delay(:,:,:,1:end/2,:);
                        nRuns = nRuns/2;
                        sessionLabel = ones(1,size(metric.allRuns.amp,4));
                    case 'sess2'
                        metric.allRuns.amp = metric.allRuns.amp(:,:,:,1+end/2:end,:);
                        metric.allRuns.delay = metric.allRuns.delay(:,:,:,1+end/2:end,:);
                        nRuns = nRuns/2;
                        sessionLabel = ones(1,size(metric.allRuns.amp,4));
                    otherwise
                        error('did not program this yet')
                        sessionLabel = ones(1,size(metric.allRuns.amp,4)); %%%%%%%%%%
                end
                period = results.inputs.stimdur*2;
                clear results
                
                %Apply anatomical mask
                allFields = fields(metric); allFields(ismember(allFields, {'mask' 'brain'})) = [];
                for i = 1:length(allFields)
                    allFields2 = fields(metric.(allFields{i}));
                    for ii = 1:length(allFields2)
                        metric.(allFields{i}).(allFields2{ii})(repmat(~metric.mask,[1 1 1 size(metric.(allFields{i}).(allFields2{ii}),4)])) = nan;
                    end
                end
                
                %Define funcROI
                p.funcROI.stats = metric.allExp.F;
                
                %Make this fit the old pipeline
                metricSinCos = metric;
                metric = struct;
                        
                metric.voxInd = [];
                metric.ampRect = nan(length(find(metricSinCos.mask)),nRuns,3);
                metric.delayRect = nan(length(find(metricSinCos.mask)),nRuns,3);
                metric.funcROI.stats = nan(length(find(metricSinCos.mask)),1);
                for z = 1:size(metricSinCos.mask,3)
                    [x,y] = find(metricSinCos.mask(:,:,z));
                    metric.voxInd = [metric.voxInd; x y repmat(z,[length(x) 1])];
                end
                
                for ii = 1:size(metric.voxInd,1)
                    metric.ampRect(ii,:,:) = metricSinCos.allRuns.amp(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
                    metric.delayRect(ii,:,:) = metricSinCos.allRuns.delay(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
                    metric.funcROI.stats(ii,1) = p.funcROI.stats(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3));
                end
                
                %Sort functional ROI and put in p struct
                p.funcROI.vec.stats = metric.funcROI.stats;
                [~, p.funcROI.vec.sortInd] = sort(metric.funcROI.stats,'descend');                        
%                         metric.dataFields = fields(metric); metric.dataFields(1) = [];
% %                         metric.label = metricCompiled.label;
                %Define other stuff
                metric.sessionLabel(1,:,:) = repmat(sessionLabel',[1 3]);
                metric.fittingParam.period = period;
                
                clear metricSinCos
                
                
                
                
%                 for cond = 1:3
%                     
%                     if ~isfield(p,'split') || (~ischar(p.split) && ~p.split)
%                         load(fullfile(dataDirIn,'run1a_preprocessing',['XSinCos_' p.motionParam '_cond' num2str(cond) '.mat']),'results')
%                     elseif ischar(p.split)
%                         switch p.preSelection
%                             case {'sess1','sess2'}
%                                 
%                                 load(fullfile(dataDirIn,'run1a_preprocessing',['eqSess_' p.preSelection '_SinCos_' p.split '_' p.motionParam '_cond' num2str(cond) '.mat']),'results')
%                                 sessionLabel = ones(1,size(results.parametricRun.amp,4));
%                                 period = results.inputs.stimdur*2;
%                             case 'eqSess'
%                                 keyboard
%                                 load(fullfile(dataDirIn,'run1a_preprocessing',['eqSess_sess1_SinCos_' p.split '_' p.motionParam '_cond' num2str(cond) '.mat']),'results')
%                                 results1 = results;
%                                 load(fullfile(dataDirIn,'run1a_preprocessing',['eqSess_sess2_SinCos_' p.split '_' p.motionParam '_cond' num2str(cond) '.mat']),'results')
%                                 results2 = results;
%                                 results1
%                                 
%                                 sessionLabel = ones(1,size(results.parametricRun.amp,4));
%                                 
%                                 Fmixed1 = results1.parametricRun.Fmixed;
%                                 Fmixed2 = results2.parametricRun.Fmixed;
%                                 FmixedAll = cat(4,Fmixed1,Fmixed2);
%                                 FmixedAll = mean(FmixedAll,4);
%                                 hist(cat(2,Fmixed1(:),Fmixed2(:),FmixedAll(:)),100)
%                                 legend({'1' '2' 'all'})
%                                 
%                                 
%                                 
%                         end
%                     end
%                     % Results for whole experiment
% %                     [results.parametric.delay, results.parametric.amp] = cart2pol(results.parametric.parameters(:,:,:,1),results.parametric.parameters(:,:,:,2));
% %                     [results.parametric.delayse, results.parametric.ampse] = cart2pol(results.parametric.parametersse(:,:,:,1),results.parametric.parametersse(:,:,:,2));
%                     metric.allExp.amp(:,:,:,cond) = results.parametric.amp(:,:,:);
%                     metric.allExp.ampStd(:,:,:,cond) = results.parametric.ampse(:,:,:);
% %                     metric.allExp.crossValR2(:,:,:,cond) = results.R2;
%                     metric.allExp.F(:,:,:,cond) = results.parametric.F;
%                     metric.allExp.Fp(:,:,:,cond) = results.parametric.Fp;
%                     metric.allExp.Fz(:,:,:,cond) = results.parametric.Fz;
% %                     metric.allExp.crossValR2(:,:,:,cond) = results.R2;
%                     
%                     
%                     
%                     % Results for individual runs
%                     for i = 1:size(results.parametricRun.amp,4)
% %                         [results.parametricRun.delay(:,:,:,i), results.parametricRun.amp(:,:,:,i)] = cart2pol(results.parametricRun.parameters(:,:,:,i*2-1),results.parametricRun.parameters(:,:,:,i*2));
% %                         [results.parametricRun.delayse(:,:,:,i), results.parametricRun.ampse(:,:,:,i)] = cart2pol(results.parametricRun.parametersse(:,:,:,i*2-1),results.parametricRun.parametersse(:,:,:,i*2));
%                         
%                         metric.allRuns.amp(:,:,:,i,cond) = results.parametricRun.amp(:,:,:,i);
%                         metric.allRuns.ampStd(:,:,:,i,cond) = results.parametricRun.ampse(:,:,:,i);
%                         metric.allRuns.delay(:,:,:,i,cond) = results.parametricRun.delay(:,:,:,i);
%                         metric.allRuns.F(:,:,:,i,cond) = results.parametricRun.F(:,:,:,i);
%                         metric.allRuns.Fp(:,:,:,i,cond) = results.parametricRun.Fp(:,:,:,i);
%                         metric.allRuns.Fz(:,:,:,i,cond) = results.parametricRun.Fz(:,:,:,i);
%                     end
%                     metric.allRuns.Fmixed(:,:,:,cond) = results.parametricRun.Fmixed;
%                     metric.allRuns.Fmixedp(:,:,:,cond) = results.parametricRun.Fmixedp;
% %                     metric.allRuns.R2(:,:,:,:,cond) = results.R2run;
%                 end
% %                 keyboard
% %                 clear tmp tmp1
% %                 size(metric.allRuns.amp)
% %                 for i = 1:size(metric.allRuns.amp,4)
% %                     for ii = 1:size(metric.allRuns.amp,5)
% %                         tmp = metric.allRuns.amp(:,:,:,i,ii);
% %                         tmp1(:,i,ii) = tmp(logical(mask));
% %                     end
% %                 end
% %                 tmp2 = cat(2,tmp1(:,:,1),tmp1(:,:,2),tmp1(:,:,3));
% %                 tmp3 = corr(tmp2);
% %                 imagesc(tmp3)
%                 
% 
%                 nRuns = length(results.inputs.datasize);
%                 nPtsPerRun = results.inputs.datasize{1}(4);
%                 nPts = nRuns*nPtsPerRun;
%                 clear results
%                 
%                 % T and p
%                 metric.allExp.ampT = metric.allExp.amp./metric.allExp.ampStd;
%                 metric.allExp.ampP = 1-tcdf(metric.allExp.ampT,nPts-1);
%                 metric.allRuns.ampT = metric.allRuns.amp./metric.allRuns.ampStd;
%                 metric.allRuns.ampP = 1-tcdf(metric.allRuns.ampT,nPts-1);
%                 metric.allRuns.ampTmean = squeeze(mean(metric.allRuns.ampT,4));
%                 metric.allRuns.ampPmean = 1-tcdf(metric.allRuns.ampTmean,nPts-1);
%                 % Mask for ROI
%                 %                 slice = 10;
%                 %                 cond = 2;
%                 %                 run = 1;
%                 
%                 %                 close all
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allExp.ampP(:,:,slice,cond))
%                 allFields = fields(metric.allExp);
%                 tmpMask = repmat(mask,[1 1 1 3]);
%                 for i = 1:length(allFields)
%                     metric.allExp.(allFields{i})(~tmpMask) = nan;
%                 end
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allExp.ampP(:,:,slice,cond))
%                 
%                 %                 close all
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allRuns.amp(:,:,slice,run,cond),[0 5])
%                 allFields = fields(metric.allRuns);
%                 for i = 1:length(allFields)
%                     if length(size(metric.allRuns.(allFields{i})))==5
%                         tmpMask = repmat(mask,[1 1 1 nRuns 3]);
%                         metric.allRuns.(allFields{i})(~tmpMask) = nan;
%                     elseif length(size(metric.allRuns.(allFields{i})))==4
%                         tmpMask = repmat(mask,[1 1 1 3]);
%                         metric.allRuns.(allFields{i})(~tmpMask) = nan;
%                     end
%                 end
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allRuns.amp(:,:,slice,run,cond),[0 5])
% 
%                 % Mask for significance (FDR-corrected within the ROI)
%                 switch p.thresholdMethod
%                     case 'sessionCrossValR2'
%                         error('double-check that')
%                         sigMaskFDRanyCond = any(metric.allExp.crossValR2>p.thresholdP,4);
%                     case 'sessionP'
%                         error('double-check that')
%                         %On the whole experiment
%                         for cond = 1:3
%                             FDR = mafdr(reshape(metric.allExp.ampP(:,:,:,cond),[1,numel(metric.allExp.ampP(:,:,:,cond))])','BHFDR',1); metric.allExp.ampFDR(:,:,:,cond) = reshape(FDR',size(metric.allExp.ampP(:,:,:,cond))); clear FDR
%                         end
%                         sigMaskFDRanyCond = any(metric.allExp.ampFDR<p.thresholdP,4);
%                     case 'sessionF'
%                         error('double-check that')
%                         %On the whole experiment
%                         for cond = 1:3
%                             FDR = mafdr(reshape(metric.allExp.Fp(:,:,:,cond),[1,numel(metric.allExp.Fp(:,:,:,cond))])','BHFDR',1); metric.allExp.Ffdr(:,:,:,cond) = reshape(FDR',size(metric.allExp.Fp(:,:,:,cond))); clear FDR
%                         end
%                         sigMaskFDRanyCond = any(metric.allExp.Fp<p.thresholdP,4);
%                     case 'FmixedCorr'
%                         p.funcROI.stats = metric.allRuns.Fmixed;
%                         p.funcROI.p = metric.allRuns.Fmixedp;
%                         for cond = 1:3
%                             FDR = mafdr(reshape(p.funcROI.p(:,:,:,cond),[1,numel(p.funcROI.p(:,:,:,cond))])','BHFDR',1);
%                             p.funcROI.p(:,:,:,cond) = reshape(FDR',size(p.funcROI.p(:,:,:,cond))); clear FDR
%                         end
%                     case 'FmixedUncorr'
%                         error('double-check that')
%                         sigMaskFDRanyCond = any(metric.allRuns.Fmixedp<p.thresholdP,4);
%                     case 'runFcorr'
%                         p.funcROI.stats = squeeze(mean(metric.allRuns.Fz,4));
%                         p.funcROI.p = 1-normcdf(p.funcROI.stats,0,1);
%                         for cond = 1:3
%                             FDR = mafdr(reshape(p.funcROI.p(:,:,:,cond),[1,numel(p.funcROI.p(:,:,:,cond))])','BHFDR',1);
%                             p.funcROI.p(:,:,:,cond) = reshape(FDR',size(p.funcROI.p(:,:,:,cond))); clear FDR
%                         end
%                     case 'runFuncorr'
%                         error('double-check that')
%                         z = squeeze(mean(metric.allRuns.Fz,4));
%                         P = 1-normcdf(z,0,1);
%                         sigMaskFDRanyCond = any(P<p.thresholdP,4);
%                     case 'runP'
%                         error('double-check that')
%                         % On averaged individual runs
%                         for cond = 1:3
%                             FDR = mafdr(reshape(metric.allRuns.ampPmean(:,:,:,cond),[1,numel(metric.allRuns.ampPmean(:,:,:,cond))])','BHFDR',1); metric.allRuns.ampFDRmean(:,:,:,cond) = reshape(FDR',size(metric.allRuns.ampPmean(:,:,:,cond))); clear FDR
%                         end
%                         sigMaskFDRanyCond = any(metric.allRuns.ampFDRmean<p.thresholdP,4);
%                     case 'runUncorP'
%                         error('double-check that')
%                         % On averaged individual runs, not corrected for
%                         % multiple comparison
%                         sigMaskFDRanyCond = any(metric.allRuns.ampPmean<p.thresholdP,4);
%                     case 'runR2'
%                         error('double-check that')
%                         switch p.thresholdP
%                             case 0.05
%                                 R2thresh = 0.0358;
%                             case 0.01
%                                 R2thresh = 0.0610;
%                             case 0.001
%                                 R2thresh = 0.0975;
%                             case 0.0001
%                                 R2thresh = 0.1336;
%                         end
%                         sigMaskFDRanyCond = any(mean(metric.allRuns.R2,4)>=R2thresh,5);
%                 end
%                 
%                 if p.thresholdData
%                     switch p.funcROI.method
%                         case 'any3'
%                             p.funcROI.mask = any(p.funcROI.p<=p.thresholdP,4);
%                         case 'any2'
%                             error('not implemented')
%                         case 'all3'
%                             error('not implemented')
%                         case 'all2'
%                             error('not implemented')
%                         case 'only3'
%                             p.funcROI.mask = p.funcROI.p(:,:,:,3)<=p.thresholdP;
%                     end
%                 else
%                     p.funcROI.mask = true(size(p.funcROI.stats,1),size(p.funcROI.stats,2),size(p.funcROI.stats,3));
%                 end
%                 
% 
% %                 figure('WindowStyle','docked'); colormap gray
% %                 imagesc(p.funcROI.mask(:,:,10));
%                 
%                 
%                 
%                 allFields = fields(metric.allExp);
%                 tmpMask = repmat(p.funcROI.mask,[1 1 1 3]);
%                 for i = 1:length(allFields)
%                     metric.allExp.(allFields{i})(~tmpMask) = nan;
%                 end
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allExp.ampP(:,:,slice,cond))
%                 
%                 %                 close all
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allRuns.amp(:,:,slice,run,cond),[0 5])
%                 allFields = fields(metric.allRuns);
%                 for i = 1:length(allFields)
%                     if length(size(metric.allRuns.(allFields{i})))==5
%                         tmpMask = repmat(p.funcROI.mask,[1 1 1 nRuns 3]);
%                         metric.allRuns.(allFields{i})(~tmpMask) = nan;
%                     elseif length(size(metric.allRuns.(allFields{i})))==4
%                         tmpMask = repmat(p.funcROI.mask,[1 1 1 3]);
%                         metric.allRuns.(allFields{i})(~tmpMask) = nan;
%                     end
%                 end
%                 %                 figure('WindowStyle','docked'); colormap hot
%                 %                 imagesc(metric.allRuns.amp(:,:,slice,run,cond),[0 5])
%                 
% %                 % Remove corrupted slices
% %                 allFields1 = fields(metric);
% %                 for i = 1:length(allFields1)
% %                     allFields2 = fields(metric.(allFields1{i}));
% %                     for ii = 1:length(allFields2)
% %                         metric.(allFields1{i}).(allFields2{ii})(:,:,[1 13],:,:) = [];
% %                     end
% %                 end
% %                 keyboard
% 
% %                 close all
% %                 h1 = figure('WindowStyle','docked'); colormap gray
% %                 h2 = figure('WindowStyle','docked'); colormap hot
% %                 h3 = figure('WindowStyle','docked'); colormap gray
% %                 for slice = 1:13;
% %                     figure(h1);
% %                     imagesc(mean(brain(:,:,slice,:),4))
% %                     figure(h2);
% %                     imagesc(metric.allExp.ampT(:,:,slice,1))
% %                     figure(h3);
% %                     imagesc(any(any(zeroAmp(:,:,slice,:,:),4),5))
% %                     keyboard
% %                 end
%                 
% 
% % keyboard
% % clear tmp tmp1 tmptmp
% % for i = 1:size(metric.allRuns.amp,5)
% %     for ii = 1:size(metric.allRuns.amp,4)
% %         tmp = metric.allRuns.amp(:,:,:,ii,i);
% %         tmp1(:,ii,i) = tmp(~isnan(tmp));
% %     end
% % end
% % clear tmp
% % tmp = cat(2,tmp1(:,:,1),tmp1(:,:,2),tmp1(:,:,3));
% % tmp = corr(tmp);
% % imagesc(tmp)
% 
%                 
%                 %% Make this fit the pipeline
%                 switch p.preSelection
%                     case {'eqSess','sess1','sess2'}
%                         
%                         metricSinCos = metric;
%                         metric = struct;
%                         
%                         metric.voxInd = [];
%                         metric.ampRect = nan(length(find(metricSinCos.mask)),nRuns,3);
%                         metric.delayRect = nan(length(find(metricSinCos.mask)),nRuns,3);
%                         
%                         for z = 1:size(metricSinCos.mask,3)
%                             [x,y] = find(metricSinCos.mask(:,:,z));
%                             metric.voxInd = [metric.voxInd; x y repmat(z,[length(x) 1])];
%                         end
%                         
%                         for ii = 1:size(metric.voxInd,1)
%                             metric.ampRect(ii,:,:) = metricSinCos.allRuns.amp(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
%                             metric.delayRect(ii,:,:) = metricSinCos.allRuns.delay(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
%                             metric.funcROI.stats(ii,1) = p.funcROI.stats(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3));
%                             metric.funcROI.p(ii,1) = p.funcROI.p(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3));
%                         end
%                         
%                         %sort functional ROI and put in p struct
%                         p.funcROI.vec.stats = metric.funcROI.stats;
%                         p.funcROI.vec.p = metric.funcROI.p;
%                         [~, p.funcROI.vec.sortInd] = sort(metric.funcROI.stats,'descend');
%                         
%                         metric.dataFields = fields(metric); metric.dataFields(1) = [];
% %                         metric.label = metricCompiled.label;
%                         
%                         metric.sessionLabel(1,:,:) = repmat(sessionLabel',[1 3]);
%                         metric.fittingParam.period = period;
%                         
%                         clear metricSinCos
%                     otherwise
%                         error('double-check that')
%                         metricSinCos = metric;
%                         % Get some info from the crossCorr data files
%                         [~,b,~] = fileparts(dataFileIn);
%                         if ~exist(fullfile(dataDirIn,[b '.mat']),'file')
%                             tmp = strsplit(b,'_'); tmp = strfind(b,tmp{end}); b(tmp:end) = []; if strcmp(b(end),'_'); b(end) = []; end; if strcmp(b(end),'_'); b(end) = []; end;
%                         end
%                         load(fullfile(dataDirIn,[b '.mat']),'metric')
%                         clear tmp
%                         tmp.runList = metric.runList;
%                         tmp.run = metric.run;
%                         tmp.trial = metric.(['trial8']);
%                         
%                         metric = tmp; clear tmp
%                         runList = dir([labelDir '/*.mat']);
%                         
%                         
%                         label = [];
%                         i=1;
%                         while i <= length(runList)
%                             tmp = strsplit(runList(i).name,'__');
%                             if length(tmp)==3
%                                 label = [label str2num(tmp{3}(18:end-4))];
%                             end
%                             i = i+1;
%                         end
%                         metricCompiled = compileRuns(metric,label,'crossCorr',dataType);
%                         
%                         
%                         
%                         %                 tmp = cat(2,metricCompiled.ampRect(:,:,1),metricCompiled.ampRect(:,:,2),metricCompiled.ampRect(:,:,3));
%                         %                 tmp = corr(tmp);
%                         %                 imagesc(tmp)
%                         
%                         
%                         
%                         
%                         
%                         % Create new metric variable
%                         metric = struct;
%                         
%                         finalMask = p.funcROI.mask.*logical(mask);
%                         metric.voxInd = [];
%                         metric.ampRect = nan(length(find(finalMask)),nRuns,3);
%                         metric.delayRect = nan(length(find(finalMask)),nRuns,3);
%                         
%                         for z = 1:size(finalMask,3)
%                             [x,y] = find(finalMask(:,:,z));
%                             metric.voxInd = [metric.voxInd; x y repmat(z,[length(x) 1])];
%                         end
%                         
%                         for ii = 1:size(metric.voxInd,1)
%                             metric.ampRect(ii,:,:) = metricSinCos.allRuns.amp(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
%                             metric.delayRect(ii,:,:) = metricSinCos.allRuns.delay(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3),:,:);
%                             metric.funcROI.stats(ii,1) = p.funcROI.stats(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3));
%                             metric.funcROI.p(ii,1) = p.funcROI.p(metric.voxInd(ii,1),metric.voxInd(ii,2),metric.voxInd(ii,3));
%                         end
%                         
%                         %sort functional ROI and put in p struct
%                         p.funcROI.vec.stats = metric.funcROI.stats;
%                         p.funcROI.vec.p = metric.funcROI.p;
%                         [~, p.funcROI.vec.sortInd] = sort(metric.funcROI.stats,'descend');
%                         
%                         metric.dataFields = fields(metric); metric.dataFields(1) = [];
%                         metric.label = metricCompiled.label;
%                         keyboard
%                         metric.sessionLabel = metricCompiled.sessionLabel;
%                         metric.fittingParam.period = metricCompiled.fittingParam.period;
%                         clear metricCompiled.fittingParam
%                 end
%                 
%                 
% %                 tmp = cat(2,metric.ampRect(:,:,1),metric.ampRect(:,:,2),metric.ampRect(:,:,3));
% %                 tmp = corr(tmp);
% %                 imagesc(tmp)
                
                
            case 'crossCorr'
                %Load it
                
                [a,b,c] = fileparts(dataFileIn);
                if ~exist(fullfile(dataDirIn,[b '.mat']),'file')
                    tmp = strsplit(b,'_'); tmp = strfind(b,tmp{end}); b(tmp:end) = []; if strcmp(b(end),'_'); b(end) = []; end; if strcmp(b(end),'_'); b(end) = []; end;
                end
                load(fullfile(dataDirIn,[b '.mat']),'metric')
                
                tmp.runList = metric.runList;
                tmp.run = metric.run;
                tmp.trial = metric.(['trial' num2str(p.trialsPerObs)]);
                metric = tmp; clear tmp
                
                runList = dir([labelDir '/*.mat']);
                label = [];
                i=1;
                while i <= length(runList)
                    tmp = strsplit(runList(i).name,'__');
                    if length(tmp)==3
                        label = [label str2num(tmp{3}(18:end-4))];
                    end
                    i = i+1;
                end
                %         switch dataType
                %             case 'trial'
                %                 metricCompiled = compileRuns(metric,label,fitType,dataType);
                %                 metricCompiled_thresh = compileRuns(metric,label,fitType,'run');
                %             case 'run'
%                 metricCompiled = compileRuns(metric,label,fitType,dataType);
                metricCompiled = compileRuns(metric,label,'crossCorr',dataType);
                metricCompiled_thresh = metricCompiled;
                %         end
                %Threshold it
                %based on r^2
                if p.thresholdData
                    switch p.thresholdP
                        case 0.05
                            threshRsquared = 0.0358;
                        case 0.01
                            threshRsquared = 0.0610;
                        case 0.001
                            threshRsquared = 0.0975;
                        case 0.0001
                            threshRsquared = 0.1336;
                        otherwise
                            warning('threshRsquared not precompiled for requested p, will estimate it. Should be fine as long as you have very large noisy data set')
                            threshRsquared = findRsqaredAtP(metricCompiled,p.thresholdP);
                    end
                    metricCompiled = applyThresh(metricCompiled,metricCompiled_thresh,'Rsquared',threshRsquared);%0.2435^2
                    metric = metricCompiled; clear metricCompiled
                else
                    clear metricCompiled
                end
                %based on phase locking
                if p.PL
                    metric = applyPhaseLockingThresh(metric);
                end
            otherwise
                error('did not implement for these specific params')
        end
        



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         keyboard
%         figure('windowStyle','docked');
%         [~,b] = sort(metric.funcROI.stats,'descend');
%         tmp = [metric.ampRect(b,:,1)'; metric.ampRect(b,:,2)'];
%         tmp = zscore(tmp,[],2);
%         tmp = zscore(tmp,[],1);
%         tmp1 = tmp(1:end/2,:);
%         tmp2 = tmp(end/2+1:end,:);
%         ind = mean(tmp2-tmp1,1)>0;
%         tmp(1:end/2,ind) = tmp1(:,ind);
%         tmp(end/2+1:end,ind) = tmp2(:,ind);
%         tmp(1:end/2,~ind) = tmp2(:,~ind);
%         tmp(end/2+1:end,~ind) = tmp1(:,~ind);
%         
%         imagesc(tmp)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %% Define some params
        p.subj = subj;
%         p.dataType = dataType;
        p.fitType = fitType;
        p.maskName = maskName;
        p.k = k;
        p.featLevType = featLevType;
        p.nFeatLev = nFeatLev;
        p.keepInfo = keepInfo;
        p.C = 1;
%         p.fittingParam = metric.fittingParam;
        p.voxInd = metric.voxInd;
        p.algorithm = algorithm;
        p.RFE_L = RFE_L;
        
        p.nObs = size(metric.ampRect,2)*2;
        p.nFeatures = size(metric.ampRect,1);
        
        p.dataFileOut = dataFileOut;
        p.dataDirOut = dataDirOut;
        
        switch p.featLevType
            case 'max'
                p.featLevList = p.nFeatures;
            case 'log'
                p.featLevList = unique([1 round(exp(linspace(log(1),log(p.nFeatures),p.nFeatLev))) p.nFeatures]);
            case 'linReg'
                
                p.featLevList = p.voxPerFeatLev:p.voxPerFeatLev:p.nFeatures;
                if p.nFeatures~=p.featLevList(end)
                    p.featLevList(end+1) = p.nFeatures;
                end
            case 'lin'
                error('doubleCheck')
                p.featLevList = linspace(0,p.nFeatures,p.nFeatLev+1);
                p.featLevList(1) = [];
                p.featLevList = round(p.featLevList);
            case 'F1'
                Fsorted = p.funcROI.vec.stats(p.funcROI.vec.sortInd);
                p.funLevList = 100;
                FatStep = Fsorted(p.funLevList);
                Fsorted = Fsorted(p.funLevList:end);
                Fstep = linspace(max(Fsorted),min(Fsorted),p.nFeatLev);
                for iii = 2:length(Fstep)
                    p.funLevList = [p.funLevList p.funLevList(1)+length(find(Fsorted>Fstep(iii)))];
                    FatStep = [FatStep Fstep(iii)];
                end
                p.featLevList = p.funLevList;
                
                
%                 tmpFeat = unique([1 round(exp(linspace(log(1),log(p.nFeatures),p.nFeatLev))) p.nFeatures]);
%                 tmpFeat = tmpFeat(tmpFeat>=100);
%                 plot(tmpFeat); hold on
%                 plot(p.funLevList,'r')
%                 
%                 figure('WindowStyle','docked');
%                 hist(p.funcROI.vec.stats,100); hold on
%                 Fsorted = p.funcROI.vec.stats(p.funcROI.vec.sortInd);
%                 plot(Fsorted(p.featLevList),100,'ro')
                
            case 'fix'
                p.featLevList = [1 2 3 4 5 6 7 8 9 10 12 14 16 19 22 25 29 33 39 45 52 60 69 80 93 108 125 144 167 193 224 259 300 347 401 465 538 622 720 834 965 1117 1293];
                p.featLevList = p.featLevList(p.featLevList<=p.nFeatures);
                if p.featLevList(end)~=p.nFeatures
                    p.featLevList = [p.featLevList p.nFeatures];
                end
            case 'fix2'
                p.featLevList = [10 100 500 1000];
                p.featLevList = p.featLevList(p.featLevList<=p.nFeatures);
                if p.featLevList(end)~=p.nFeatures
                    p.featLevList = [p.featLevList p.nFeatures];
                end
            otherwise
                error('what do you wanna do?')
        end
        p.nFeatLev = length(p.featLevList);
        
        
        
        if strfind(char(curKernel),'polynomial')
            tmpKernel = strsplit(char(curKernel),'_');
            p.kernel = tmpKernel{1}; % 'linear' 'quadratic' 'polynomial' 'rbf' (Gaussian Radial) 'mlp' (Multilayer Perceptron)
            p.polyorder = str2num(tmpKernel{2});
        else
            p.kernel = char(curKernel); % 'linear' 'quadratic' 'polynomial' 'rbf' (Gaussian Radial) 'mlp' (Multilayer Perceptron)
        end
        
        %% Define data and labels
        %Data
        switch p.conditions
            case 'grat1VSgrat2'
                ind1 = 1; ind2 = 2; indNorm = 3;
            case 'gratVSplaid'
                ind1 = [1 2]; ind2 = 3;
            case 'grat1VSplaid'
                ind1 = 1; ind2 = 3;
            case 'grat2VSplaid'
                ind1 = 2; ind2 = 3;
            otherwise
                error('something wrong')
        end
        if strcmp(fitType,'SinCos')
            tmp1 = metric.ampRect(:,:,ind1);
            tmp2 = metric.ampRect(:,:,ind2);
            tmpNorm = metric.ampRect(:,:,indNorm);
            mag = [tmp1 tmp2]';
            magNorm = tmpNorm';
            
            tmp1 = metric.delayRect(:,:,ind1);
            tmp2 = metric.delayRect(:,:,ind2);
            tmpNorm = metric.delayRect(:,:,indNorm);
            phase = [tmp1 tmp2]';
            phaseNorm = tmpNorm';
        else
            error('have a look at that (norm)')
            tmp1 = mean(metric.ampRect(:,:,ind1),3);
            tmp2 = mean(metric.ampRect(:,:,ind2),3);
            mag = [tmp1 tmp2]';
            tmp1 = circ_mean(sec2rad(metric.delayRect(:,:,ind1),metric.fittingParam.period),[],3);
            tmp2 = circ_mean(sec2rad(metric.delayRect(:,:,ind2),metric.fittingParam.period),[],3);
            phase = [tmp1 tmp2]';
        end
        [X,Y] = pol2cart(phase,mag);
        d.xData = complex(X,Y);
        [X,Y] = pol2cart(phaseNorm,magNorm);
        d.normData = complex(X,Y); clear tmp1 tmp2 tmpNorm phase phaseNorm mag magNorm
        
        %Category labels
        d.label = reshape(repmat([1 2],p.nObs/2,1),p.nObs,1);
        %Session labels
        if length(ind1)>1 && ~all(metric.sessionLabel(1,:,ind1(1))==metric.sessionLabel(1,:,ind1(2)))
            error('something wrong here')
        end
        if length(ind2)>1
            error('something wrong here')
        end
        d.sessionLabel = [metric.sessionLabel(1,:,ind1(1)) metric.sessionLabel(1,:,ind2)]';
        
        %% Compute accuracy threshold on binomial distribution !!!!Might be wrong!!!!
        [p.binom.hitRate, p.binom.p] = binomialSigThresh(p.nObs,0.5);
        
        
        %% Run SVMs
        stime = tic;
        svm = runSVMRepetitions2_para(d,p,1);
        svm.r.dur = toc(stime);
        display(['This took ' datestr(1/24/60/60*svm.r.dur, 'HH:MM:SS') 'sec'])

        %% Output and plot
        if stopThis
            break
        else
%             svm.p = p;
            
            %reduce size and save
            svmOrig = svm;
            svm.w = [];
            svm.a = [];
            svm.amp = [];
            svm.delay = [];
            svm.xValCorr = [];
            save(fullfile(dataDirOut,[dataFileOut '.mat']),'svm','d','p','perm')
            display(['Data saved as ' dataFileOut])
            
            %plot
            if plotIt
                if p.doSVM && p.doCrossVal
                    [h,h2] = plotSVM2(svm);
                elseif ~p.doSVM && p.doCrossVal
                    [~,h2] = plotSVM2(svm);
                elseif p.doSVM && ~p.doCrossVal
                    [h,~] = plotSVM2(svm);
                else
                    [h,h2] = plotSVM2(svm);
                end
                if svm.p.doSVM
                    saveas(h,fullfile(dataDirOut,[dataFileOut '.jpg']),'jpg')
                end
            end
        end
    else
        %% Load already performed SVM analysis
        load(allFile{taskInd},'p','svm','d','perm')
        if ~exist('plotIt','var')
            plotIt = 1;
        end
        if exist('altPerm','var')
            perm.doPerm = 1;
            plotIt = 1;
            allFields = fields(altPerm);
            for i = 1:length(allFields)
                curField = allFields{i};
                perm.(curField) = altPerm.(curField);
            end
        end
        
        %% Plot it
        if plotIt
            [h1,h2] = plotSVM2(svm);
        end
        
%         %% Extract fixed ROI
%         %At each voxel, count the number of time it was included across all
%         %folds and repetition
%         for i = 1:size(svm.a,2)
%             inclFreq(i) = length(find(~isnan(svm.a(:,i,:,:))))/numel(svm.a(:,i,:,:));
%         end
%         %Sort them according to that, from the most often included to the
%         %least (breaking tighs acording to A??)
%         [~,b] = sort(inclFreq);
%         A = abs(svm.a);
%         A(isnan(A)) = 0;
%         A = mean(A,3);
%         A = mean(A,4);
        
%         length(find(diff(a)==0))/length(a)
        
    end
    
    
    %% Permutation test
    if perm.doPerm
        
        %% House keeping
        %Define feature levels
        if strcmp(p.algorithm,'SVM_RFE')
            error('code that')
            altFeatLev = p.featLevList;
        else
            if perm.doPermAtMax
                altFeatLev =[];
                [~,b] = max(mean(svm.r.hitRate,1));
                altFeatLev =[altFeatLev p.featLevList(b)];
                [~,b] = min(mean(svm.r.hitRate,1));
                altFeatLev =[altFeatLev p.featLevList(b)];
            elseif perm.doPermAtAll
                altFeatLev = p.featLevList;
            else
                error('code that')
                if p.nFeatLev>3
                    altFeatLev=[]; % define manually which point to run permutation test on
                    %                 altFeatLev=[9]; % define manually which point to run permutation test on
                    if stopIt
                        keyboard
                        %                 altFeatLev=[]; % define manually which point to run permutation test on
                    else
                        %                     keyboard
                    end
                else
                    altFeatLev=p.featLevList;
                end
            end
        end
        
        
        %Prepare p
        if isfield(svm,'pP')
            p = svm.pP;
            if exist('altFeatLev','var')
                if ~isempty(altFeatLev)
                    p.altFeatLev = altFeatLev;
                else
                    altFeatLev = p.altFeatLev;
                end
            else
                error('Must specify this because lazy programmer')
            end
        else
            svm.pP = svm.p;
            svm.pP.allPerm = nan(1,length(d.label));
            svm.pP.numPerm = perm.numPerm;
            p = svm.pP;
            if exist('altFeatLev','var')
                if ~isempty(altFeatLev)
                    p.altFeatLev = altFeatLev;
                else
                    p.altFeatLev = p.featLevList;
                    altFeatLev = p.altFeatLev;
                end
            else
                error('Must specify this because lazy programmer')
            end
        end
        
        if p.doSVM
            %Prepare r
            if isfield(svm,'rP')
                r = svm.rP;
            else
                svm.rP.hitRate = [];
                r = svm.rP;
            end
        end
        
        if p.doCrossVal
            if isfield(svm,'xValCorrP')
                xValCorr = svm.xValCorrP;
            else
                svm.xValCorrP.Rsquared = [];
                xValCorr = svm.xValCorrP;
            end
        end
        
        
        % Compute only at all level of feature selection if not specified
        if ~exist('altFeatLev','var') || isempty(altFeatLev)
            altFeatLev = p.featLevList;
        end

        
        
        % Loop over permutations in the bloc
        i=0;
        permDone = 0;
        while i<perm.numPermPerBloc && ~permDone
            if svm.p.doSVM
                allHitRate = nan(perm.compileEachNperm,length(altFeatLev),length(altFeatLev));
            end
            if svm.p.doCrossVal
                allRsquared = nan(perm.compileEachNperm,length(altFeatLev),length(altFeatLev));
            end
            
            for ii = 1:perm.compileEachNperm
                %% Check if we have enough
                if svm.p.doSVM
                    permInBloc = findNperm(allHitRate);
                    permTotal = findNperm(r.hitRate);
                else
                    permInBloc = findNperm(allRsquared);
                    permTotal = findNperm(xValCorr.Rsquared);
                end
                nPerm = permTotal + permInBloc;
                if all(nPerm>=perm.numPerm)
                    permDone = 1;
                    break
                end
                
                %% Do it
                display(['Perm ' num2str(i+1) '/' num2str(perm.numPermPerBloc) ' in bloc']);
                display(['Perm ' num2str(max(permTotal)+1) '/' num2str(perm.numPerm) ' total']);
                i = i+1;
                
                tic

                curd = d; tmpp = p;
                tmpp.repeat = 1; %only one repeat for permutation test
                %define random k-folding here (if d.crossVal exists, it will not be generated later in runSVMRepetitions2)
                curd.crossVal = [randperm(size(curd.label,1)/2) randperm(size(curd.label,1)/2)]';
                %then randomly swap or not labels at each fold to keep
                %labels balanced
                for i = 1:size(d.label,1)/2
                    tmp = curd.label(curd.crossVal==i);
                    curd.label(curd.crossVal==i) = tmp(randperm(length(tmp)));
                end
                
                
                
                
                tmpp.featLevList = altFeatLev;
                tmpp.nFeatLev = length(tmpp.featLevList);
                if ~all(ismember(tmpp.featLevList,svm.p.featLevList))
                    error('Must feature levels for permutation that were used for actual test')
                end
                
                [cursvm,~] = runSVMRepetitions2(curd,tmpp,0);
                allHitRate(ii,:,:) = mean(cursvm.r.hitRate,1);
%                 allRsquared(ii,:) = mean(curRsquared,1);
                
                dur(ii) = toc;
                display(['Took ' num2str(round(dur(ii))) 'sec']);

            end
            
            %% Compile
            
            r.hitRate = cat(1,r.hitRate,allHitRate);
%             r.hitRate = compilePermRes(r.hitRate,svm.p.featLevList,svm.p.featLevList,allHitRate,altFeatLev,altFeatLev);
%             xValCorr.Rsquared = compilePermRes(xValCorr.Rsquared,svm.p.featLevList,allRsquared,altFeatLev);
            if ~isfield(r,'dur')
                r.dur = dur';
            else
                if ~exist('dur','var')
                    dur=0;
                end
                r.dur = [r.dur; dur'];
            end
            
            % Put data back in the main structure
            svm.pP = p;
            svm.rP = r;
            
            % Compute non-param thresh so far
            svm.rP.thresh = prctile(svm.rP.hitRate,[2.5 5 95 97.5],1);
            
            % Plot
            plotNameList = {'actualMean' 'negThresh' 'posThresh' 'actualThresh' 'permMean'};
            svm.plotIt = plotIt;
            if ~exist('h','var')
                h = zeros(1,length(plotNameList));
                if exist('h1','var')
                    h(1) = h1;
                end
            end
            for iii = 1:length(plotNameList)
                if h(iii)
                    h(iii) = plotSVM2(svm,h(iii),[],[],[],plotNameList{iii});
                else
                    h(iii) = plotSVM2(svm,[],[],[],[],plotNameList{iii});
                end
                saveas(h(iii),fullfile(p.dataDirOut,[p.dataFileOut '_' plotNameList{iii} '.jpg']),'jpg')
            end

            
            % Save
            if ~exist(fullfile(p.dataDirOut,[p.dataFileOut '.mat']),'file')
                p.dataDirOut = altMainDir;
            end
            save(fullfile(p.dataDirOut,[p.dataFileOut '.mat']),'svm','-append') 
        end
    end
end



end

