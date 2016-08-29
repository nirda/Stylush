function StyleSearcher(FileDir,person,col)
%% PlateAnalyzer(FileDir,Time)
% -------------------------------------------------------------------------
% Purpose: Open the plate analyzing screen
% 
% Arguments: FileDir - The full path of the directory
%            Time (default 0) - if no starting time was found in the data file 
%            the time argument will be used (with 0 value if no such argument was
%            given by the user)
% -------------------------------------------------------------------------
% Nir Dick 2015

    global state;
    global appData;
    
    
    %% Load data
    
    % Load signal
    signal=importdata(FileDir);
    signal=signal(signal(:,1)==person,col);
    t1=10000:30000;
    signal=signal(t1);
    times=1:length(signal);
    signal=wden(signal,'rigrsure','s','one',5,'sym8');
    
    state.time=1;
    state.isSegHide=0;
    state.isSigHide=0;
    appData.times=times;
    appData.signal=signal;
    appData.segments=[1 length(signal)];

    % find current icons directory

    [cdir cname ctype]=fileparts(mfilename('fullpath'));  
    
    %% Create gui
    h.fig=figure('units','pixels',...
                  'position',[50 50 1750 955],...
                  'name','StyleSearcher',...
                  'resize','off');
    figcolor=get(h.fig,'color');  
    h.sigax = axes('units','pixels',...
                'position',[50 70 800 800],...
                'fontsize',8,...
                'nextplot','add','Tag','sigax');

    h.segax = axes('units','pixels',...
                     'position',[900 70 800 800],...
                     'fontsize',8,...
                     'nextplot','add','Tag','GRAPHAX');

    set(h.fig,'KeyPressFcn',@(src,e)KeyPressFcn(src,e,h,FileDir));


    h.edc = uicontrol('style','text','unit','pix','position',[30 900 200 20],...
                     'fontsize',10,'String','Choose discont TH:',...
                     'backgroundcolor',figcolor);

    h.ed = uicontrol('style','edit','unit','pix','position',[210 900 60 20],...
                     'fontsize',10);    

    [icon map]=imread(strcat(cdir,'/Icons/Search.png'));
 
    h.search= uicontrol('style','pushbutton',...
                     'unit','pix',...
                     'position',[280 900 20 20],...
                     'CData',icon,'Callback',@(objH,e)search(objH,e,h));  
                 
     buildToolBar(h,cdir)

     plotSignal(h,0);
     
     % find discontinuity points
     
     % calculate signal pca
     spectralPCA(h.segax);
end

function spectralPCA(h)
    global appData;
    %signal=appData.signal(10000:10000+60*60*10);
