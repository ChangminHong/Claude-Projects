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

PARA.SET_HIGH_VOLT   = 2;             % Uint : voltage
PARA.READ_HIGH_VOLT  = 1;

PARA.REPEAT          = 3;

PARA.SET_PULSE_DURATION     = 0.01;    % Uint : millisec
PARA.READ_PULSE_DURATION    = 0.01;

PARA.SET_AFTER_INTERVAL     = 0.01;    % Uint : millisec
PARA.READ_AFTER_INTERVAL    = 0.01;

PARA.MEASURE_INTERVAL       = 0.01;    % Uint : sec

PARA.SET_PULSE_DUTY_CYCLE   = 100;     % Uint : percentage
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
myvoltage_assert(-10, PARA.READ_HIGH_VOLT, PARA.SET_HIGH_VOLT);

mytime_assert(PARA.SET_PULSE_DURATION, PARA.SET_PULSE_DUTY_CYCLE, 100, PARA.RATE );
mytime_assert(PARA.READ_PULSE_DURATION, PARA.READ_PULSE_DUTY_CYCLE, 100, PARA.RATE );

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

myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );
% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
set(gcf, 'Position',  [0, 0, 1920, 1080])
subplot(4,4,1)
plot(set_unit_pulse_input)
title('Set Mode Voltage Unit Function')
xlabel("Scan Data (#)")
ylabel("Voltage (V)")
grid on

subplot(4,4,2)
plot(read_unit_pulse_input)
title('Read Mode Voltage Unit Function')
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
    result_current = zeros(PARA.REPEAT + 1, 1);
    
%% ========================================================================
% [4] OFF STATE READ
%
% =========================================================================
    measured_data = readwrite(myDAQ, read_unit_pulse_input);
    
    % ---------------------------------
    % [4-1] Caculate & Drow Currnet Data
    %
    % ----------------------------------
    % Caculate Output I, V
    caculated_data.voltage = read_unit_pulse_input;
    caculated_data.currnet = measured_data.Variables * -PARA.SENSITIVITY;
    
    % ---------------------------------
    % [4-2] OFF STATE Data
    %
    % ----------------------------------
    % Drow OFF STATE Graph
    subplot(2, 1, 2)
    [read_retetion.current, read_retetion.cycle] =...
        myavg_readpulse(...
        caculated_data.currnet,...
        1,...
        0,...
        0,...
        read_high_start,...
        read_high_end,...
        PARA.READ_MEAN_START_PERCENT,...
        PARA.READ_MEAN_END_PERCENT);
    result_current(1) = read_retetion.current;
    
    fig = plot(0, read_retetion.current, 'ro');
    xlim([0 PARA.REPEAT])
    title('Output Voltage')
    xlabel("number of pulse")
    ylabel("Ampere (I)")
    legend({'OFF STATE'},'Location','best')
    hold on
    
%% ========================================================================
% [5] SET MEMRISTOR
%
% =========================================================================
    % ---------------------------------
    % [5-1] Measure Data
    %
    % ----------------------------------
    % Mesurment
    fprintf("\nset operation start\n");
    measured_data = readwrite(myDAQ, set_unit_pulse_input);
    measured_data.Variables = -measured_data.Variables;
    
    % ---------------------------------
    % [5-2] Drow Measured Voltage Data
    %
    % ----------------------------------
    % Drow Output V-t Grape
    subplot(4,4,3)
    plot(measured_data.Time, measured_data.Variables);
    title('Set Mode Output Voltage')
    xlabel("Sec")
    ylabel("Voltage (V)")
    grid on;
    
    % ---------------------------------
    % [5-3] Caculate & Drow Currnet Data
    %
    % ----------------------------------
    % Caculate Output I, V
    caculated_data.voltage = set_unit_pulse_input;
    caculated_data.currnet = measured_data.Variables * PARA.SENSITIVITY;
    
