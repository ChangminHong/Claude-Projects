%% ========================================================================
% [1] Parameter
%
% =========================================================================
% --------------------------
% [1-1] Setting Param
%
% --------------------------
%  Ex) SET_MODE
%        -----  <-(SET_PULSE_VOLTAGE)
%       |     | (READ_PULSE_VOLTAGE56)-> -----                 ----- 
%       |     |                         |     |               |     |
%  ------     ---------------------------     -----------------     -------
%  <----------------><-------------><-------------><----->    <----->
%     S_P_DURATION    S_P_INTERVAL  RD_P_DURATION  RD_P_INTERVAL  DUTY_CYCLE
% =========================================================================
PARA.SENSITIVITY     = 1e-0;
PARA.RATE            = 2e5;

PARA.NUMB_OF_SET              = 10;
PARA.NUMB_OF_RESET            = 10;

PARA.SET_HIGH_VOLT   = 2;        % Uint : voltage
PARA.RESET_HIGH_VOLT = -2;
PARA.READ_HIGH_VOLT  = 1;

 PARA.SET_PULSE_DURATION   = 0.01;       % Uint : millisec
 PARA.RESET_PULSE_DURATION = 0.01;
 PARA.READ_PULSE_DURATION  = 0.01;

PARA.SET_AFTER_INTERVAL   = 0.01;     % Uint : millisec
PARA.RESET_AFTER_INTERVAL = 0.01;     % low
PARA.READ_AFTER_INTERVAL  = 0.01;

PARA.SET_PULSE_DUTY_CYCLE   = 100;   % Uint : percentage
PARA.RESET_PULSE_DUTY_CYCLE = 100;
PARA.READ_PULSE_DUTY_CYCLE  = 100;

PARA.READ_MEAN_START_PERCENT = 0;
PARA.READ_MEAN_END_PERCENT   = 100;

%% ========================================================================
% [2] INPUT
%
% =========================================================================
% --------------------------
% [2-0] check operation parameter
%
% --------------------------
myvoltage_assert(PARA.RESET_HIGH_VOLT, PARA.READ_HIGH_VOLT, PARA.SET_HIGH_VOLT);

mytime_assert(PARA.SET_PULSE_DURATION, PARA.SET_PULSE_DUTY_CYCLE, PARA.SET_AFTER_INTERVAL, PARA.RATE );
mytime_assert(PARA.RESET_PULSE_DURATION, PARA.RESET_PULSE_DUTY_CYCLE, PARA.RESET_AFTER_INTERVAL, PARA.RATE );
mytime_assert(PARA.READ_PULSE_DURATION, PARA.READ_PULSE_DUTY_CYCLE, PARA.READ_AFTER_INTERVAL, PARA.RATE );

% --------------------------
% [2-1] Prepare input voltage
%
% --------------------------
myDAQ.Rate            = PARA.RATE;

%make read mode voltage function
[ read_unit_pulse_input, read_high_start, read_high_end, read_duration_end ]...
    = mypulse_gen...
            (PARA.READ_HIGH_VOLT, PARA.READ_PULSE_DURATION,...
             PARA.READ_PULSE_DUTY_CYCLE, PARA.READ_AFTER_INTERVAL, myDAQ.Rate );

%make set mode voltage function
[ set_unit_pulse_input, set_high_start, set_high_end, set_duration_end ]...
    = mypulse_gen...
            (PARA.SET_HIGH_VOLT, PARA.SET_PULSE_DURATION,...
              PARA.SET_PULSE_DUTY_CYCLE, PARA.SET_AFTER_INTERVAL, myDAQ.Rate);
input_unit_set_mode = [ set_unit_pulse_input; read_unit_pulse_input ];

%make reset mode voltage function
[ reset_unit_pulse_input, reset_high_start, reset_high_end, reset_duration_end ]...
	= mypulse_gen...
            (PARA.RESET_HIGH_VOLT, PARA.RESET_PULSE_DURATION,...
             PARA.RESET_PULSE_DUTY_CYCLE, PARA.RESET_AFTER_INTERVAL, myDAQ.Rate );
         
