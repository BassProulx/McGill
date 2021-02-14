function [results] = runGLMs(d,p)
% function [results] = runGLM(design,data,stimdur,tr,hrfmodel,hrfknobs,opt,splitIn)


p.timeSz = zeros(size(d.data,1),1);
p.xyzSz = size(d.data{1},1:3);
p.runSz = size(d.data,1);
p.polyDeg = zeros(size(d.data,1),1);
d.poly = cell(size(d.data));
d.polyInfo = cell(size(d.data));
d.censorPts = cell(size(d.data));
for runInd = 1:size(d.data,1)
    timeSz = size(d.data{runInd},4);
    polyDeg = round(timeSz*p.tr/60/2);
    d.poly{runInd,1} = constructpolynomialmatrix(timeSz,0:polyDeg,0);
    d.polyInfo{runInd,1} = cellstr(num2str((0:polyDeg)','poly%d'))';
    p.timeSz(runInd,1) = timeSz;
    p.polyDeg(runInd,1) = polyDeg;
    d.censorPts{runInd,1} = false(timeSz,1);
    d.censorPts{runInd,1}(1:24) = true;
end

%% HRF
res = runHRF(d,p);
%% Sin
res = runSin(d,p)

function res = runSin(d,p)
%% First exclude
excl = d.excl;
rep = unique(d.repLabel(excl));
if length(rep)>1
    error('cannot deal with multiple exclusions')
end
fieldList = fields(d);
for fieldInd = 1:length(fieldList)
    d.(fieldList{fieldInd})(excl,:,:) = [];
end
d.repLabel(d.repLabel>rep) = d.repLabel(d.repLabel>rep)-1;
d.runInd = (1:size(d.repLabel,1))';
fieldList = fields(p);
for fieldInd = 1:length(fieldList)
    if size(p.(fieldList{fieldInd}),1)==p.runSz
        p.(fieldList{fieldInd})(excl,:,:) = [];
    end
end
p.runSz = p.runSz - nnz(excl);


%% Prepare peices of design matrix
for runInd = 1:size(d.data,1)
    hrfknobs = zeros(p.stimDur/p.tr*2);
    hrfknobs(logical(eye(size(hrfknobs)))) = 1;
    d.design{runInd} = repmat(d.design{runInd},1,size(hrfknobs,2));
    tmp = nan(p.timeSz(runInd)+p.stimDur/p.tr*2-1,p.stimDur/p.tr*2);
    for knobInd = 1:size(hrfknobs,2)
        tmp(:,knobInd) = conv2(full(d.design{runInd}(:,knobInd)),hrfknobs(:,knobInd));  % convolve
    end
    d.design{runInd} = tmp(1:p.timeSz(runInd,1),:); clear tmp
end
p.designInfo1 = cellstr(num2str((1:size(hrfknobs,2))','t%d'))';
p.designInfo2 = cellstr(num2str(sort(unique(d.condLabel)),'cond%d'))';

%% Fixed-effect
disp('Fixed-Effect')
opt.rmPoly0 = 1;
fixedFitRes = fitFixed(d,p,opt);
fieldList = fields(fixedFitRes);
for fieldInd = 1:length(fieldList)
    figure('WindowStyle','docked');
    imagesc(fixedFitRes.(fieldList{fieldInd}).design)
    title(fixedFitRes.(fieldList{fieldInd}).info)
end

regTlist = unique(ols.designInfo(1,:));
regTlist = regTlist(~cellfun('isempty',regTlist));
regCondList = unique(ols.designInfo(2,:));
regCondList = regCondList(~cellfun('isempty',regCondList));
hr = nan([p.xyzSz length(regCondList) length(regTlist)]);
for regTind = 1:length(regTlist)
    for regCondInd = 1:length(regCondList)
        ind = ismember(ols.designInfo(1,:),regTlist{regTind}) & ismember(ols.designInfo(2,:),regCondList{regCondInd});
        hr(:,:,:,regCondInd,regTind) = ols.betas(:,:,:,ind);
    end
end

res.hr = hr; clear hr
res.info = 'X x Y x Z x cond x time';

function res = runHRF(d,p)
%% First exclude
excl = d.excl;
rep = unique(d.repLabel(excl));
if length(rep)>1
    error('cannot deal with multiple exclusions')
end
fieldList = fields(d);
for fieldInd = 1:length(fieldList)
    d.(fieldList{fieldInd})(excl,:,:) = [];
end
d.repLabel(d.repLabel>rep) = d.repLabel(d.repLabel>rep)-1;
d.runInd = (1:size(d.repLabel,1))';
fieldList = fields(p);
for fieldInd = 1:length(fieldList)
    if size(p.(fieldList{fieldInd}),1)==p.runSz
        p.(fieldList{fieldInd})(excl,:,:) = [];
    end
end
p.runSz = p.runSz - nnz(excl);


%% Prepare peices of design matrix
for runInd = 1:size(d.data,1)
    hrfknobs = zeros(p.stimDur/p.tr*2);
    hrfknobs(logical(eye(size(hrfknobs)))) = 1;
    d.design{runInd} = repmat(d.design{runInd},1,size(hrfknobs,2));
    tmp = nan(p.timeSz(runInd)+p.stimDur/p.tr*2-1,p.stimDur/p.tr*2);
    for knobInd = 1:size(hrfknobs,2)
        tmp(:,knobInd) = conv2(full(d.design{runInd}(:,knobInd)),hrfknobs(:,knobInd));  % convolve
    end
    d.design{runInd} = tmp(1:p.timeSz(runInd,1),:); clear tmp
end
p.designInfo1 = cellstr(num2str((1:size(hrfknobs,2))','t%d'))';
p.designInfo2 = cellstr(num2str(sort(unique(d.condLabel)),'cond%d'))';

%% Fixed-effect
disp('Fixed-Effect')
opt.rmPoly0 = 1;
fixedFitRes = fitFixed(d,p,opt);
fieldList = fields(fixedFitRes);
for fieldInd = 1:length(fieldList)
    figure('WindowStyle','docked');
    imagesc(fixedFitRes.(fieldList{fieldInd}).design)
    title(fixedFitRes.(fieldList{fieldInd}).info)
end

regTlist = unique(ols.designInfo(1,:));
regTlist = regTlist(~cellfun('isempty',regTlist));
regCondList = unique(ols.designInfo(2,:));
regCondList = regCondList(~cellfun('isempty',regCondList));
hr = nan([p.xyzSz length(regCondList) length(regTlist)]);
for regTind = 1:length(regTlist)
    for regCondInd = 1:length(regCondList)
        ind = ismember(ols.designInfo(1,:),regTlist{regTind}) & ismember(ols.designInfo(2,:),regCondList{regCondInd});
        hr(:,:,:,regCondInd,regTind) = ols.betas(:,:,:,ind);
    end
end

res.hr = hr; clear hr
res.info = 'X x Y x Z x cond x time';


function res = fitFixed(d,p,opt)
if ~exist('opt','var')
    opt = [];
end
if ~isfield(opt,'rmPoly0')
    opt.rmPoly0 = 0;
end
% design
[designFull,designFullInfo] = getDesign(d,p);
% Polynomial regressors
[poly,polyInfo,polyX,polyInfoX] = getPoly(d,p);
% Extra regressors (e.g. motion)
if p.doMotion
    motionInfo = [repmat({''},2,length(motionInfo)); motionInfo; repmat({''},1,length(motionInfo))];
else
    motion = nan(sum(p.timeSz),0);
    motionInfo = {};
end

%% Model 1
modelName = 'null';
modelLabel = 'null model';
designMatrix = cat(2,motion,poly);
designMatrixInfo = cat(2,motionInfo,polyInfo);
design = designMatrix;
designInfo = designMatrixInfo;
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)

%% Model 2
modelName = 'full';
modelLabel = 'full model';
design = designFull;
designInfo = designFullInfo;
if opt.rmPoly0
    design = cat(2,design,motion,polyX);
    designInfo = cat(2,designInfo,motionInfo,polyInfoX);
else
    design = cat(2,design,motion,poly);
    designInfo = cat(2,designInfo,motionInfo,polyInfo);
end
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)

%% Model 3
modelName = 'cond1v2v3null';
modelLabel = 'cond1v2v3-null model';
condToMerge = {'cond1' 'cond2' 'cond3'};
condToMergeLabel = {'cond1v2v3'};
[design,designInfo] = mergeCond(designFull,designFullInfo,condToMerge,condToMergeLabel);
if opt.rmPoly0
    design = cat(2,design,motion,polyX);
    designInfo = cat(2,designInfo,motionInfo,polyInfoX);
else
    design = cat(2,design,motion,poly);
    designInfo = cat(2,designInfo,motionInfo,polyInfo);
end
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)

%% Model 4
modelName = 'cond1v2null';
modelLabel = 'cond1v2-null model';
condToMerge = {'cond1' 'cond2'};
condToMergeLabel = {'cond1+2'};
[design,designInfo] = mergeCond(designFull,designFullInfo,condToMerge,condToMergeLabel);
if opt.rmPoly0
    design = cat(2,design,motion,polyX);
    designInfo = cat(2,designInfo,motionInfo,polyInfoX);
else
    design = cat(2,design,motion,poly);
    designInfo = cat(2,designInfo,motionInfo,polyInfo);
end
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)

%% Model 5
modelName = 'cond1v3null';
modelLabel = 'cond1v3-null model';
condToMerge = {'cond1' 'cond3'};
condToMergeLabel = {'cond1+3'};
[design,designInfo] = mergeCond(designFull,designFullInfo,condToMerge,condToMergeLabel);
if opt.rmPoly0
    design = cat(2,design,motion,polyX);
    designInfo = cat(2,designInfo,motionInfo,polyInfoX);
else
    design = cat(2,design,motion,poly);
    designInfo = cat(2,designInfo,motionInfo,polyInfo);
end
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)

%% Model 6
modelName = 'cond2v3null';
modelLabel = 'cond2v3-null model';
condToMerge = {'cond2' 'cond3'};
condToMergeLabel = {'cond2+3'};
[design,designInfo] = mergeCond(designFull,designFullInfo,condToMerge,condToMergeLabel);
if opt.rmPoly0
    design = cat(2,design,motion,polyX);
    designInfo = cat(2,designInfo,motionInfo,polyInfoX);
else
    design = cat(2,design,motion,poly);
    designInfo = cat(2,designInfo,motionInfo,polyInfo);
end
res.(modelName) = computeOLS(d,design,designInfo);
res.(modelName).info = modelLabel;
% imagesc(res.(modelName).design)


function [design,designInfo] = getDesign(d,p)
condList = sort(unique(d.condLabel));
tmp1 = d.design;
runLabel = cell(size(d.design));
for runInd = 1:size(tmp1,1)
    tmp1{runInd,1} = zeros(size(tmp1{runInd,1}));
    runLabel{runInd} = ones(size(tmp1{runInd,1},1),1).*runInd;
end
design = cell(1,length(condList));
designInfo = cell(1,length(condList));
for condInd = 1:length(condList)
    cond = condList(condInd);
    tmp2 = tmp1;
    tmp2(d.condLabel==cond) = d.design(d.condLabel==cond);
    design{condInd} = catcell(1,tmp2);
    designInfo{condInd} = repmat(p.designInfo2(condInd),[1 size(design{condInd},2)]);
end
clear tmp1 tmp2
design = catcell(2,design);
designInfo1 = repmat(p.designInfo1,[1 size(designInfo,2)]);
designInfo2 = catcell(2,designInfo);
designInfo = cat(1,designInfo1,designInfo2); clear designInfo1 designInfo2
designInfo = cat(1,designInfo,repmat({''},2,length(designInfo)));

function [poly,polyInfo,polyX,polyInfoX] = getPoly(d,p)
poly = blkdiag(d.poly{:});
polyInfo = catcell(1,d.polyInfo)';
polyInfo = polyInfo(:)';
polyInfo = [repmat({''},3,length(polyInfo)); polyInfo; repmat({''},0,length(polyInfo))];

polyX = poly;
polyX(:,1:p.polyDeg(1)+1:end) = [];
polyInfoX = polyInfo;
polyInfoX(:,1:p.polyDeg(1)+1:end) = [];

function [design,designInfo] = mergeCond(design,designInfo,condToMerge,condToMergeLabel)
regList = unique(designInfo(1,:));
designTmp = nan([size(design,1) size(regList,2)]);
designInfoTmp = repmat({''},[size(designInfo,1) size(regList,2)]);
for regInd = 1:length(regList)
    ind = ismember(designInfo(1,:),regList{regInd});
    ind = ind & ismember(designInfo(2,:),condToMerge);
    designTmp(:,regInd) = sum(design(:,ind),2);
    designInfoTmp(1,regInd) = regList(regInd);
    designInfoTmp(2,regInd) = condToMergeLabel;
end
ind = ~ismember(designInfo(2,:),condToMerge);
design = cat(2,designTmp,design(:,ind));
designInfo = cat(2,designInfoTmp,designInfo(:,ind));

function res = computeOLS(d,design,designInfo)
disp('computing OLS')
dataInd = ~d.censorPts{1}; % this here works only if all runs have the same length and the same censored points
xyzSz = size(d.data{1},1:3);
res.betas = ...
    mtimescell(olsmatrix2(design), ...
    cellfun(@(x) squish(x(:,:,:,dataInd),3)',d.data,'UniformOutput',0));  % regressors x voxels
res.betas = permute(reshape(res.betas,[size(design,2) xyzSz]),[2 3 4 1]);
res.design = design;
res.designInfo = designInfo;







% % OLS Reduced-Model 1
% modelInd = ~ismember(designInfo(2,:),{'cond1' 'cond2' 'cond3'});
% dataInd = ~catcell(1,d.censorPts);
% display('computing OLS')
% betas = ...
%     mtimescell(olsmatrix2(design(dataInd,modelInd)), ...
%     cellfun(@(x) squish(x(:,:,:,~d.censorPts{1}),3)',d.data,'UniformOutput',0));  % regressors x voxels
% 
% betas = permute(reshape(betas,[size(design(:,modelInd),2) p.xyzSz]),[2 3 4 1]);
% 
% ind = ismember(designInfo(4,modelInd),{'poly0'});
% base = betas(:,:,:,ind);



% 
% 
% 
% %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MIXED-EFFECT FIT
% tic
% fprintf('*** MIXED(random)-EFFECT FIT ***\n');
% %% Construct design matrix
% % Polynomials and motion
% poly = cell(1,numruns);
% polyNmotion = cell(1,numruns);
% constant = cell(1,numruns);
% 
% numtime = size(data{p},dimtime)*splitIn;
% for p=1:numruns/splitIn
%     tmp = constructpolynomialmatrix(numtime,0:opt.maxpolydeg(p),0);
%     poly((p-1)*splitIn+1:p*splitIn) = mat2cell(tmp,repmat(size(data{p},dimtime),1,splitIn),2)';
% end
% 
% numtime = size(data{p},dimtime)*splitIn;
% for p=1:numruns
%     polyNmotion{p} = cat(2,poly{p}, ...
%         opt.extraregressors{p}, ...
%         []);
%     tmpConstant = poly{p}; tmpConstant(:,2:end) = zeros(size(tmpConstant(:,2:end)));
%     constant{p} = cat(2,tmpConstant, ...
%         zeros(size(opt.extraregressors{p})), ...
%         []);
% end
% %Reformat to remerge motion regressors that were split before
% polyNmotion_b = reshape(polyNmotion,[opt.splitedIn length(polyNmotion)/opt.splitedIn])';
% constant_b = reshape(constant,[opt.splitedIn length(constant)/opt.splitedIn])';
% polyNmotion = cell(1,size(polyNmotion_b,1));
% constant = cell(1,size(polyNmotion_b,1));
% for ii = 1:size(polyNmotion_b,1)
%     polyNmotion{ii} = catcell(1,polyNmotion_b(ii,:));
%     constant{ii} = catcell(1,constant_b(ii,:));
% end
% clear polyNmotion_b constant_b
% 
% % Conditions
% condLabel = cat(1,ones(numruns/3,1)*1,ones(numruns/3,1)*2,ones(numruns/3,1)*3);
% sessLabel = cell2mat(opt.sessionLabel)';
% 
% condDesign1 = cell(1,3);
% polyNmotionDesign1 = cell(1,3);
% constantDesign1 = cell(1,3);
% condDesign2 = cell(1,3);
% polyNmotionDesign2 = cell(1,3);
% constantDesign2 = cell(1,3);
% for cond = 1:3
%     sess=1;
%     condInd = condLabel==cond & sessLabel==sess;
%     condInd_polyNmotion = condInd(1:opt.splitedIn:end);
%     condDesign1{cond} = blkdiag(cache.rawdesign{condInd});
%     
%     polyNmotionDesign1{cond} = blkdiag(polyNmotion{condInd_polyNmotion});
%     constantDesign1{cond} = blkdiag(constant{condInd_polyNmotion});
%     
%     
%     sess=2;
%     condInd = condLabel==cond & sessLabel==sess;
%     condInd_polyNmotion = condInd(1:opt.splitedIn:end);
%     condDesign2{cond} = blkdiag(cache.rawdesign{condInd});
%     
%     polyNmotionDesign2{cond} = blkdiag(polyNmotion{condInd_polyNmotion});
%     constantDesign2{cond} = blkdiag(constant{condInd_polyNmotion});
% end
% condDesign = reshape(cat(1,condDesign1,condDesign2),1,6);
% polyNmotionDesign = reshape(cat(1,polyNmotionDesign1,polyNmotionDesign2),1,6);
% constantDesign = reshape(cat(1,constantDesign1,constantDesign2),1,6);
% 
% 
% % Merge conditions, polynomials and motion
% condDesign = blkdiag(condDesign{:});
% % sessDesign = catcell(1,sessDesign); sessDesign(:,1:2) = [];
% polyNmotionDesign = blkdiag(polyNmotionDesign{:});
% constantDesign = blkdiag(constantDesign{:});
% 
% results.OLS.mixed.designmatrix = cat(2,condDesign,polyNmotionDesign);% time x regressors
% % results.OLS.mixed.designmatrixCond3 = cat(2,condDesign(end*2/3+1:end,:),polyNmotionDesign(end*2/3+1:end,:));% time x regressors
% 
% % Extract some usefull params
% results.OLS.mixed.designmatrixPieces.cond = cat(2,condDesign,zeros(size(polyNmotionDesign)));
% results.OLS.mixed.designmatrixPieces.motion = cat(2,zeros(size(condDesign)),polyNmotionDesign);
% results.OLS.mixed.designmatrixPieces.constant = cat(2,zeros(size(condDesign)),constantDesign);
% %deal with higher order poly
% ind = find(any(results.OLS.mixed.designmatrixPieces.constant,1));
% for i = 1:unique(opt.maxpolydeg)
%     results.OLS.mixed.designmatrixPieces.(['p' num2str(i)]) = zeros(size(results.OLS.mixed.designmatrixPieces.constant));
%     results.OLS.mixed.designmatrixPieces.(['p' num2str(i)])(:,ind+i) = results.OLS.mixed.designmatrix(:,ind+i);
% end
% 
% %     close all
% %     figure('WindowStyle','docked'); colormap gray
% %     imagesc(results.OLS.mixed.designmatrix)
% %     figure('WindowStyle','docked'); colormap gray
% %     imagesc(results.OLS.mixed.designmatrixPieces.cond)
% %     figure('WindowStyle','docked'); colormap gray
% %     imagesc(results.OLS.mixed.designmatrixPieces.motion)
% %     figure('WindowStyle','docked'); colormap gray
% %     imagesc(results.OLS.mixed.designmatrixPieces.constant,[-1 1])
% 
% 
% 
% %remove constant
% ind = any(results.OLS.mixed.designmatrixPieces.constant,1);
% results.OLS.mixed.designmatrix(:,ind) = [];
% fieldList = fields(results.OLS.mixed.designmatrixPieces);
% for i = 1:length(fieldList)
%     results.OLS.mixed.designmatrixPieces.(fieldList{i})(:,ind) = [];
% end
% results.OLS.mixed.designmatrixPieces = rmfield(results.OLS.mixed.designmatrixPieces,'constant');
% 
% %% Estimate parameters with OLS
% display('computing OLS')
% results.OLS.mixed.parameters = ...
%     mtimescell(olsmatrix2(results.OLS.mixed.designmatrix), ...
%     cellfun(@(x) squish(x,dimdata)',data,'UniformOutput',0));  % regressors x voxels
% 
% for i = 1:length(opt.sessionLabel)
%     respTmp(:,:,i) = results.OLS.mixed.parameters((i-1)*12+1:i*12,:);
% end
% for i = 1:unique(opt.maxpolydeg)
%     ind = any(results.OLS.mixed.designmatrixPieces.(['p' num2str(i)]),1);
%     polyPar.(['p' num2str(i)]) = permute(results.OLS.mixed.parameters(ind,:),[3 2 1]);
% end
% results.OLS.mixed = rmfield(results.OLS.mixed,'parameters');
% 
% respMixed1 = respTmp(:,:,cell2mat(opt.sessionLabel)==1);
% respMixed1 = cat(4,respMixed1(:,:,1:end/3),respMixed1(:,:,end/3+1:end/3*2),respMixed1(:,:,end/3*2+1:end));
% for i = 1:unique(opt.maxpolydeg)
%     polyPar1.(['p' num2str(i)]) = polyPar.(['p' num2str(i)])(:,:,cell2mat(opt.sessionLabel)==1);
%     polyPar1.(['p' num2str(i)]) = cat(4,polyPar1.(['p' num2str(i)])(:,:,1:end/3),polyPar1.(['p' num2str(i)])(:,:,end/3+1:end/3*2),polyPar1.(['p' num2str(i)])(:,:,end/3*2+1:end));
% end
% respMixed2 = respTmp(:,:,cell2mat(opt.sessionLabel)==2);
% respMixed2 = cat(4,respMixed2(:,:,1:end/3),respMixed2(:,:,end/3+1:end/3*2),respMixed2(:,:,end/3*2+1:end));
% for i = 1:unique(opt.maxpolydeg)
%     polyPar2.(['p' num2str(i)]) = polyPar.(['p' num2str(i)])(:,:,cell2mat(opt.sessionLabel)==2);
%     polyPar2.(['p' num2str(i)]) = cat(4,polyPar2.(['p' num2str(i)])(:,:,1:end/3),polyPar2.(['p' num2str(i)])(:,:,end/3+1:end/3*2),polyPar2.(['p' num2str(i)])(:,:,end/3*2+1:end));
% end
% clear respTmp polyPar
% 
% % %Percent BOLD
% % respMixed1 = (respMixed1 - repmat(mean(respMixed1,1),[12 1 1 1]))./repmat(mean(respMixed1,1),[12 1 1 1]);
% % respMixed2 = (respMixed2 - repmat(mean(respMixed2,1),[12 1 1 1]))./repmat(mean(respMixed2,1),[12 1 1 1]);
% 
% for run = 1:size(respMixed1,3)
%     for cond = 1:size(respMixed1,4)
%         results.OLS.mixed.sess1.resp(:,:,:,:,run,cond) =   reshape(respMixed1(:,:,run,cond)',  [xyzsize size(respMixed1(:,:,run,cond),1)]);
%         for i = 1:unique(opt.maxpolydeg)
%             results.OLS.mixed.sess1.(['p' num2str(i)])(:,:,:,:,run,cond) =   reshape(polyPar1.(['p' num2str(i)])(:,:,run,cond)',  [xyzsize size(polyPar1.(['p' num2str(i)])(:,:,run,cond),1)]);
%         end
%     end
% end
% for run = 1:size(respMixed2,3)
%     for cond = 1:size(respMixed2,4)
%         results.OLS.mixed.sess2.resp(:,:,:,:,run,cond) =   reshape(respMixed2(:,:,run,cond)',  [xyzsize size(respMixed2(:,:,run,cond),1)]);
%         for i = 1:unique(opt.maxpolydeg)
%             results.OLS.mixed.sess2.(['p' num2str(i)])(:,:,:,:,run,cond) =   reshape(polyPar2.(['p' num2str(i)])(:,:,run,cond)',  [xyzsize size(polyPar2.(['p' num2str(i)])(:,:,run,cond),1)]);
%         end
%     end
% end
% 
