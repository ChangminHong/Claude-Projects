%% ========================================================================
% [1] Parameter
%
% =========================================================================
% ------------------------------
% [1-1] Setting Parameter
%
% -------------------------------
PARA.MAX_VOLTAGE     = 2;              % unit : Set Mode Voltage
PARA.START_VOLTAGE   = 1;              % unit : Start and *END* Volatge
PARA.MIN_VOLATGE     = -2;             % unit : Reset Mode Voltage
PARA.VOLTAGE_PER_SEC = 10000;          % unit : Voltage / Sec
PARA.REPEAT          = 1;              % Number of Reapeat Set mode & Reset Mode
PARA.SENSITIVITY     = 1e-6;
PARA.RATE            = 2e6;

% ------------------------------
% [1-2] Parameter Check
%
% -------------------------------
myvoltage_assert(PARA.MIN_VOLATGE, PARA.START_VOLTAGE, PARA.MAX_VOLTAGE);

if (PARA.VOLTAGE_PER_SEC > 1e4) 
        error('USER_ERROR : Rising Voltage per sec is too high( %d sec )'...
              , PARA.VOLTAGE_PER_SEC)
elseif (PARA.VOLTAGE_PER_SEC > 1e3)
        warning('USER_WARNING : Rising Voltage per sec is too high( %d sec )'...
                , PARA.VOLTAGE_PER_SEC)
end

if (PARA.START_VOLTAGE ~= 0)
        warning('USER_WARNING : Start voltage is not Zero ( %d Volt )'...
                , PARA.START_VOLTAGE)
end

%% ========================================================================
% [2] INPUT DATA
%
% =========================================================================
% ------------------------------
% [2-1] Prepare input voltage
%
% -------------------------------
myDAQ.Rate = PARA.RATE;

% caculate number of point for input data
Number_of_set_data_points   = (PARA.MAX_VOLTAGE - PARA.START_VOLTAGE) * PARA.RATE / PARA.VOLTAGE_PER_SEC;
Number_of_reset_data_points = (PARA.START_VOLTAGE - PARA.MIN_VOLATGE) * PARA.RATE / PARA.VOLTAGE_PER_SEC;

% Make Input Queue
input_set_data           = linspace(PARA.START_VOLTAGE, PARA.MAX_VOLTAGE, Number_of_set_data_points)';
input_reset_data         = linspace(PARA.START_VOLTAGE, PARA.MIN_VOLATGE, Number_of_reset_data_points)';
reverse_input_set_data   = flip(input_set_data);
reverse_input_reset_data = flip(input_reset_data);

% delete overlap data
if ( PARA.MAX_VOLTAGE ~= PARA.START_VOLTAGE )
input_set_data(1)           = [];
reverse_input_set_data(1)   = [];
end

if ( PARA.MIN_VOLATGE ~= PARA.START_VOLTAGE )
input_reset_data(1)         = [];
reverse_input_reset_data(1) = [];
end

% integrate Queue
input_unit_data = [input_set_data ; reverse_input_set_data ; input_reset_data ; reverse_input_reset_data];
input_all_data  = [0 ; repmat(input_unit_data, PARA.REPEAT, 1) ; 0 ];

% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,2,1)
plot(input_unit_data)
title('Unit Input Voltage Function (SET & RESET mode)')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
grid on

subplot(4,2,2)
plot(input_all_data)
title('All Input Voltage Function (SET & RESET mode)')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
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
    measured_data           = readwrite(myDAQ, input_all_data);
    measured_data.Variables = -measured_data.Variables;
    fprintf("\n* Finished Measurement *\n");
    
% ---------------------------------
% [3-3] Check after Measurement
%
% ----------------------------------
    row = size(input_all_data);
    number_of_input_all_data = row(1);

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
    % Drow Output V-t Grape
    subplot(4,1,2)
    plot(measured_data.Time, measured_data.Variables, 'r');
    title('Output Voltage')
    xlabel("Sec")
    ylabel("Voltage (V)")
    grid on;
    
% ---------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
    % Caculate Output I, V
    caculated_data.voltage = input_all_data;
    caculated_data.currnet = measured_data.Variables * PARA.SENSITIVITY;
    caculated_data.currnet = abs(caculated_data.currnet);
    
    % Drow Output I-V Grape
    subplot(2,1,2)
    semilogy(caculated_data.voltage, caculated_data.currnet, 'r');
    title('RESULT')
    xlabel("INPUT Voltage (V)")
    ylabel("OUTPUT Ampere (I)")
    grid on;
    
end

finish_excute_time   = toc(start_excute_time);
fprintf("Measurement Time : %s\n", measured_data.Time(end));
fprintf("Excute Time      : %.3fsec\n", finish_excute_time);
fprintf("DC_Sweep_END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_DC_Sweep.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
%   Version    : 1