input_unit_reset_mode = [ reset_unit_pulse_input; read_unit_pulse_input ];
myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );
% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,3,1)
plot(input_unit_set_mode)
title('Set Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
grid on

subplot(4,3,2)
plot(input_unit_reset_mode)
title('Reset Mode Voltage Unit Function')
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

if (excute == 1)
    %integrate input voltage scandata
    input_data = [ zeros(myDAQ.Rate/1000, 1); read_unit_pulse_input; repmat(input_unit_set_mode, PARA.NUMB_OF_SET, 1); repmat(input_unit_reset_mode, PARA.NUMB_OF_RESET, 1) ];

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
% [4] Drow Output Data
%
% =========================================================================
% ---------------------------------
% [4-1] Drow Measured Voltage Data
%
% ----------------------------------
    % Drow Output V-t Grape
    subplot(4,1,2)
    plot(measured_data.Time, -measured_data.Variables);
    title('Output Voltage')
    xlabel("Sec")
    ylabel("Voltage (V)")
    grid on;
    
% ---------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
    % Caculate Output I, V
    caculated_data.voltage = input_data;
    caculated_data.currnet = measured_data.Variables * -PARA.SENSITIVITY;
    
    % Drow Output I-V Grape
    subplot(4,3,3)
    plot(caculated_data.voltage, caculated_data.currnet, 'ro');
    title('Read Endurance')
    xlabel("Voltage (V)")
    ylabel("Ampere (I)")
    grid on;
    
%% ========================================================================
% [5] Drow Retantion Data
%
% =========================================================================
% ---------------------------------
% [5-1] Set Retantion Data
%
% ----------------------------------
    % Drow Retantion Graph (SET_mode)
    subplot(2,1,2)
    [set_ltpltd.current, set_ltpltd.cycle] =...
        myavg_readpulse(...
            caculated_data.currnet,...
            PARA.NUMB_OF_SET + 1,...
            myDAQ.Rate/1000,...
            set_duration_end + read_duration_end,...
            read_high_start,...
            read_high_end,...
            PARA.READ_MEAN_START_PERCENT,...
            PARA.READ_MEAN_END_PERCENT);
    plot(set_ltpltd.cycle, set_ltpltd.current, 'ro');
    title('Output Voltage')
    xlabel("number of pulse")
    ylabel("Ampere (I)")
    hold on
    
% ---------------------------------
% [5-2] Reset Retantion Data
%
% ----------------------------------
    % Drow Retantion Graph (RESET_mode)
    buf = size(input_unit_set_mode);
    reset_mode_start_point = buf(1) * PARA.NUMB_OF_SET;
    [reset_ltpltd.current, reset_ltpltd.cycle] =...
        myavg_readpulse(...
            caculated_data.currnet,...
            PARA.NUMB_OF_RESET,...
            reset_mode_start_point + read_duration_end + myDAQ.Rate/1000,...
            reset_duration_end + read_duration_end,...
            reset_duration_end + read_high_start,...
            reset_duration_end + read_high_end,...
            PARA.READ_MEAN_START_PERCENT,...
            PARA.READ_MEAN_END_PERCENT);
    reset_ltpltd.cycle = reset_ltpltd.cycle + PARA.NUMB_OF_SET + 1;
    fig = plot(reset_ltpltd.cycle, reset_ltpltd.current, 'bo');
    title('Output Voltage')
    xlabel("number of pulse")
    ylabel("Ampere (I)")
    legend({'SET', 'RESET'},'Location','best')
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

    if ~isfolder('b_LTPLTDVer5')
        mkdir b_LTPLTDVer5
    end
    cd(currentFolder);
    cd('b_LTPLTDVer5');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(caculated_data.voltage, strcat(save_index, '_caculated_data.voltage.txt'));
    writematrix(caculated_data.currnet, strcat(save_index, '_caculated_data.currnet.txt'));
    writematrix(measured_data.Time, strcat(save_index, '_measured_data.Time.txt'));
    writematrix(measured_data.Variables, strcat(save_index, '_measured_data.Variables.txt'));
    writematrix((set_ltpltd.cycle)', strcat(save_index, '_set_ltpltd.cycle.txt'));
    writematrix((set_ltpltd.current)', strcat(save_index, '_set_ltpltd.current.txt'));
    writematrix((reset_ltpltd.cycle)', strcat(save_index, '_reset_ltpltd.cycle.txt'));
    writematrix((reset_ltpltd.current)', strcat(save_index, '_reset_ltpltd.current.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
end

fprintf("b_LTPLTDVer5 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_LTPLTDVer5.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