%% ========================================================================
% [6] RETENTION TEST
%
% =========================================================================
    alternate = 0;
    
    % Start Mesurment
    start_excute_time = tic;
    cycle_timer = tic;
    count = 0;
    
    for index = 1:1:PARA.REPEAT
        while 1
            pause(0.05);
            if (toc(cycle_timer) > PARA.MEASURE_INTERVAL)
                cycle_finish_time = toc(cycle_timer);
                count = count + 1;
                if (count == 1000)
                    fprintf("reset channel");
                    count = 0;
                    removechannel(myDAQ, [1:2]);
                    addinput(myDAQ, "Dev1", 0, "Voltage");
                    addoutput(myDAQ, "Dev1", 0, "Voltage");
                end
                fprintf("ONE CYCLE Time     : %.5f초\n", cycle_finish_time);
                fprintf("========================\n");
                cycle_timer = tic;
                fprintf("\n********************************");
                fprintf("\n* %dth Read Measurement *\n", index);
                fprintf("********************************\n");

                watch_time    = tic;
                measured_data = readwrite(myDAQ, read_unit_pulse_input);
                stop_watch    = toc(watch_time);
                read_time     = stop_watch;
                fprintf("read Time             : %.5f초\n", stop_watch);
                measured_data.Variables = -measured_data.Variables;

            % ---------------------------------
            % [6-1] Drow Measured Voltage Data
            %
            % ----------------------------------
                % Drow Output V-t Grape
                subplot(4,1,2)
                
                if ( alternate == 1 )
                plot(measured_data.Time, measured_data.Variables, 'ro');
                    alternate = 2;
                else
                plot(measured_data.Time, measured_data.Variables, 'bo');
                    alternate = 1;
                end
                title('Read Mode Output Voltage')
                xlabel("Sec")
                ylabel("Voltage (V)")
                grid on;
                buf = stop_watch;
                stop_watch = toc(watch_time);
                fprintf("drow volt Time      : %.5f초\n", stop_watch - buf);

            % ---------------------------------
            % [6-2] Caculate & Drow Currnet Data
            %
            % ----------------------------------
                % Caculate Output I, V
                caculated_data.voltage = read_unit_pulse_input;
                caculated_data.currnet = measured_data.Variables * PARA.SENSITIVITY;
                caculated_data.currnet = caculated_data.currnet;
                buf = stop_watch;
                stop_watch = toc(watch_time);
                fprintf("caculate Time        : %.5f초\n", stop_watch - buf);
                
                % ---------------------------------
                % [6-3] Retention Data
                %
                % ----------------------------------
                % Drow Endurance Graph (RESET_mode)
                subplot(2, 1, 2)
                [read_retetion.current, read_retetion.cycle] =...
                    myavg_readpulse(...
                        caculated_data.currnet,...
                        1,...
                        0,...
                        0,...
                        read_high_start,...
                        read_high_end,...
                        PARA.READ_MEAN_START_PERCENT,...
                        PARA.READ_MEAN_END_PERCENT);
                result_current(index+1) = read_retetion.current;

                fig = plot(index, read_retetion.current, 'bo');
                xlim([0 PARA.REPEAT])
                title('Result Data')
                xlabel("number of pulse")
                ylabel("Ampere (I)")
                legend({'OFF STATE', 'ON STATE'},'Location','best')
                hold on
                
                subplot(4,4,4)
                plot(index, read_time, 'ro');
                xlim([0 PARA.REPEAT])
                title('Read Time')
                xlabel("number of pulse")
                ylabel("sec")
                hold on
                break
            end
        end
        buf = stop_watch;
        stop_watch = toc(watch_time);
        cycle_finish_time = toc(cycle_timer);
        fprintf("Drow 2 Time          : %.5f초\n", stop_watch - buf);
        fprintf("----------------------------\n");
        fprintf("Excute Time          : %.5f초\n", cycle_finish_time);
        fprintf("========================\n");
        fprintf("Measurement Time : %d초\n", PARA.MEASURE_INTERVAL);
    end
    hold off
    
    % Time Check
    finish_time = toc(start_excute_time);
    fprintf("\n****************************");
    fprintf("\n* Finished Measurement *");
    fprintf("\n****************************\n");
    fprintf("Measurement Time : %d초\n", PARA.MEASURE_INTERVAL * index);
    fprintf("Excute Time          : %.5f초\n", finish_time);

%% ========================================================================
% [7] Save Data
%
% =========================================================================
% ---------------------------------
% [7-1] Caculate data number
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

    if ~isfolder('b_RetentionVer3')
        mkdir b_RetentionVer3
    end
    cd(currentFolder);
    cd('b_RetentionVer3');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(result_current, strcat(save_index, 'result_current.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
end
    
fprintf("b_RetentionVer3 END\n");
%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_RetentionVer3.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
