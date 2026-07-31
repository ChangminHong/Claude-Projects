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
PARA.SENSITIVITY     = 1e0;
PARA.RATE            = 1e5;

% P = set, E = reset R = read
PARA.SEQUENCE     = ['R', repmat('P', 1, 3), repmat('R', 1, 3), ...
                     repmat('E', 1, 3), repmat('R', 1, 3)];

PARA.SET_HIGH_VOLT   = 2;        % Uint : voltage
PARA.RESET_HIGH_VOLT = -2;
PARA.READ_HIGH_VOLT  = 1;

PARA.SET_PULSE_DURATION   = 0.01;       % Uint : millisec
PARA.RESET_PULSE_DURATION = 0.01;
PARA.READ_PULSE_DURATION  = 0.01;

PARA.SET_AFTER_INTERVAL   = 0.01;     % Uint : millisec
PARA.RESET_AFTER_INTERVAL = 0.01;     % low
PARA.READ_AFTER_INTERVAL  = 0.01;

PARA.SET_PULSE_DUTY_CYCLE   = 100;    % Uint : percentage
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

%make reset mode voltage function
[ reset_unit_pulse_input, reset_high_start, reset_high_end, reset_duration_end ]...
	= mypulse_gen...
            (PARA.RESET_HIGH_VOLT, PARA.RESET_PULSE_DURATION,...
             PARA.RESET_PULSE_DUTY_CYCLE, PARA.RESET_AFTER_INTERVAL, myDAQ.Rate );

myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );

input_unit_set_mode   = [mydc_chennal_adder(0, set_unit_pulse_input, 0);       flip(mydc_chennal_adder(0, read_unit_pulse_input, 0), 2)];
input_unit_reset_mode = [mydc_chennal_adder(0, reset_unit_pulse_input, 0);     flip(mydc_chennal_adder(0, read_unit_pulse_input, 0), 2)];
input_unit_read_mode  = [mydc_chennal_adder(0, zeros(set_duration_end, 1), 0); flip(mydc_chennal_adder(0, read_unit_pulse_input, 0), 2)];
% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,4,1)
plot(input_unit_set_mode)
title('Set Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
legend({'GATE', 'DRAIN'},'Location','best')
grid on

subplot(4,4,2)
plot(input_unit_reset_mode)
title('Reset Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
legend({'GATE', 'DRAIN'},'Location','best')
grid on

subplot(4,4,3)
plot(input_unit_read_mode)
title('Read Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
legend({'GATE', 'DRAIN'},'Location','best')
grid on

input_data = [];
for sequ_num = 1:1:size(PARA.SEQUENCE, 2)
    if (PARA.SEQUENCE(sequ_num) == 'P')
        input_data = [input_data; input_unit_set_mode];
    elseif (PARA.SEQUENCE(sequ_num) == 'E')
        input_data = [input_data; input_unit_reset_mode];
    elseif (PARA.SEQUENCE(sequ_num) == 'R')
        input_data = [input_data; input_unit_read_mode];
    else
        error("user error : PARA.SEQUENC need input only P E R but, %s", PARA.SEQUENCE(sequ_num));
    end
end
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
% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    % Start Mesurment
    start_excute_time = tic;
    % Mesurment
    measured_data = readwrite(myDAQ, input_data);
    measured_data.Variables = -measured_data.Variables;
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
    % Drow Output V-t Grape
    subplot(4,1,2)
    plot(measured_data.Time, measured_data.Variables);
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
    caculated_data.currnet = measured_data.Variables * PARA.SENSITIVITY;
    caculated_data.currnet = caculated_data.currnet;
    
    % Drow Output I-V Grape
    subplot(4,4,4)
    plot(caculated_data.voltage, caculated_data.currnet, 'ro');
    title('Read Endurance')
    xlabel("Voltage (V)")
    ylabel("Ampere (I)")
    grid on;
    
%% ========================================================================
% [5] Drow Endurance Data
%
% =========================================================================
% ---------------------------------
% [5-1] Endurance Data
%
% ----------------------------------
    output_data.cycle   = 1:1:size(PARA.SEQUENCE, 2);
    output_data.current = zeros(1, size(PARA.SEQUENCE, 2));
    starting_point = 0;
    for cycle = 1:1:size(PARA.SEQUENCE, 2)
        if (PARA.SEQUENCE(cycle) == 'E')
            duration = reset_duration_end;
        else
            duration = set_duration_end;
        end
        
        [output_data_buf.current, output_data_buf.cycle] =...
            myavg_readpulse(...
            caculated_data.currnet,...
            1,...
            starting_point,...
            0,...
            duration + read_high_start,...
            duration + read_high_end,...
            PARA.READ_MEAN_START_PERCENT,...
            PARA.READ_MEAN_END_PERCENT);
        
        subplot(2,1,2)
        output_data.current(cycle) = output_data_buf.current;
        if (PARA.SEQUENCE(cycle) == 'E')
            fig = plot(cycle, output_data_buf.current, 'bo');
            starting_point = starting_point + duration + read_duration_end;
        else
            starting_point = starting_point + duration + read_duration_end;
            if (PARA.SEQUENCE(cycle) == 'P')
                fig = plot(cycle, output_data_buf.current, 'ro');
            else
                fig = plot(cycle, output_data_buf.current, 'k*');
            end
        end
        title('Output Voltage')
        xlabel("number of pulse")
        ylabel("Ampere (I)")
        hold on
    end
        
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
    if ~isfolder('c_LTPLTD_segmentVer1')
        mkdir c_LTPLTD_segmentVer1
    end
    cd(currentFolder);
    cd('c_LTPLTD_segmentVer1');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(caculated_data.voltage,   strcat(save_index, '_caculated_data.voltage.txt'));
    writematrix(caculated_data.currnet,   strcat(save_index, '_caculated_data.currnet.txt'));
    writematrix(measured_data.Time,       strcat(save_index, '_measured_data.Time.txt'));
    writematrix(measured_data.Variables,  strcat(save_index, '_measured_data.Variables.txt'));
    writematrix((output_data.cycle)',     strcat(save_index, '_output_data.cycle.txt'));
    writematrix((output_data.current)',   strcat(save_index, '_output_data.current.txt'));
    saveas(fig,                           strcat(save_index, '_figure.fig'));
    cd(currentFolder);
end

fprintf("c_LTPLTD_segmentVer1 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : c_LTPLTD_segmentVer1.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
