%% ========================================================================
% [1] Parameter
%
% =========================================================================
% ------------------------------
% [1-1] Setting Parameter
%
% -------------------------------
PARA.VOLTAGE_AMP     = 2;              % unit : Voltage Amplitude
PARA.FREQENCY        = 10000;          % unit : Hz
PARA.REPEAT          = 3;              % Number of Sine pulse
PARA.SENSITIVITY     = 1e-6;
PARA.RATE            = 2e6;
PARA.BUFFER          = 10;             % unit : ms

% ------------------------------
% [1-2] Parameter Check
%
% -------------------------------
myvoltage_assert(0, 0, PARA.VOLTAGE_AMP);

if (PARA.RATE/PARA.FREQENCY < 20)
    error('USER_ERROR : You are "SO" greedy DAQ can not run that speed( %d Hz )'...
        , PARA.FREQENCY)
elseif (PARA.RATE/PARA.FREQENCY < 40)
    warning('USER_WARNING : HIGH SPEED( %d Hz )'...
        , PARA.FREQENCY)
end

%% ========================================================================
% [2] INPUT DATA
%
% =========================================================================
% ------------------------------
% [2-1] Prepare input voltage
%
% -------------------------------
% make buffer
num_of_buf_sample = PARA.RATE / PARA.BUFFER / 1000;

% make time table
myDAQ.Rate   = PARA.RATE;
period       = 1 / PARA.FREQENCY;
time_table   = 0 : 1/PARA.RATE : period;

% make input data
input_unit_data = (PARA.VOLTAGE_AMP * sin(2*pi / period * time_table)).';
input_data      = [zeros(num_of_buf_sample, 1); ...
    repmat(input_unit_data(1:end-1), PARA.REPEAT, 1); ...
    zeros(num_of_buf_sample, 1)];

% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,2,1)
plot(input_unit_data)
title('Unit Input Voltage Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
grid on
txt = {' Frequency(Hz):', PARA.FREQENCY};
text(0, -3/4 * PARA.VOLTAGE_AMP, txt)

subplot(4,2,2)
plot(input_data)
title('All Input Voltage Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
xline(num_of_buf_sample,                      '--','Starting Point');
xline(size(input_data, 1) - num_of_buf_sample,'--','End Point');
grid on


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

% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
if (excute == 1)
    % Stert execution
    start_excute_time       = tic;
    measured_data           = readwrite(myDAQ, input_data);
    measured_data.Variables = -measured_data.Variables;
    fprintf("\n* Finished Measurement *\n");
    
    % ---------------------------------
    % [3-3] Check after Measurement
    %
    % ----------------------------------
    number_of_input_all_data = size(input_data, 1);
    
    if (number_of_input_all_data == myDAQ.NumScansOutputByHardware)
        fprintf("\ninput & scans output by hardware = %d\n", myDAQ.NumScansOutputByHardware)
        fprintf("Generation has terminated with %d scans output by hardware\n", myDAQ.NumScansAcquired);
    else
        warning("your experimental condition is not good ask for program developer")
    end
    
    %% ========================================================================
    % [4] Drow Output Data
    %
    % =========================================================================
    % ---------------------------------
    % [4-1] Drow Measured Voltage Data
    %
    % ----------------------------------
    % Caculate Output I, V
    caculated_data.time    = measured_data.Time;
    caculated_data.voltage = input_data;
    caculated_data.currnet = - measured_data.Variables * PARA.SENSITIVITY;
    
    % Drow Output V-t Grape
    subplot(4,1,2)
    plot(caculated_data.time   (PARA.RATE/PARA.BUFFER/1000 + 1 : end - PARA.RATE/PARA.BUFFER/1000), ...
         caculated_data.currnet(PARA.RATE/PARA.BUFFER/1000 + 2 : end -(PARA.RATE/PARA.BUFFER/1000 - 1)), 'r');
    title('Output Current')
    xlabel("Sec")
    ylabel("Current (A)")
    grid on;
    
    % ---------------------------------
    % [4-2] Caculate & Drow Currnet Data
    %
    % ----------------------------------
    % Drow Output I-V Grape
    subplot(2,1,2)
    fig = plot(caculated_data.voltage(PARA.RATE/PARA.BUFFER/1000 + 1 : end-PARA.RATE/PARA.BUFFER/1000), ...
               caculated_data.currnet(PARA.RATE/PARA.BUFFER/1000 + 2 : end-(PARA.RATE/PARA.BUFFER/1000 - 1)), 'r');
    title('Result Data')
    xlabel("INPUT Voltage (V)")
    ylabel("OUTPUT Ampere (I)")
    grid on;
    
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
    if ~isfolder('b_random_NW_sin_pulse')
        mkdir b_random_NW_sin_pulse
    end
    cd(currentFolder);
    cd('b_random_NW_sin_pulse');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(caculated_data.time(1:2),    strcat(save_index, 'input_data.time.txt'));
    writematrix(caculated_data.voltage(PARA.RATE/PARA.BUFFER/1000 + 1 : end-PARA.RATE/PARA.BUFFER/1000),...
                strcat(save_index, 'input_data.voltage.txt'));
    writematrix(caculated_data.currnet(PARA.RATE/PARA.BUFFER/1000 + 2 : end-(PARA.RATE/PARA.BUFFER/1000 - 1)),...
                strcat(save_index, 'output_data.current.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
end

finish_time = toc(start_excute_time);
fprintf("\nTotal Excute Time        : %.3fsec\n", finish_time);
fprintf("b_random_NW_sin_pulse END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
%
%   File name  : b_random_NW_sin_pulse.m
%   Written by : Jeong, Hakcheon
%                M.S. & PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : July 27, 2022
%   Version    : 1