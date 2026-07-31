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
PARA.SENSITIVITY      = 1e0;
PARA.RATE             = 2e5;

PARA.NUMB_OF_CYCLE          = 5;
PARA.NUMB_OF_SET_PER_CYCLE  = 10;
 
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
 
% adaptive parameter
 PARA.SET_MAX_VOLTAGE    = 2.5;
 PARA.RESET_MIN_VOLTAGE  = -2.5;
 
 PARA.SET_VOLTAGE_STEP   = 0.02;
 PARA.RESET_VOLTAGE_STEP = -0.02;
 
 PARA.MAX_NUM_OF_ADOPTIVE_PULSE = 10;
 PARA.MIN_ON_OFF_RATIO   = 10;
 
 PARA.LRS_HEADROOM_PERCENT   = 10;
 PARA.HRS_HEADROOM_PERCENT   = 10;
 
 PARA.AVERAGE_LRS    = 0;  % do not change
 PARA.AVERAGE_HRS    = 0;  % do not change
 
 PARA.PAUSE    = 0.1;  % do not make 0

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
input_unit_read_off_cycle = [ set_unit_pulse_input ; zeros(read_duration_end, 1) ; 
                              reset_unit_pulse_input ; zeros(read_duration_end, 1) ];
                          
size1 = size(input_unit_read_on_cycle);
size2 = size(input_unit_read_off_cycle);  
if (size1(1) ~= size2(1))
    warning("size of 'input_unit_read_on_cycle' does not same 'input_unit_read_off_cycle'")
end

myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );

% ------------------------------
% [2-2] Drow Input Voltage Grape
% 
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,4,1)
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

    set_result.current           = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    set_result.cycle             = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    set_result.adapt             = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    set_result.adapted_current   = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.current         = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.cycle           = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.adapt           = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    reset_result.adapted_current = zeros(PARA.NUMB_OF_CYCLE + PARA.NUMB_OF_SET_PER_CYCLE - 1, 1);
    
    total_excute_time = tic;
% ---------------------------------
% [3-2] Measure Data
%
% ----------------------------------
    for index = 1:1:PARA.NUMB_OF_CYCLE
        start_excute_time = tic;
        
        if (index == 1)
            % Start Mesurment
            measured_data = readwrite(myDAQ, first_input_data);
            Variables = -measured_data.Variables;
            Time      = measured_data.Time;
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
        if (index == 1)
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
        if (index == 1)
            caculated_data.voltage = first_input_data;
        else
            caculated_data.voltage = input_unit_read_on_cycle;
        end
        caculated_data.currnet = Variables * PARA.SENSITIVITY;
        
%% ========================================================================
% [5] Drow Endurance Data (first cycle measure)
%
% =========================================================================
        if (index == 1)
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
                1,...
                read_high_start,...
                read_high_end,...
                PARA.READ_MEAN_START_PERCENT,...
                PARA.READ_MEAN_END_PERCENT);
            
            semilogx(1, initial.current, 'mo');
            title('Output Voltage')
            xlabel("number of pulse")
            ylabel("Ampere (I)")
            xlim([0 PARA.NUMB_OF_CYCLE * PARA.NUMB_OF_SET_PER_CYCLE])
            legend({'INIT'},'Location','best')
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
            legend({'INIT', 'SET'},'Location','best')
    
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
            
        % ---------------------------------
        % [5-3] Adaptive Data Extract
        %
        % ----------------------------------
            PARA.AVERAGE_LRS = mean(set_endurance.current,'all');
            PARA.AVERAGE_HRS = mean(reset_endurance.current,'all');
            
            if (PARA.AVERAGE_LRS/PARA.AVERAGE_HRS < PARA.MIN_ON_OFF_RATIO)
                error('USER ERROR : check PARA.ON_OFF_RATIO or operation, \nmeasured on / off ratio : %f', PARA.AVERAGE_LRS/PARA.AVERAGE_HRS);
            end
            if ((PARA.AVERAGE_HRS < 0) || (PARA.AVERAGE_LRS < 0))
                error('USER ERROR : current is negative');
            end

        else
            % ---------------------------------
            % [5-4] Set Endurance Data
            %
            % ----------------------------------
            % Drow Endurance Graph (SET_mode)
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
            
            subplot(2,1,2)
            semilogx(PARA.NUMB_OF_SET_PER_CYCLE * index, set_endurance.current, 'ro');
            legend({'INIT', 'SET', 'RESET'},'Location','best')
            
            % ---------------------------------
            % [5-5] Reset Endurance Data
            %
            % ----------------------------------
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
            