%     t1=10000:30000;
     signal=appData.signal;
    len=length(signal);

    lowband=2;
    highband=20;
    
    Fs=60;
    nfft=2^ceil(log2(Fs));
    
    % for each time slice from 10 minutes to 1 second
    lows=2;
    highs=60;
    step=10;
    F=[];
    for i=lows:step:highs
        [s,f,t]=spectrogram(signal,hamming(i),i-1,nfft,Fs);
        rangef=find(f<highband & f>lowband);
        currF=zeros(length(rangef),len);
        currF(:,int64(t*Fs))=normc(log(abs(s(rangef,:))));
        F=[F;currF];
    end
    
    myfilter = fspecial('gaussian',[4 4], 0.5);
    F = imfilter(F, myfilter, 'replicate');
    F=normc(F);
    
    figure; imagesc(F);
    % Principal components
    [coeff,~]=princomp(F');
    F2=(coeff(:,1:2)'*F)';
    appData.pca=F2;
    scatter(h,F2(:,1),F2(:,2),[]);
end

function segments=findDiscont(th)
    global appData;
    signal=appData.signal;
    signal2=zeros(size(signal));
    signal2(1:length(signal)-1)=signal(2:length(signal));
    diff=abs(signal2-signal);
    segments=find(diff>th);
end

%% function buildToolBar(handles,FileDir,times)
% -------------------------------------------------------------------------
% Purpose: Build the toolbar for the ScanLagApp 
%
% Arguments: handles - The set of gui handles
%            FileDir - the results file directory
%            times - vector of times
% -------------------------------------------------------------------------
% Nir Dick Sept. 2013
% -------------------------------------------------------------------------
function buildToolBar(handles,dir)
    
    set(handles.fig,'toolbar','figure');
    
    % Remove unwanted icons
    
    b = findall(handles.fig,'ToolTipString','Edit Plot');
    set(b,'Visible','Off');
    
    % Add icons to the toolbar
    
    ht = uitoolbar(handles.fig);
    
    [icon map]=imread(strcat(dir,'/Icons/HideSeg.png'));
    hideSegh = uipushtool('Parent',ht,'CData',icon,'Tag','HideSeg');
    set(hideSegh,'ClickedCallback',...
                   @(h,e)hideSegClickedCallback(h,e,handles));
               
    [icon map]=imread(strcat(dir,'/Icons/HideSig.png'));
    hideSigh = uipushtool('Parent',ht,'CData',icon,'Tag','HideSig');
    set(hideSigh,'ClickedCallback',...
                   @(h,e)hideSigClickedCallback(h,e,handles));
               
    [icon map]=imread(strcat(dir,'/Icons/ChooseSeg.png'));
    chooseh = uipushtool('Parent',ht,'CData',icon,'Tag','Choose');
    set(chooseh,'ClickedCallback',...
                   @(h,e)chooseSegClickedCallback(h,e,handles));
               
    [icon map]=imread(strcat(dir,'/Icons/ChooseSig.png'));
    chooseh = uipushtool('Parent',ht,'CData',icon,'Tag','Choose');
    set(chooseh,'ClickedCallback',...
                   @(h,e)chooseSigClickedCallback(h,e,handles));
               
end

function hideSegClickedCallback(h,e,handles)
    global state;

    % Add selection listener to all the lines in the graph

    
    state.isSegHide=1-state.isSegHide;
    allpoints = findobj(handles.sigax,'Tag',getSegStr);
    if state.isSegHide
        set(allpoints,'Visible','off');
    else
        set(allpoints,'Visible','on');
    end
end

function hideSigClickedCallback(h,e,handles,forcev)
    global state;
    
    if nargin<4
        forcev=[];
    end

    % Add selection listener to all the lines in the graph

    
    allpoints = findobj(handles.sigax,'Tag',getSigStr);
    if ~isempty(forcev)
        if forcev
            state.isSigHide=0;
            set(allpoints,'Visible','on');
        else
            state.isSigHide=1;
            set(allpoints,'Visible','off');
        end
    else
        state.isSigHide=1-state.isSigHide;
        if state.isSigHide
            set(allpoints,'Visible','off');
        else
            set(allpoints,'Visible','on');
        end
    end
end

function plotSignal(handles,isseg)
    global appData;
    
    t=1:length(appData.signal);
    segs=NaN(size(appData.signal));
    if isseg
        sl=1;    
        for i=2:length(appData.segments)
              el=appData.segments(i);
              len=el-sl+1;
              p=6;
              r=floor(len/p);
              csl=sl+r;
              cel=el-r;
              seg=appData.signal(csl:cel);
              segs(csl:cel)=seg;
              sl=el;
        end
        hold on;
        plot(handles.sigax,t,segs,'Tag',getSegStr);
    else
        plot(handles.sigax,1:length(appData.signal),appData.signal,'Tag',getSigStr);
    end
    
    hold off;
end

function search(objH,e,handles)
    global appData;
    
    str=get(handles.ed,'string');
    [th,status]=str2num(str);

    if (status)
        allpoints = findobj(handles.sigax,'Tag',getSegStr);
    
        % Add selection listener to all the lines in the graph
        if (~isempty(allpoints))
            delete(allpoints);
        end;
        
        disp(['Calculating segments for TH=' str '...']);
        appData.segments=findDiscont(th);
        disp(['Plotting segments for TH=' str '...']);
        plotSignal(handles,1);
        disp(['Finished TH=' str]);
    end
end

function str=getSegStr
    str='seg';
end

function str=getSigStr
    str='sig';
end

function chooseSegClickedCallback(h,e,handles)
    global appData;
    axes(handles.segax);
    h1 = impoly();
    nodes = getPosition(h1);
    f=appData.pca;
    appData.selected=find(inpolygon(f(:,1),f(:,2), nodes(:,1), nodes(:,2)));
    
    delete(h1);
    
    showSelected(handles);
    
end

function chooseSigClickedCallback(h,e,handles)
    global appData;
    
    
    axes(handles.sigax);
    hrect = imrect;
    pos = getPosition(hrect);
    x1=pos(1);
    x2=x1+pos(3);
    t=appData.times;
    t=t>=x1&t<=x2;
    t=find(t);
    
    hideSigClickedCallback(h,e,handles,0);
    
    delete(hrect);
    
    appData.selected=t;
    showSelected(handles)
end

function showSelected(handles)
    global appData;
    
    sigstr='sig selected';
    segstr='seg selected';
    
    htmp=findobj(handles.sigax,'Tag',sigstr);
    if ~isempty(htmp)
        delete(htmp);
    end
    
    htmp=findobj(handles.segax,'Tag',segstr);
    if ~isempty(htmp)
        delete(htmp);
    end
    
    selt = appData.selected;
    sigt = appData.signal(selt);
    segt = appData.pca(selt,:);
    c = linspace(1,100,length(selt));
    axes(handles.sigax)
    hold on;
    scatter(handles.sigax,selt,sigt,[],c,'Tag',sigstr);
    hold off;
    axes(handles.segax)
    hold on;
    scatter(handles.segax,segt(:,1),segt(:,2),[],c,'filled','Tag',segstr);
    hold off;
end


% % %% function [min, max,times]=getSliderTimeData(FileDir)
% % % -------------------------------------------------------------------------
% % % Purpose: Get the time data for the silder when building it 
% % %
% % % Arguments: FileDir - Directory of time axis
% % % Outputs: min - the minimum value for the slider
% % %          max - the maximum value of the slider
% % %          times - the times for the slider
% % % -------------------------------------------------------------------------
% % % Nir Dick Sept. 2013
% % % -------------------------------------------------------------------------
% % function [min, max,times]=getSliderTimeData(FileDir,StartTime)
% %      TimeAxisDir=fullfile(FileDir, 'Results', 'TimeAxis');
% %      load(TimeAxisDir);
% %      times=TimeAxis;
% %      FileNum  = find(times,1,'last');   
% %      min=1;
% %      max=FileNum;
% % end
% 
% %% function initPics(handle,FileDir)
% % -------------------------------------------------------------------------
% % Purpose: show the first plate image (i.e. black picture with empty plate)
% %
% % Arguments: startTime - Directory of time axis
% %            handle - the first scan time
% %            FileDir - Directory of the data files
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function initPics(startTime,handle,FileDir,appData)
%     global state;
%     h=gca;
%     axes(handle);
%     
%     fileName=getFileName(startTime,appData.times,appData.imagesName);
%     numOfColonies=getColoniesNumber(appData);
%     title=GetTitle(startTime,numOfColonies,appData.description);
%     PlotPlateByData(...
%      FileDir,fileName,1,title,0,appData.limitsBW,handle,appData.background)
%     initImg=findobj(handle, 'Tag', 'ImageColony');
%     if (~isempty(initImg))
%         set(initImg,'Tag','ImageColony0');
%     end;
%     
%     if (~isempty(h))
%         axes(h);
%     end
% end
% 
% %% function initAreaGraph(handles,FileDir)
% % -------------------------------------------------------------------------
% % Purpose: Show the area graph
% %
% % Arguments: handles - Dall the ralevant handles
% %            FileDir - the directory of the results
% %            keepScaleFlag - an indication if tosave previous scaling or
% %            not.
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function initAreaGraph(handles,keepScaleFlag,appData)
%     global state;
%     if nargin<3
%         keepScaleFlag=0;
%     end
%     h=gca;
%     axes(handles.graphax);
%     
%     prevxlim=get(handles.graphax,'xlim');
%     prevylim=get(handles.graphax,'ylim');
%     
%     allPrevLines = findobj(handles.graphax,'Type','line');
%     
%     % Add selection listener to all the lines in the graph
%     if (~isempty(allPrevLines))
%         delete(allPrevLines);
%     end;
%     
%     ShowAreaGraphByData(...
%                   0,gca,state.ignored,appData.area,appData.times,...
%                   appData.colors,appData.description);
%     
%     allLines = findobj(handles.graphax,'Type','line');
%     
%     % Add selection listener to all the lines in the graph
%     if (~isempty(allLines))
%         set(allLines,'ButtonDownFcn',...
%                @(objH, eventH)lineSelected(objH, eventH,handles));
% 
%     end;
%     
%     if (~isempty(prevxlim)&&~isempty(prevylim)&&keepScaleFlag)
%         set(handles.graphax,'xlim',prevxlim,'ylim',prevylim);
%     end
%             
%     
%     % Go back to current axes
%     if (~isempty(h))
%         axes(h);
%     end;
% end
% 
% %% function sliderChange(ObjH, EventData, times,FileDir,handles) 
% % -------------------------------------------------------------------------
% % Purpose: This handler manage the slider's value changing event.
% %          (arise when dragging the slider)
% %
% % Arguments: times - list of all available times 
% %            FileDir - the directory of the results
% %            handles - the relevant handles
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function sliderChange(ObjH, EventData,FileDir,handles,...
%                       appData) 
%     global state;
%     set(handles.worktxt,'Visible','on');
%     
%     % update state's time
%     val =round(get(ObjH,'Value'));
%     state.time=appData.times(val);
%     
%     handleTimeChange(FileDir,handles,appData);
%                  
%     drawnow;
%     set(handles.worktxt,'Visible','off');
% end
% 
% %% function sliderChange(ObjH, EventData, times,FileDir,handles) 
% % -------------------------------------------------------------------------
% % Purpose: The ButtonDownFcn event handler of the slider
% %
% % Arguments: times - list of all available times 
% %            FileDir - the directory of the results
% %            handles - the relevant handles
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function sliderCallBack(ObjH,EventData,FileDir,handles,appData)
%     global state;
%     set(handles.worktxt,'Visible','on');
%     
%     % update state's time
%     val =round(get(ObjH,'Value'));
%     state.time=appData.times(val);
%     
%     handleTimeChange(FileDir,handles,appData);
% 
%     set(handles.worktxt,'Visible','off');
% end
% 
% %% function handleTimeChange(times,FileDir,handles)
% % -------------------------------------------------------------------------
% % Purpose: This function should be called when the time was changed in the
% % slider. The method get the current state and change the gui according to
% % it.
% %
% % Arguments: times - list of all available times 
% %            FileDir - the directory of the results
% %            handles - the relevant handles
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function handleTimeChange(FileDir,handles)
%     global state;
%     global appData;
%     
%     times
%     
%     % Move the time line to the new state
%     updateAreaGraphCurrLine(state.time,handles.graphax);
%     
%     % Get selected colony (in order to keep the selected one on the screen)
%     selNumStr=num2str(getSelectedColony());
%     
%     axes(handles.picax);
%        
%     handlePlatePlot(handles,FileDir,appData);
%                 
%     
%     % delete old numbering
%     deleteNumbersText(handles);
%   
%     if (state.numbers)
%         % Print new numbering
%         handleNumbersPlot(handles,selNumStr,appData,state.time);
%     end
%    
%      fclose('all');
% end
% 
% %% function updateAreaGraphCurrLine(time,graphAxes)
% % -------------------------------------------------------------------------
% % Purpose: This function update the position of the time line of the area
% % graph.
% %
% % Arguments: time - current time
% %            graphAxes - the graph axes
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function updateAreaGraphCurrLine(time,graphAxes)
%     currLine = findobj(graphAxes, 'Tag', 'AreaCurrTimeLine');
%     if (~isempty(currLine))
%         delete(currLine);
%     end;
%     m=get(graphAxes,'YLim');
%     hold(graphAxes,'on');
%     pH=plot(graphAxes,[time,time],[m(1,1),m(1,2)],':k');
%     hold(graphAxes,'off');
%     set(pH,'Tag','AreaCurrTimeLine');
% end
% 
% %% handleColonySelection(colonyNumber, graphH,picH)
% % -------------------------------------------------------------------------
% % Purpose: This function handles the event of selecting some colony number
% %
% % Arguments: colonyNumber - the selected colony number
% %            graphH       - the graph axes
% %            picH         - the picture handler
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function handleColonySelection(colonyNumber, graphH,picH)
%     
%     downplayPrevText(picH);
%     highlightTextByNum(num2str(colonyNumber),picH);
%     selectLine(num2str(colonyNumber),graphH);
% end
% 
% %% selectLine(colonyNumberStr,graphH)
% % -------------------------------------------------------------------------
% % Purpose: Select wanted line (of wanted colony) in the area graph
% %
% % Arguments: colonyNumberStr - the colony's number
% %            graphH       - the graph axes
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function selectLine(colonyNumberStr,graphH)
%     set (graphH,'Selected','off');
%     prevLine = findobj(graphH,'Selected','on');
%     currLine = findobj(graphH,'Tag',strcat('colony',colonyNumberStr));
%     if (~isempty(prevLine))
%         set(prevLine,'Selected','off','LineWidth',1);
%     end;
%     if (~isempty(currLine))
%         set(currLine,'Selected','on','LineWidth', 5);
%         uistack(currLine,'top');
%     end;
% end
% 
% %% function lineSelected(objH,eventH,handles)
% % -------------------------------------------------------------------------
% % Purpose: The handler of the the line selection event in the area graph
% %
% % Arguments: handles - relevant handles of the graph
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function lineSelected(objH,eventH,handles)
%     global state;
%     
%     tag=get(objH,'Tag');
%     cNumStr=tag(7:end);
%     state.selected=str2num(cNumStr);
%     downplayPrevText(handles.picax);
%     highlightTextByNum(cNumStr,handles.picax);
%     selectLine(cNumStr,handles.graphax);
% end
% 
% %% function highlightTextByNum(cNumStr,picH)
% % -------------------------------------------------------------------------
% % Purpose: Sign in gui that sent colony is selected.
% %
% % Arguments: cNumStr - the colony's number
% %            picH - the pictures axes.
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function highlightTextByNum(cNumStr,picH)
%     currText=findobj(picH,'Type','text','String',cNumStr);
%     
%     if (~isempty(currText))
%         highlightText(currText);
%     end;
% end
% 
% %% function highlightText(textH)
% % -------------------------------------------------------------------------
% % Purpose: Highlight text. current - a white square around the text
% %
% % Arguments: textH - the text to highlight
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function highlightText(textH)
%     set(textH,'EdgeColor','white');
% end
% 
% %% function downplayText(textH))
% % -------------------------------------------------------------------------
% % Purpose: cancel text highlighting
% %
% % Arguments: textH
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function downplayText(textH)
%     set(textH,'EdgeColor','none');
% end
% 
% %% function downplayPrevText(picH)
% % -------------------------------------------------------------------------
% % Purpose: cancel previous selected colony's highlighting (without knowing
% % what colony actually was selected.
% %
% % Arguments: picH - picture axes
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function downplayPrevText(picH)
%     prevText=findobj(picH,'Type','text','EdgeColor','white');
%     
%     if (~isempty(prevText))
%         downplayText(prevText);
%     end;
% end
% 
% %% function getSelectedColonyByLine(handle)
% % -------------------------------------------------------------------------
% % Purpose: Get the selected colony's number by the area graph.
% %
% % Arguments: handle - graph axes
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function [selNumStr]=getSelectedColonyByLine(handle)
%     selNumStr='none';
%     selectedLine=findobj(handle,'Type','line','Selected','on');
%     if (~isempty(selectedLine))
%         tag=get(selectedLine,'Tag');
%         selNumStr=tag(7:end);
%     end
% end
% 
% function selected=getSelectedColony()
%     global state;
%     
%     selected=state.selected;
% end
% 
% %% function updatePlotPlate(times,FileDir,handles)
% % -------------------------------------------------------------------------
% % Purpose: Update the plate plotting by current state
% %
% % Arguments: times - times vec
% %            FileDir - the file directory
% %            handles - the handles of the gui
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function updatePlotPlate(FileDir,handles,appData)
%     
%     handlePlatePlot(handles,FileDir,appData);
%                 
%     textsNumH=findobj(handles.picax,'Type','text');
%     
%     % Since we didnt change the numbering, but plotted a new image,
%     % we need to move the numbers above the image
%     uistack(textsNumH,'top');
% end
% 
% %% function textNumberSelected(objH, eventH,graphH,FileDir)
% % -------------------------------------------------------------------------
% % Purpose: the handler of selecting a number in the picture
% %
% % Arguments: graphH - graph axes
% %            FileDir - the data directory
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function textNumberSelected(objH, eventH,graphH)
%     global state;
%     selectionType=get(gcbf,'SelectionType');
%     colonyNumber=str2num(get(objH,'String'));
%     switch selectionType
%         case 'open'
%             % nothing for double click
%         case 'normal',
%             picH=get(objH,'Parent');
%             state.selected=colonyNumber;
%             handleColonySelection(colonyNumber,graphH,picH); 
%     end 
% end
% 
% %% function deleteNumbersText(handles)
% % -------------------------------------------------------------------------
% % Purpose: clean all numbers text
% %
% % Arguments: handles - the handles of the gui
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function deleteNumbersText(handles)
%     axesHandlesToChildObjects = findobj(handles.picax, 'Type', 'text');
%     if ~isempty(axesHandlesToChildObjects)
%         delete(axesHandlesToChildObjects);
%     end
% end
% 
% %% function handlePlatePlot(handles,time,FileDir,state)
% % -------------------------------------------------------------------------
% % Purpose: Update the plate plotted by current state
% %
% % Arguments: time - wanted time
% %            FileDir - the file directory
% %            handles - the handles of the gui
% %            state - the current state of the program
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function handlePlatePlot(handles,FileDir,appData)
%     
%     global state;
%     
%     % Delete current picture
%     axesHandlesToChildObjects=findobj(...
%                     handles.picax, 'Tag', 'ImageColony');
%     
%     if (~isempty(axesHandlesToChildObjects))
%         delete(axesHandlesToChildObjects);
%     end;
%     
%     NColonies=getColoniesNumber(appData);  
%     title=GetTitle(state.time,NColonies,appData.description);
%     fileName=getFileName(state.time,appData.times,appData.imagesName);
%     % Check the state for what picture option the user want
%     if (state.pic==0)
%         % Plot analysis
%         PlotPlateAnalysisByData(...
%                           FileDir,fileName,handles.picax,appData.limitsBW,...
%                           appData.th,appData.background,appData.mask,...
%                           appData.lrgb,title,0);
%     elseif (state.pic==1)
%        % Plot picture
%        if state.bw
%            limits=appData.limitsBW;
%        else 
%            limits=appData.limitsC;
%        end
%        
%        PlotPlateByData(...
%                  FileDir,fileName,state.bw,title,0,limits,...
%                  handles.picax,appData.background);
%     end;
% end
% 
% %% function handleNumbersPlot(time,handles,FileDir,selNumStr)
% % -------------------------------------------------------------------------
% % Purpose: Handle the plotting of the numbers
% %
% % Arguments: time - wanted time
% %            FileDir - the file directory
% %            handles - the handles of the gui
% %            selNumStr - selected colony's number
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function handleNumbersPlot(handles,selNumStr,appData,time)
%     global state;
%     
%     % Plot the numbers for current time
%     PlotPlateColoniesNumbersByData(time,appData.centroid,state.ignored,...
%                                    appData.times,0);
%                               
%     % Set the handler for selection event for each number
%     textNumbers = findobj(handles.picax, 'Type', 'text');
% 
%     if (~isempty(textNumbers))
%         colonyNum = size(textNumbers,1);
%         
%         set(textNumbers,'ButtonDownFcn',...
%                   @(objH, eventH)textNumberSelected(...
%                             objH, eventH,handles.graphax));
%         
%         % Highlight the selected
%         selected=findobj(handles.picax, 'Type', 'text','String',selNumStr);
%         if (~isempty(selected))
%             highlightText(selected);
%         end
%     end
% end
% 
% %% function analysisClickedCallback(h,e,oldH,handles,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: Handle the choosing of the show analysis event
% %
% % Arguments: times - time axis
% %            FileDir - the file directory
% %            handles - the handles of the gui 
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function analysisClickedCallback(h,e,oldH,handles,FileDir,appData)
%     global state;
%     state.pic=0;
%     
%     updatePlotPlate(FileDir,handles,appData);
%     colorH=findobj('Tag','ColorMenu');
%     
%     % disable the BW/COLOR button (since it's relevant to picture option
%     % only)
%     set(colorH,'Enable','off');
% end
% 
% %% function pictureClickedCallback(h,e,oldH,handles,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: Handle the choosing of the show picture event
% %
% % Arguments: times - time axis
% %            FileDir - the file directory
% %            handles - the handles of the gui 
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function pictureClickedCallback(h,e,oldH,handles,FileDir,appData)
%     global state;
%     state.pic=1;
%     updatePlotPlate(FileDir,handles,appData);
%     colorH=findobj('Tag','ColorMenu');
%     set(colorH,'Enable','on');
% end
% 
% %% function numbersClickedCallback(h,e,handles,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: Handle the showing and hiding of numbers
% %
% % Arguments: times - time axis
% %            FileDir - the file directory
% %            handles - the handles of the gui 
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------

% 
% %% function colorClickedCallback(h,e,handles,FileDir,times,iconsdir)
% % -------------------------------------------------------------------------
% % Purpose: Handle the choosing of BW/Color option whan showing the picture
% %
% % Arguments: times - time axis
% %            FileDir - the file directory
% %            handles - the handles of the gui 
% %            iconsdir - directory of icons
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function colorClickedCallback(h,e,handles,FileDir,iconsdir,...
%                               appData)
%     global state;
%     set(handles.worktxt,'Visible','on');
%     
%     state.bw=1-state.bw;
%     
%     % switch between icons
%     if (state.bw)
%        [icon map]=imread(strcat(iconsdir,'\Icons\Color.png'));
%     else
%        [icon map]=imread(strcat(iconsdir,'\Icons\BW.png'));
%     end
%     set(h,'CDATA',icon);
%        
%     % Update picture
%     updatePlotPlate(FileDir,handles,appData);
%                      
%     set(handles.worktxt,'Visible','off'); 
% end
% 
% %% function getState(handles,times)
% % -------------------------------------------------------------------------
% % Purpose: This function build a state data structure representing the
% % wanted state of the system. the state contains the current time, the
% % picture / analysis preview option and, the BW / Color options for the
% % picture preview and the hide/show flag of the numbering.
% %
% % Arguments: times - time axis
% %            handles - the handles of the gui 
% %
% % Return: The state struct
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function [state1]=getState(handles,times)
%     global state;
%     state1=state;
% end
% 
% %% function setcolonyTextColor(colonyNumStr,handles,color)
% % -------------------------------------------------------------------------
% % Purpose: color colony's text in wanted color
% %
% % Arguments: colonyNumStr - the wanted colony
% %            handles - gui handles
% %            color - wanted color
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function setcolonyTextColor(colonyNumStr,handles,color)
%     colonyTextH=findobj(handles.picax,'Type','text','string',colonyNumStr);
%     if (~isempty(colonyTextH))
%         set(colonyTextH,'color',color);
%     end
% end
% 
% %% function excludeClickedCallback(h,e,handles,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: The excluding event handler
% %
% % Arguments: FileDir - data directory
% %            handles - gui handles
% %            times - time axis
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function excludeClickedCallback(h,e,handles,FileDir,appData)
%     excludeSelected(handles,FileDir,appData);
% end
% 
% %% function excludeSelected(handles,FileDir)
% % -------------------------------------------------------------------------
% % Purpose: exclude selected colony
% %
% % Arguments: FileDir - data directory
% %            handles - gui handles
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function excludeSelected(handles,FileDir,appData)
%     global state;
%     
%     % Get selected colony
%     colonyNumber=getSelectedColony();
%     colonyNumberStr=num2str(colonyNumber);
%     
%     if ~isempty(colonyNumber)
%         IgnoredColonies=getIgnoredColonies(FileDir);
%         
%         if (~IgnoredColonies(colonyNumber))
%             % Exclude colony
%             IgnoredColonies(colonyNumber)=2;
%             state.ignored=IgnoredColonies;
%              
%             % Save change to file
%             save(GetDataName(FileDir),'IgnoredColonies','-append');
%             
%             % Color the number so it will sign that it was excluded
%             setcolonyTextColor(colonyNumberStr,handles,[1 1 0])
%             
%             % update area graph
%             initAreaGraph(handles,1,appData);
% 
%             handleColonySelection(colonyNumberStr,handles.graphax,...
%                                   handles.picax);
%             
%             NColonies=getColoniesNumber(appData);
%             currTitle=GetTitle(state.time,NColonies,appData.description);
%             title(handles.picax,currTitle);
%         end
%     end
% end
% 
% %% function includeClickedCallback(h,e,handles,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: The including event handler
% %
% % Arguments: FileDir - data directory
% %            handles - gui handles
% %            times - time axis
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function includeClickedCallback(h,e,handles,FileDir,appData)
%     includeSelected(handles,FileDir,appData);
% end
% 
% %% function includeSelected(handles,FileDir)
% % -------------------------------------------------------------------------
% % Purpose: include selected colony
% %
% % Arguments: FileDir - data directory
% %            handles - gui handles
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function includeSelected(handles,FileDir,appData)
%     global state;
%     
%     % Get selected colony
%     colonyNumber=getSelectedColony();
%     colonyNumberStr=num2str(colonyNumber);
%    
%     if ~isempty(colonyNumber)
%         IgnoredColonies=getIgnoredColonies(FileDir);
%         if (IgnoredColonies(colonyNumber))
%             % Include colony
%             IgnoredColonies(colonyNumber)=0;
%             state.ignored=IgnoredColonies;
%             % Save change to file
%             save(GetDataName(FileDir),'IgnoredColonies','-append');
%             
%             % Color the number so it will sign that it wasn't excluded
%             setcolonyTextColor(colonyNumberStr,handles,[1 1 1])
%             
%             % update area graph
%             initAreaGraph(handles,1,appData);
%             
%             handleColonySelection(colonyNumberStr,handles.graphax,...
%                                   handles.picax);
%             
%             NColonies=getColoniesNumber(appData);
%             currTitle=GetTitle(state.time,NColonies,appData.description);
%             title(handles.picax,currTitle);
%         end
%     end
% end
% 
% %% function KeyPressFcn(src,e,h,FileDir,times)
% % -------------------------------------------------------------------------
% % Purpose: The figure's key pressed event handler. Here the keyboard
% % shortcuts are being defined.
% %
% % Arguments: FileDir - data directory
% %            h - gui handles
% %            times - time axis
% % -------------------------------------------------------------------------
% % Nir Dick Sept. 2013
% % -------------------------------------------------------------------------
% function KeyPressFcn(src,e,h,FileDir,appData)
%     mod=e.Modifier;
%     key=e.Key;
%     
%     % Check for eclude option
%     if ((strcmp(key,'e'))&&(size(mod,1)==1)&&(size(mod,2)==1)&&...
%          strcmp(mod,'control'))
%         excludeSelected(h,FileDir,appData);
%     % Check for include option
%     elseif ((strcmp(key,'i'))&&(size(mod,1)==1)&&(size(mod,2)==1)&&...
%          strcmp(mod,'control'))
%         includeSelected(h,FileDir,appData);
%     end
% end
% 
% function FileName=getFileName(Time,Times,FilesName)
%     currFileNum=find(Times<=Time,1,'last');
%     FileName=FilesName{currFileNum};
% end
% 
% function IgnoredColonies=getIgnoredColonies(FileDir)
%     load(GetDataName(FileDir),'IgnoredColonies');
% end
% 
% function NColonies = getColoniesNumber(appData)
%     global state;
%     
%     idx=find(appData.times==state.time);
%     NColonies=length(find((appData.area(idx,:)>0).*~state.ignored'));
% end