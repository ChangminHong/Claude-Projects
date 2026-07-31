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
PARA.SENSITIVITY      = 1e-0;
PARA.RATE             = 2e6;

PARA.NUMB_OF_CYCLE          = 2;
PARA.NUMB_OF_SET_PER_CYCLE  = 2;

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

PARA.READ_MEAN_START_PERCENT = 50;
PARA.READ_MEAN_END_PERCENT   = 100;

PARA.READ_VOLT_ON_WHEN_READ = 1;

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

input_unit_read_on_cycle  = [ set_unit_pulse_input ; read_unit_pulse_input ;
                              reset_unit_pulse_input ; read_unit_pulse_input ];
                          
if (PARA.READ_VOLT_ON_WHEN_READ == 0)
    input_unit_read_off_cycle = [ set_unit_pulse_input ; zeros(read_duration_end, 1) ; 
                                  reset_unit_pulse_input ; zeros(read_duration_end, 1) ];
else
    input_unit_read_off_cycle = [ set_unit_pulse_input ; read_unit_pulse_input ; 
                                  reset_unit_pulse_input ; read_unit_pulse_input ];
end


% --------------------------
% [2-2] check operation parameter 2
%
% --------------------------
size1 = size(input_unit_read_on_cycle, 1);
size2 = size(input_unit_read_off_cycle, 1);  

if (size1 ~= size2)
    warning("size of 'input_unit_read_on_cycle' does not same 'input_unit_read_off_cycle'")
end

myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );

