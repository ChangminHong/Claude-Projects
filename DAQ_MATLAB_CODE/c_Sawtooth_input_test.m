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
PARA.SENSITIVITY     = 1e-1;
PARA.RATE            = 2e6;

PARA.NUMB_OF_READ    = 3;          % input to drain (read tri pulse)
PARA.NUMB_OF_SET     = 3;          % input to gate (set pulse)

PARA.SET_HIGH_VOLT   = 2;        % Uint : voltage
PARA.READ_HIGH_VOLT  = 1;

PARA.SET_PULSE_DURATION    = 0.01;     % Uint : millisec
PARA.READ_FREQUENCY        = 100;      % Uint : KHz

PARA.BEFORE_SET_MODE_INTERVAL   = 0.01;     % Uint : millisec
PARA.SET_AFTER_INTERVAL         = 0.01;
PARA.BEFORE_READ_MODE_INTERVAL  = 0.01;

PARA.SET_PULSE_DUTY_CYCLE   = 100;   % Uint : percentage
 
%% ========================================================================
% [2] INPUT
%
% =========================================================================
% --------------------------
% [2-0] check operation parameter
%
% --------------------------
myvoltage_assert(-10, PARA.READ_HIGH_VOLT, PARA.SET_HIGH_VOLT);

mytime_assert(PARA.SET_PULSE_DURATION, 100,     PARA.BEFORE_SET_MODE_INTERVAL, PARA.RATE );
mytime_assert(PARA.SET_PULSE_DURATION, 100,     PARA.SET_AFTER_INTERVAL,  PARA.RATE );
mytime_assert(1/PARA.READ_FREQUENCY + 1,   100, PARA.BEFORE_READ_MODE_INTERVAL,       PARA.RATE );

% --------------------------
% [2-1] Prepare input voltage
%
% --------------------------
myDAQ.Rate            = PARA.RATE;

%make set mode voltage function
[ set_unit_pulse_input, set_high_start, set_high_end, set_duration_end ]...
    = mypulse_gen...
            (PARA.SET_HIGH_VOLT, PARA.SET_PULSE_DURATION,...
              PARA.SET_PULSE_DUTY_CYCLE, PARA.SET_AFTER_INTERVAL, myDAQ.Rate);

%make read mode voltage function
[ read_unit_pulse_input, read_duration_end ]...
    = mysawtooth_pulse_gen...
            (PARA.READ_HIGH_VOLT, PARA.READ_FREQUENCY, myDAQ.Rate );

input_unit_set_mode        = [ mydc_chennal_adder(0, set_unit_pulse_input, 0) ];
input_unit_read_mode       = [ flip(mydc_chennal_adder(0, read_unit_pulse_input, 0), 2) ];
input_set_before_interval  = zeros(PARA.BEFORE_SET_MODE_INTERVAL / 1000 * myDAQ.Rate, 2);
input_read_before_interval = zeros(PARA.BEFORE_READ_MODE_INTERVAL/ 1000 * myDAQ.Rate, 2);

% ------------------------------
% [2-2] Drow Input Voltage Grape
% 
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,2,1)
plot(input_unit_set_mode)
title('Set Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
legend({'GATE', 'DRAIN'},'Location','best')
grid on

subplot(4,2,2)
plot(input_unit_read_mode)
title('Read Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
legend({'GATE', 'DRAIN'},'Location','best')
grid on

%% ========================================================================
% [3] EXECUTION
%
% =========================================================================
% ------------------------------
% [3-1] Reconfirm before execution
%
% -------------------------------
reconfirm = 'output 0 : GATE, output 1 : Drain\nThat Sweep is what you want? ( 1 : YES, else : NO )\n';
excute    = input(reconfirm);

if (excute == 1)
    %integrate input voltage scandata
    input_set_data  = [input_set_before_interval ; repmat(input_unit_set_mode, PARA.NUMB_OF_SET, 1)];
    input_read_data = [input_read_before_interval ; repmat(input_unit_read_mode, PARA.NUMB_OF_READ, 1); input_read_before_interval];
    input_data      = [input_set_data ; input_read_data];
          
    total_excute_time    = tic;

% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    start_excute_time = tic;
    
    % Start Mesurment
    measured_data = readwrite(myDAQ, input_data);
    Variables     = -measured_data.Variables;
    Time          = measured_data.Time;

    % Time Check
    finish_time = toc(start_excute_time);
    fprintf("\n* Finished Measurement *\n");
    fprintf("Measurement Time : %s\n", measured_data.Time(end));
    fprintf("Excute Time          : %.3fsec\n", finish_time);
    
    % ---------------------------------
    % [3-3] Check after Measurement
    %
    % ----------------------------------
    row = size(input_data);
    number_of_input_all_data = row(1);
    if (number_of_input_all_data == myDAQ.NumScansOutputByHardware)
        fprintf("\ninput & scans output by hardware = %d\n", myDAQ.NumScansOutputByHardware)
        fprintf("Generation has terminated with %d scans output by hardware\n", myDAQ.NumScansAcquired);
    else
        warning("your experimental condition is not good ask for program developer")
    end
    
%% ========================================================================
% [4] Drow Output Data      xxx
%                           ---
%                           xxx
% =========================================================================   
% ---------------------------------
% [4-1] Drow Measured Voltage Data
%
% ----------------------------------   
        % Drow Output V-t Grape
        subplot(4,1,2)
        plot(Time, Variables);
        title('TOTAL Output Voltage')
        xlabel("Sec")
        ylabel("Voltage (V)")
        grid on;
% ----------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
        % Caculate Output I, V
        caculated_data.voltage = input_data;
        caculated_data.currnet = Variables * PARA.SENSITIVITY;
        
        % READ Data Extraction
        number_of_input_read_data = size(input_read_data, 1);
        read_data.input_voltage   = caculated_data.voltage(end - (number_of_input_read_data - 1):end);
        read_data.output_current  = caculated_data.currnet(end - (number_of_input_read_data - 1):end);
        read_data.time            = Time(1:number_of_input_read_data);
        
%% ========================================================================
% [5] Drow Data
%
% =========================================================================
        finish_time = toc(start_excute_time);
        fprintf("\nCaculate Time          : %.3fsec\n", finish_time);
        
        % Drow Endurance Graph (read mode input)
        subplot(2,1,2)
        yyaxis right
        plot(read_data.time, read_data.input_voltage, 'r-');
        title('READ Sawtooth PULSE Input & Output')
        xlabel("Time (sec)")
        ylabel("Voltage (V)")
        % Drow Endurance Graph (read mode output)
        yyaxis left
        fig = plot(read_data.time, read_data.output_current, 'k-');
        ylabel("Current (A)")
        legend({'output current', 'input Voltage'},'Location','best')
        grid on
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
    if ~isfolder('c_Sawtooth_input_test')
        mkdir c_Sawtooth_input_test
    end
    cd(currentFolder);
    cd('c_Sawtooth_input_test');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(read_data.input_voltage, strcat(save_index, 'read_data.input_voltage.txt'));
    writematrix(read_data.output_current, strcat(save_index, 'read_data.output_current.txt'));
    writematrix(read_data.time, strcat(save_index, 'read_data.time.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
finish_time = toc(total_excute_time);
fprintf("\nTotal Excute Time        : %.3fsec\n", finish_time);
end

fprintf("c_Sawtooth_input_test END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : c_Sawtooth_input_test.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022