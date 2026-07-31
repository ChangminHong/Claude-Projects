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

PARA.NUMB_OF_CYCLE             = 2;
PARA.NUMB_OF_LTPLTD_PER_CYCLE  = 2;

PARA.NUMB_OF_SET               = 10;
PARA.NUMB_OF_RESET             = 10;

PARA.SET1_HIGH_VOLT   = 1;        % Uint : voltage
PARA.SET2_HIGH_VOLT   = 2;        % Uint : voltage
PARA.RESET_HIGH_VOLT  = -2;
PARA.READ_HIGH_VOLT   = 1;

 PARA.SET1_PULSE_DURATION   = 0.01;       % Uint : millisec
 PARA.SET2_PULSE_DURATION   = 0.01;       % Uint : millisec
 PARA.RESET_PULSE_DURATION  = 0.01;
 PARA.READ_PULSE_DURATION   = 0.01;

PARA.SET1_AFTER_INTERVAL   = 0;     % Uint : millisec
PARA.SET2_AFTER_INTERVAL   = 0.01;     % Uint : millisec
PARA.RESET_AFTER_INTERVAL  = 0.01;     % low
PARA.READ_AFTER_INTERVAL   = 0.01;

PARA.SET1_PULSE_DUTY_CYCLE   = 100;   % Uint : percentage
PARA.SET2_PULSE_DUTY_CYCLE   = 100;   % Uint : percentage
PARA.RESET_PULSE_DUTY_CYCLE  = 100;
PARA.READ_PULSE_DUTY_CYCLE   = 100;

PARA.READ_MEAN_START_PERCENT = 0;
PARA.READ_MEAN_END_PERCENT   = 100;

PARA.MUX_ON          = 3.3;       % Uint : voltage

PARA.MUX_SET_PULSE_ON    = 1;
PARA.MUX_READ_PULSE_ON   = 1;
PARA.MUX_RESET_PULSE_ON  = 0;
%% ========================================================================
% [2] INPUT
%
% =========================================================================
% --------------------------
% [2-0] check operation parameter
%
% --------------------------
myvoltage_assert(PARA.RESET_HIGH_VOLT, PARA.READ_HIGH_VOLT, PARA.SET2_HIGH_VOLT);

mytime_assert(PARA.SET1_PULSE_DURATION, PARA.SET1_PULSE_DUTY_CYCLE, PARA.SET1_AFTER_INTERVAL, PARA.RATE );
mytime_assert(PARA.SET2_PULSE_DURATION, PARA.SET2_PULSE_DUTY_CYCLE, PARA.SET2_AFTER_INTERVAL, PARA.RATE );
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

%make set2 mode voltage function
[ set1_unit_pulse_input, set1_high_start, set1_high_end, set1_duration_end ]...
    = mypulse_gen...
            (PARA.SET1_HIGH_VOLT, PARA.SET1_PULSE_DURATION,...
              PARA.SET1_PULSE_DUTY_CYCLE, PARA.SET1_AFTER_INTERVAL, myDAQ.Rate, 1);
          
%make set1 mode voltage function
[ set2_unit_pulse_input, set2_high_start, set2_high_end, set2_duration_end ]...
    = mypulse_gen...
            (PARA.SET2_HIGH_VOLT, PARA.SET2_PULSE_DURATION,...
              PARA.SET2_PULSE_DUTY_CYCLE, PARA.SET2_AFTER_INTERVAL, myDAQ.Rate);

set_unit_pulse_input = [set1_unit_pulse_input; set2_unit_pulse_input];
set_high_start       = set1_high_start;
set_high_end         = set1_duration_end + set2_high_end;
set_duration_end     = set1_duration_end + set2_duration_end;

%make reset mode voltage function
[ reset_unit_pulse_input, reset_high_start, reset_high_end, reset_duration_end ]...
	= mypulse_gen...
            (PARA.RESET_HIGH_VOLT, PARA.RESET_PULSE_DURATION,...
             PARA.RESET_PULSE_DUTY_CYCLE, PARA.RESET_AFTER_INTERVAL, myDAQ.Rate );

myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );

set_unit_pulse_input  = mydc_chennal_adder(PARA.MUX_ON, set_unit_pulse_input, PARA.MUX_SET_PULSE_ON);
read_unit_pulse_input = mydc_chennal_adder(PARA.MUX_ON, read_unit_pulse_input, PARA.MUX_READ_PULSE_ON);
reset_unit_pulse_input = mydc_chennal_adder(PARA.MUX_ON, reset_unit_pulse_input, PARA.MUX_RESET_PULSE_ON);

input_unit_set_mode    = [ set_unit_pulse_input ; read_unit_pulse_input];
input_unit_reset_mode  = [ reset_unit_pulse_input ; read_unit_pulse_input ];
                   
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
grid on