% ------------------------------
% [2-3] Drow Input Voltage Grape
% 
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,2,1)
plot(input_unit_read_on_cycle)
title('A CYCLE Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
hold on
plot(input_unit_read_off_cycle)
legend({'READ ON', 'READ OFF'},'Location','best')
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
    first_input_data     = [read_unit_pulse_input ; repmat(input_unit_read_on_cycle, PARA.NUMB_OF_SET_PER_CYCLE, 1)];
    input_data           = [repmat(input_unit_read_off_cycle, (PARA.NUMB_OF_SET_PER_CYCLE - 1), 1);
                            input_unit_read_on_cycle ];
    flag = 0;
    set_result.current   = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    set_result.cycle     = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.current = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.cycle   = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    total_excute_time = tic;
% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    for index = 1:1:PARA.NUMB_OF_CYCLE
        start_excute_time = tic;
        
        if (~flag)
            % Start Mesurment
            measured_data = readwrite(myDAQ, first_input_data);
            Variables     = -measured_data.Variables;
            Time          = measured_data.Time;
            % Mesurment
        else
            measured_data = readwrite(myDAQ, input_data);
            Variables = -measured_data{size2(1)*(PARA.NUMB_OF_SET_PER_CYCLE-1) + 1:end,:};
            Time      = measured_data.Time(1:size2(1));
        end
        % Time Check
        finish_time = toc(start_excute_time);
        fprintf("\n* Finished Measurement *\n");
        fprintf("Measurement Time : %s\n", measured_data.Time(end));
        fprintf("Excute Time          : %.3fsec\n", finish_time);

% ---------------------------------
% [3-3] Check after Measurement
%
% ----------------------------------
        % Check # of ScansOutput data
        if (~flag)
            row = size(first_input_data);
        else
            row = size(input_data);
        end
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
        title('Output Voltage')
        xlabel("Sec")
        ylabel("Voltage (V)")
        grid on;
% ---------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
        % Caculate Output I, V
        if (~flag)
            caculated_data.voltage = first_input_data;
        else
            caculated_data.voltage = input_unit_read_on_cycle;
        end
        caculated_data.currnet = Variables * PARA.SENSITIVITY;
        
        % Drow Output I-V Grape
        subplot(4,4,3)
        plot(caculated_data.voltage, caculated_data.currnet, 'ro');
        title('Read Endurance')
        xlabel("Voltage (V)")
        ylabel("Ampere (I)")
        grid on;
        
%% ========================================================================
% [5] Drow Endurance Data
%
% =========================================================================
            
        if (~flag)
            % ---------------------------------
            % [5-1] Set Endurance Data
            %
            % ----------------------------------
            % Drow Endurance Graph (INIT)
            subplot(2,1,2)
            [initial.current, initial.cycle] =...
                myavg_readpulse(...
                caculated_data.currnet,...
                1,...
                0,...
                0,...
                read_high_start,...
                read_high_end,...
                PARA.READ_MEAN_START_PERCENT,...
                PARA.READ_MEAN_END_PERCENT);
            
            semilogx(1, initial.current, 'mo');
            title('Output Voltage')
            xlabel("number of pulse")
            ylabel("Ampere (I)")
            xlim([0 PARA.NUMB_OF_CYCLE * PARA.NUMB_OF_SET_PER_CYCLE])
            hold on
            
            % Drow Endurance Graph (SET_mode)
            [set_endurance.current, set_endurance.cycle] =...
                myavg_readpulse(...
                    caculated_data.currnet,...
                    PARA.NUMB_OF_SET_PER_CYCLE,...
                    read_duration_end,...
                    set_duration_end + read_duration_end*2 + reset_duration_end,...
                    set_duration_end + read_high_start,...
                    set_duration_end + read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
            set_result.current(1:PARA.NUMB_OF_SET_PER_CYCLE) = set_endurance.current;
            set_result.cycle(1:PARA.NUMB_OF_SET_PER_CYCLE)   = set_endurance.cycle;
            semilogx(set_endurance.cycle, set_endurance.current, 'ro');
    
        % ---------------------------------
        % [5-2] Reset Endurance Data
        %
        % ----------------------------------
            % Drow Endurance Graph (RESET_mode)
            [reset_endurance.current, reset_endurance.cycle] =...
                myavg_readpulse(...
                    caculated_data.currnet,...
                    PARA.NUMB_OF_SET_PER_CYCLE,...
                    set_duration_end + read_duration_end * 2,...
                    set_duration_end + read_duration_end * 2 + reset_duration_end,...
                    reset_duration_end + read_high_start,...
                    reset_duration_end + read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
            reset_result.current(1:PARA.NUMB_OF_SET_PER_CYCLE) = reset_endurance.current;
            reset_result.cycle(1:PARA.NUMB_OF_SET_PER_CYCLE)   = reset_endurance.cycle;
            semilogx(reset_endurance.cycle, reset_endurance.current, 'bo');
            legend({'INIT', 'SET', 'RESET'},'Location','best')
            flag = 1;
        else
            
            % Drow Endurance Graph (SET_mode)
            subplot(2,1,2)
            [set_endurance.current, set_endurance.cycle] =...
                myavg_readpulse(...
                    caculated_data.currnet,...
                    1,...
                    0,...
                    0,...
                    set_duration_end + read_high_start,...
                    set_duration_end + read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
            set_result.current(PARA.NUMB_OF_SET_PER_CYCLE + index - 1) = set_endurance.current;
            set_result.cycle(PARA.NUMB_OF_SET_PER_CYCLE + index - 1)   = PARA.NUMB_OF_SET_PER_CYCLE * index;
            semilogx(PARA.NUMB_OF_SET_PER_CYCLE * index, set_endurance.current, 'ro');
            legend({'INIT', 'SET', 'RESET'},'Location','best')
            
            % Drow Endurance Graph (RESET_mode)
            [reset_endurance.current, reset_endurance.cycle] =...
                myavg_readpulse(...
                    caculated_data.currnet,...
                    1,...
                    set_duration_end + read_duration_end,...
                    0,...
                    reset_duration_end + read_high_start,...
                    reset_duration_end + read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
            reset_result.current(PARA.NUMB_OF_SET_PER_CYCLE + index - 1) = reset_endurance.current;
            reset_result.cycle(PARA.NUMB_OF_SET_PER_CYCLE + index - 1)   = PARA.NUMB_OF_SET_PER_CYCLE * index;
            fig = semilogx(PARA.NUMB_OF_SET_PER_CYCLE * index, reset_endurance.current, 'bo');
            legend({'INIT', 'SET', 'RESET'},'Location','best')
        end
        
        finish_time = toc(start_excute_time);
        fprintf("\nCaculate Time          : %.3fsec\n", finish_time);
        
        subplot(4,4,4)
        plot(index, finish_time, 'ro');
        xlim([0 PARA.NUMB_OF_SET_PER_CYCLE])
        title('Read Time')
        xlabel("number of pulse")
        ylabel("sec")
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
    if ~isfolder('b_EnduranceVer6')
        mkdir b_EnduranceVer6
    end
    cd(currentFolder);
    cd('b_EnduranceVer6');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(reset_result.current, strcat(save_index, 'reset_result.current.txt'));
    writematrix(reset_result.cycle, strcat(save_index, 'reset_result.cycle.txt'));
    writematrix(set_result.current, strcat(save_index, 'set_result.current.txt'));
    writematrix(set_result.cycle, strcat(save_index, 'set_result.cycle.txt'));
    writematrix(initial.current, strcat(save_index, 'initial.current.txt'));
    writematrix(initial.cycle, strcat(save_index, 'initial.cycle.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
end
finish_time = toc(total_excute_time);
fprintf("\nTotal Excute Time        : %.3fsec\n", finish_time);
fprintf("b_EnduranceVer6 END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_EnduranceVer6_0.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