%% ========================================================================
% [6] ISPP
%
%
% =========================================================================
            % ---------------------------------
            % [6-1] ISPP SET setting 
            %
            % ----------------------------------
            % inital value (need to adapt)
            subplot(4,4,2)
            plot(0, PARA.AVERAGE_LRS, 'mo')
            title('SET Adopted')
            xlabel("number of pulse")
            ylabel("Current (A)")
            grid on
            hold on
            
            % ---------------------------------
            % [6-2] SET ISPP
            %
            % ----------------------------------
            set_adapted_count = 0;
            SET_HIGH_VOLT = PARA.SET_HIGH_VOLT;
            while (set_endurance.current < PARA.AVERAGE_LRS * (1 - PARA.LRS_HEADROOM_PERCENT/100) )
                % print ISPP operation ON
                set_adapted_count = set_adapted_count + 1;
                fprintf('\nISPP operation : SET MODE ERROR (%d)', set_adapted_count)
                
                % check set voltage and update input data
                if (SET_HIGH_VOLT < PARA.SET_MAX_VOLTAGE)
                    SET_HIGH_VOLT = SET_HIGH_VOLT + PARA.SET_VOLTAGE_STEP;
                    [ adapted_unit_set ]...
                        = mypulse_gen...
                        (SET_HIGH_VOLT, PARA.SET_PULSE_DURATION,...
                        PARA.SET_PULSE_DUTY_CYCLE, PARA.SET_AFTER_INTERVAL, myDAQ.Rate);
                end
                
                % measurement
                pause(PARA.PAUSE)
                ISPP_input            = [adapted_unit_set ; read_unit_pulse_input];
                ISPP_measured_data    = readwrite(myDAQ, ISPP_input);
                
                % Drow Output V-t Grape
                subplot(4,1,2)
                plot(ISPP_measured_data.Time, ISPP_measured_data.Variables);
                title('Output Voltage')
                xlabel("Sec")
                ylabel("Voltage (V)")
                grid on
                
                % Caculate ISPP result
                ISPP_caculated_data = -ISPP_measured_data.Variables * PARA.SENSITIVITY;
                [ISPP_Variables.current, ISPP_Variables.cycle] =...
                    myavg_readpulse(...
                    ISPP_caculated_data,...
                    1,...
                    set_duration_end,...
                    0,...
                    read_high_start,...
                    read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
                
                % save data
                set_endurance.current = ISPP_Variables.current;
                set_result.adapted_current(PARA.NUMB_OF_SET_PER_CYCLE + index - 1) = set_endurance.current;
                set_result.adapt(PARA.NUMB_OF_SET_PER_CYCLE + index - 1)           = set_adapted_count;
                
                subplot(2,1,2)
                semilogx(PARA.NUMB_OF_SET_PER_CYCLE * index, set_endurance.current, 'Marker','o','MarkerFaceColor','red', 'Color', 'r');
                legend({'INIT', 'SET', 'RESET'},'Location','best')
                
                % Drow ISPP result
                subplot(4,4,2)
                plot(set_adapted_count, set_endurance.current, 'ro')
                legend({'AVERAGE LRS', 'ISPP RESULT'},'Location','best')
                
                % Check stucked
                if (set_adapted_count >= PARA.MAX_NUM_OF_ADOPTIVE_PULSE)
                    fprintf('\n');
                    error('USER ERROR : SET stucked');
                end
            end
            hold off
            
            % ---------------------------------
            % [6-3] ISPP RESET setting 
            %
            % ----------------------------------
            % inital value (need to adapt)
            subplot(4,4,3)
            plot(0, PARA.AVERAGE_HRS, 'mo')
            title('RESET Adopted')
            xlabel("number of pulse")
            ylabel("Current (A)")
            grid on
            hold on
            
            % ---------------------------------
            % [6-4] RESET ISPP
            %
            % ----------------------------------
            reset_adapted_count = 0;
            RESET_HIGH_VOLT = PARA.RESET_HIGH_VOLT;
            while (reset_endurance.current > PARA.AVERAGE_HRS * (1 + PARA.HRS_HEADROOM_PERCENT/100) )
                % print ISPP operation ON
                reset_adapted_count = reset_adapted_count - 1;
                fprintf('\nISPP operation : RESET MODE ERROR (%d)', reset_adapted_count)
                
                % check set voltage and update input data
                if (RESET_HIGH_VOLT > PARA.RESET_MIN_VOLTAGE)
                    RESET_HIGH_VOLT = RESET_HIGH_VOLT + PARA.RESET_VOLTAGE_STEP;
                    [ adapted_unit_reset ]...
                        = mypulse_gen...
                        (RESET_HIGH_VOLT, PARA.RESET_PULSE_DURATION,...
                        PARA.RESET_PULSE_DUTY_CYCLE, PARA.RESET_AFTER_INTERVAL, myDAQ.Rate);
                end
                
                % measurement
                pause(PARA.PAUSE)
                ISPP_input            = [adapted_unit_reset ; read_unit_pulse_input];
                ISPP_measured_data    = readwrite(myDAQ, ISPP_input);
                
                % Drow Output V-t Grape
                subplot(4,1,2)
                plot(ISPP_measured_data.Time, ISPP_measured_data.Variables);
                title('Output Voltage')
                xlabel("Sec")
                ylabel("Voltage (V)")
                grid on
                
                % Caculate ISPP result
                ISPP_caculated_data = -ISPP_measured_data.Variables * PARA.SENSITIVITY;
                [ISPP_Variables.current, ISPP_Variables.cycle] =...
                    myavg_readpulse(...
                    ISPP_caculated_data,...
                    1,...
                    reset_duration_end,...
                    0,...
                    read_high_start,...
                    read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
                
                % save data
                reset_endurance.current = ISPP_Variables.current;
                reset_result.adapted_current(PARA.NUMB_OF_SET_PER_CYCLE + index - 1) = reset_endurance.current;
                reset_result.adapt(PARA.NUMB_OF_SET_PER_CYCLE + index - 1)           = reset_adapted_count;
                
                subplot(2,1,2)
                semilogx(PARA.NUMB_OF_SET_PER_CYCLE * index, reset_endurance.current, ...
                         'Marker','o','MarkerFaceColor','b', 'Color', 'b');
                legend({'INIT', 'SET', 'RESET'},'Location','best')
                     
                % Drow ISPP result
                subplot(4,4,3)
                plot(reset_adapted_count, reset_endurance.current, 'bo')
                legend({'AVERAGE HRS', 'ISPP RESULT'},'Location','best')
                
                % Check stucked
                if (reset_adapted_count <= -PARA.MAX_NUM_OF_ADOPTIVE_PULSE)
                    fprintf('\n');
                    error('USER ERROR : RESET stucked');
                end
            end
            
            hold off
            
        end
        
        finish_time = toc(start_excute_time);
        fprintf("\nCaculate Time          : %.3fsec\n", finish_time);
        
        subplot(4,4,4)
        plot(index, finish_time, 'ro');
        xlim([0 PARA.NUMB_OF_CYCLE])
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
    if ~isfolder('b_Endu_adoptiveVer2')
        mkdir b_Endu_adoptiveVer2
    end
    cd(currentFolder);
    cd('b_Endu_adoptiveVer2');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(reset_result.current,         strcat(save_index, 'reset_result.current.txt'));
    writematrix(reset_result.cycle,           strcat(save_index, 'reset_result.cycle.txt'));
    writematrix(reset_result.adapt,           strcat(save_index, 'reset_result.adapt.txt'));
    writematrix(reset_result.adapted_current, strcat(save_index, 'reset_result.adapted_current.txt'));
    writematrix(set_result.current,           strcat(save_index, 'set_result.current.txt'));
    writematrix(set_result.cycle,             strcat(save_index, 'set_result.cycle.txt'));
    writematrix(set_result.adapt,             strcat(save_index, 'set_result.adapt.txt'));
    writematrix(set_result.adapted_current,   strcat(save_index, 'set_result.adapted_current.txt'));
    writematrix(initial.current,              strcat(save_index, 'initial.current.txt'));
    writematrix(initial.cycle,                strcat(save_index, 'initial.cycle.txt'));
    saveas(fig,                               strcat(save_index, '_figure.fig'));
    cd(currentFolder);

end
finish_time = toc(total_excute_time);
fprintf("\nTotal Excute Time        : %.3fsec\n", finish_time);

fprintf("b_Endu_adoptiveVer2 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_Endu_adoptiveVer2.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