subplot(4,4,2)
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
    unit_ltp_ltd_input_data = [read_unit_pulse_input ; repmat(input_unit_set_mode, PARA.NUMB_OF_SET, 1) ; repmat(input_unit_reset_mode, PARA.NUMB_OF_RESET, 1)];
    input_data              = repmat(unit_ltp_ltd_input_data, PARA.NUMB_OF_LTPLTD_PER_CYCLE, 1);
    
    unit_ltp_ltd_size    = size(unit_ltp_ltd_input_data);
    
    set_result.current   = zeros((PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * (PARA.NUMB_OF_LTPLTD_PER_CYCLE + PARA.NUMB_OF_CYCLE - 1), 1);
    set_result.cycle     = zeros((PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * (PARA.NUMB_OF_LTPLTD_PER_CYCLE + PARA.NUMB_OF_CYCLE - 1), 1);
    reset_result.current = zeros((PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * (PARA.NUMB_OF_LTPLTD_PER_CYCLE + PARA.NUMB_OF_CYCLE - 1), 1);
    reset_result.cycle   = zeros((PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * (PARA.NUMB_OF_LTPLTD_PER_CYCLE + PARA.NUMB_OF_CYCLE - 1), 1);
    total_excute_time    = tic;
% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    for cycle_number = 1:1:PARA.NUMB_OF_CYCLE
        start_excute_time = tic;
        
        if (cycle_number == 1)
            % Start Mesurment
            measured_data = readwrite(myDAQ, input_data);
            Variables     = -measured_data.Variables;
            Time          = measured_data.Time;
        else
            measured_data = readwrite(myDAQ, input_data);
            Variables     = -measured_data{unit_ltp_ltd_size(1)*(PARA.NUMB_OF_LTPLTD_PER_CYCLE-1) + 1:end,:};
            Time          = measured_data.Time(1:unit_ltp_ltd_size(1));
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
        if (cycle_number == 1)
            row = size(input_data);
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
        subplot(4,1,3)
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
        if (cycle_number == 1)
            caculated_data.voltage = input_data;
        else
            caculated_data.voltage = input_data;
        end
        caculated_data.currnet = Variables * PARA.SENSITIVITY;

%% ========================================================================
% [5] Drow Endurance Data
%
% =========================================================================
            
        if (cycle_number == 1)
            for ltpltd_number = 1:1:PARA.NUMB_OF_LTPLTD_PER_CYCLE
                % ---------------------------------
                % [5-1] Set Endurance Data
                %
                % ----------------------------------
                % caculate Endurance data (SET_mode)
                [set_endurance.current, set_endurance.cycle] =...
                    myavg_readpulse(...
                    caculated_data.currnet,...
                    PARA.NUMB_OF_SET + 1,...
                    unit_ltp_ltd_size(1) * (ltpltd_number - 1),...
                    set_duration_end + read_duration_end,...
                    read_high_start,... 
                    read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
                
                set_endurance.cycle = set_endurance.cycle +...
                                      ((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ));
                set_result.current((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + 1 ...
                                  : ltpltd_number * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) - PARA.NUMB_OF_RESET)...
                                  = set_endurance.current;
                set_result.cycle((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + 1 ...
                                : ltpltd_number * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) - PARA.NUMB_OF_RESET) ...
                                = set_endurance.cycle;

                % Drow Endurance Graph (SET_mode)
                subplot(4,1,2)
                plot(set_endurance.cycle, set_endurance.current, 'ro');
                title('First Cycle Output')
                xlabel("number of pulse")
                ylabel("Ampere (I)")
                xlim([0 (PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * PARA.NUMB_OF_LTPLTD_PER_CYCLE ])
                hold on

                % Drow Endurance Graph (Total Data - SET)
                subplot(4,1,4)                            
                semilogx(set_endurance.cycle, set_endurance.current, 'ro');
                title('Total Output Data - Log scale')
                xlabel("number of pulse")
                ylabel("Ampere (I)")
                xlim([0 (PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1) * PARA.NUMB_OF_LTPLTD_PER_CYCLE * PARA.NUMB_OF_CYCLE])
                hold on
                
                % ---------------------------------
                % [5-2] Reset Endurance Data
                %
                % ----------------------------------
                % caculate Endurance data (RESET_mode)
                reset_mode_start_point = size(input_unit_set_mode) * PARA.NUMB_OF_SET;
                [reset_endurance.current, reset_endurance.cycle] =...
                    myavg_readpulse(...
                    caculated_data.currnet,...
                    PARA.NUMB_OF_RESET,...
                    reset_mode_start_point(1) + read_duration_end + unit_ltp_ltd_size * (ltpltd_number - 1),...
                    reset_duration_end + read_duration_end,...
                    reset_duration_end + read_high_start,...
                    reset_duration_end + read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
                
                reset_endurance.cycle = reset_endurance.cycle +...
                                      ((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1));
                reset_result.current((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1) + 1 ...
                                  : ltpltd_number * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ))...
                                  = reset_endurance.current;
                reset_result.cycle((ltpltd_number - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1) + 1 ...
                                : ltpltd_number * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 )) ...
                                = reset_endurance.cycle;

                % Drow Endurance Graph (RESET_mode)
                subplot(4,1,2) 
                plot(reset_endurance.cycle, reset_endurance.current, 'bo');
                legend({'SET', 'RESET'},'Location','best')
                
                % Drow Endurance Graph (Total Data - RESET)
                subplot(4,1,4)
                fig = semilogx(reset_endurance.cycle, reset_endurance.current, 'bo');
                legend({'SET', 'RESET'},'Location','best')
                hold on
            end
        else
            % Caculation Endurance Graph (SET_mode)
            [set_endurance.current, set_endurance.cycle] =...
                myavg_readpulse(...
                caculated_data.currnet,...
                PARA.NUMB_OF_SET + 1,...
                0,...
                set_duration_end + read_duration_end,...
                read_high_start,...
                read_high_end,...
                PARA.READ_MEAN_START_PERCENT,...
                PARA.READ_MEAN_END_PERCENT);
            
            % Caculation Endurance Graph (RESET_mode)
            [reset_endurance.current, reset_endurance.cycle] =...
                myavg_readpulse(...
                caculated_data.currnet,...
                PARA.NUMB_OF_RESET,...
                reset_mode_start_point(1) + read_duration_end,...
                reset_duration_end + read_duration_end,...
                reset_duration_end + read_high_start,...
                reset_duration_end + read_high_end,...
                PARA.READ_MEAN_START_PERCENT,...
                PARA.READ_MEAN_END_PERCENT);
            
            % Drow Endurance Graph (SET_mode, RESET_mode)
            subplot(4,4,3)
            plot(set_endurance.cycle, set_endurance.current, 'ro');
            hold on
            plot(reset_endurance.cycle + PARA.NUMB_OF_SET + 1, reset_endurance.current, 'bo');
            hold off
            title('A Cycle Output')
            xlabel("number of pulse")
            ylabel("Ampere (I)")
            grid on;
            
            % Drow Endurance Graph (Total Data - SET)
            set_endurance.cycle = set_endurance.cycle +...
                ((cycle_number * PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ));
            
            set_result.current((cycle_number - 1 + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + 1 ...
                : (cycle_number + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) - PARA.NUMB_OF_RESET)...
                = set_endurance.current;
                        
            set_result.cycle((cycle_number - 1 + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + 1 ...
                : (cycle_number + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) - PARA.NUMB_OF_RESET)...
                = set_endurance.cycle;
            
            subplot(4,1,4)
            semilogx(set_endurance.cycle, set_endurance.current, 'ro');
            hold on
            
            % Drow Endurance Graph (Total Data - RESET)
            reset_endurance.cycle = reset_endurance.cycle +...
                ((cycle_number * PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1));
            reset_result.current((cycle_number - 1 + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1) + 1 ...
                : (cycle_number + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ))...
                = reset_endurance.current;
            reset_result.cycle((cycle_number - 1 + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ) + (PARA.NUMB_OF_SET + 1) + 1 ...
                : (cycle_number + PARA.NUMB_OF_LTPLTD_PER_CYCLE - 1) * ( PARA.NUMB_OF_SET + PARA.NUMB_OF_RESET + 1 ))...
                = reset_endurance.cycle;
            fig = semilogx(reset_endurance.cycle, reset_endurance.current, 'bo');
            legend({'SET', 'RESET'},'Location','best')
            
        end
        
        finish_time = toc(start_excute_time);
        fprintf("\nCaculate Time          : %.3fsec\n", finish_time);
        
        subplot(4,4,4)
        plot(cycle_number, finish_time, 'ro');
        xlim([0 PARA.NUMB_OF_CYCLE])
        title('Read Time')
        xlabel("number of cycle")
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
    if ~isfolder('b_LTPLTD_Endu_stairs_set_MUXVer2')
        mkdir b_LTPLTD_Endu_stairs_set_MUXVer2
    end
    cd(currentFolder);
    cd('b_LTPLTD_Endu_stairs_set_MUXVer2');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(reset_result.current, strcat(save_index, 'reset_result.current.txt'));
    writematrix(reset_result.cycle, strcat(save_index, 'reset_result.cycle.txt'));
    writematrix(set_result.current, strcat(save_index, 'set_result.current.txt'));
    writematrix(set_result.cycle, strcat(save_index, 'set_result.cycle.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
finish_time = toc(total_excute_time);
fprintf("\nTotal Excute Time        : %.3fsec\n", finish_time);

end

fprintf("b_LTPLTD_Endu_stairs_set_MUXVer2 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_LTPLTD_Endu_stairs_set_MUXVer2.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
