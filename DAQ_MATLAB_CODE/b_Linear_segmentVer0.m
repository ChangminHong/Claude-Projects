%% ========================================================================
% [1] Parameter
%
% =========================================================================
% --------------------------
% [1-1] Setting Param
%
% --------------------------
PARA.SENSITIVITY     = 1e-0;
PARA.RATE            = 1000;

PARA.INPUT           = [[2 0 2]; [1 2 2]; [1 2 4]; [1 4 1]; [1 1 0]]; % if [A, B, C], during A (ms) voltage from B (V) to C (V)
%% ========================================================================
% [2] INPUT
%
% =========================================================================
myDAQ.Rate           = PARA.RATE;

% --------------------------
% [2-0] check operation parameter
%
% --------------------------
mylinear_segment_assert(PARA.INPUT, PARA.RATE);

% --------------------------
% [2-1] Prepare input voltage
%
% --------------------------
num_of_segment = size(PARA.INPUT, 1);
input_data     = [];

for seg_num = 1:num_of_segment
    input_data = [input_data; linspace(PARA.INPUT(seg_num, 2), PARA.INPUT(seg_num, 3), PARA.INPUT(seg_num, 1)/1000*PARA.RATE).'];
end

% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(2,1,1)
plot(input_data)
title('Input Data')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
grid on
hold on

%% ========================================================================
% [3] EXECUTION
%
% =========================================================================
% ------------------------------
% [3-1] Reconfirm before execution
%
% -------------------------------
reconfirm = 'That Sweep is what you want? ( 1 : YES, else : NO )\n';
excute    = input(reconfirm);

if (excute == 1)
% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    % Start Mesurment
    start_excute_time = tic;
    % Mesurment
    measured_data = readwrite(myDAQ, input_data);
    % Time Check
    finish_time = toc(start_excute_time);
    fprintf("\n* Finished Measurement *\n");
    fprintf("Measurement Time : %s\n", measured_data.Time(end));
    fprintf("Excute Time          : %.3f초\n", finish_time);
    
% ---------------------------------
% [3-3] Check after Measurement
%
% ----------------------------------
    % Check # of ScansOutput data
    row = size(input_data);
    number_of_input_all_data = row(1);
    
    if (number_of_input_all_data == myDAQ.NumScansOutputByHardware)
        fprintf("\ninput & scans output by hardware = %d\n", myDAQ.NumScansOutputByHardware)
        fprintf("Generation has terminated with %d scans output by hardware\n", myDAQ.NumScansAcquired);
    else
        warning("your experimental condition is not good ask for program developer")
    end
    
    
%% ========================================================================
% [4] Drow Data
%
% =========================================================================
% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
    subplot(2,1,2)
    plot(measured_data.Time, input_data, 'b-')
    yyaxis left
    title('Input & Output')
    xlabel("Time (sec)")
    ylabel("Voltage (V)")
    hold on
% ---------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
    % Caculate Output I, V
    measured_data.Variables = measured_data.Variables * -PARA.SENSITIVITY;
    % Drow Output I-V Grape
    subplot(2,1,2)
    yyaxis right
    fig = plot(measured_data.Time, measured_data.Variables, 'r-');
    title('Input & Output')
    xlabel("Time (sec)")
    ylabel("Current (A)")
    legend({'input voltage', 'output current'},'Location','best')
    grid on
    hold off
%% ========================================================================
% [6] Save Data
%
% =========================================================================
% ---------------------------------
% [6-1] Caculate data number
%
% ----------------------------------
    % save number not exist
    if ~exist('save_index')
        warning('USER WARNING : Check Your Data Already Saved?');
        reconfirm_save = '( 1 : YES, else : NO ) ***Check Your Data Already Saved?***\n';
        excute_save    = input(reconfirm_save);
        
        if (excute_save == 1)
            save_index = [];
        else
            error('USER ERROR : BREAK CODE');
        end
    end
    save_index = mysave(save_index);
    
% ---------------------------------
% [6-2] Find dirction & save data
%
% ----------------------------------
currentFolder = pwd;

    if ~isfolder('b_Linear_segmentVer0')
        mkdir b_Linear_segmentVer0
    end
    cd(currentFolder);
    cd('b_Linear_segmentVer0');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(measured_data.Time,      strcat(save_index, '_measured_data_time.txt'));
    writematrix(measured_data.Variables, strcat(save_index, '_caculated_data.currnet.txt'));
    writematrix(input_data,              strcat(save_index, '_input_data.txt'));
    saveas(fig,                          strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
end

fprintf("b_Linear_segmentVer0 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_Linear_segmentVer0.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022