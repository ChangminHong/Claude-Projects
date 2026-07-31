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
hold on

PARA.SENSITIVITY     = 1e-5;
PARA.RATE            = 2*10e5;
PARA.READ_ONLY_ONE   = 0;         % 1 : active

%PARA.NUMB_OF_BINARY  = [0 0 0 0     0 0 0 0     0 0 0 0     0 0 0 1     0 0 1 0     0 0 0 1     0 0 0 0 ; %3
%                        0 0 0 0     0 0 0 0     0 1 0 0     0 0 1 0     0 1 0 0     0 0 1 0     0 0 0 0 ; %4
%                        0 0 0 0     0 0 0 1     1 0 0 1     1 0 0 0     0 0 0 1     0 1 0 0     0 0 0 0 ; %6
%                        0 0 0 0     1 1 1 0     0 0 1 0     0 1 0 0     1 0 0 0     1 0 0 0     0 0 0 0 ];%7
%PARA.NUMB_OF_BINARY  = [ones(1,20), zeros(1,100)];

PARA.NUMB_OF_BINARY  = [1 1 0 1];

number_of_repeat     = 1;          % new
number_of_measure    = 3;          % new (duty cycle + duty_cycle_step)
duty_cycle_step      = 1;          % new
interval             = 1;          % new   (second)

PARA.SET_HIGH_VOLT   = 4.0;        % Uint : voltage
PARA.READ_HIGH_VOLT  = 1.5;

PARA.SET_PULSE_DURATION   = 0.1;       % Uint : millisec
PARA.READ_PULSE_DURATION  = 0.1;

PARA.SET_PULSE_DUTY_CYCLE   = 50 - duty_cycle_step;   % Uint : percentage
PARA.READ_PULSE_DUTY_CYCLE  = 30;

PARA.READ_MEAN_START_PERCENT = 20;
PARA.READ_MEAN_END_PERCENT   = 80;

PARA.ERASE_PULSE_DURATION   = 0.1;
PARA.ERASE_HIGH_VOLT        = 0;
PARA.ERASE_PULSE_DUTY_CYCLE = 100;
% --------------------------
% [1-2] Param Check
%
% --------------------------
myvoltage_assert(PARA.ERASE_HIGH_VOLT, PARA.READ_HIGH_VOLT, PARA.SET_HIGH_VOLT);

mytime_assert(PARA.SET_PULSE_DURATION, PARA.SET_PULSE_DUTY_CYCLE, 100, PARA.RATE );
mytime_assert(PARA.ERASE_PULSE_DURATION, PARA.ERASE_PULSE_DUTY_CYCLE, 100, PARA.RATE );
mytime_assert(PARA.READ_PULSE_DURATION, PARA.READ_PULSE_DUTY_CYCLE, 100, PARA.RATE );


%% ========================================================================
% [2] INPUT
%
% =========================================================================
% --------------------------
% [2-1] Prepare input voltage
%
% --------------------------
myDAQ.Rate            = PARA.RATE;

for measure_number = 1 : 1 : number_of_measure
    %close;
    PARA.SET_PULSE_DUTY_CYCLE = PARA.SET_PULSE_DUTY_CYCLE + duty_cycle_step;
    
    %make read mode voltage function
    [ read_unit_pulse_input, read_high_start, read_high_end, read_duration_end ]...
        = mypulse_gen...
        (PARA.READ_HIGH_VOLT, PARA.READ_PULSE_DURATION,...
        PARA.READ_PULSE_DUTY_CYCLE, 0, myDAQ.Rate );
    
    %make set mode voltage function
    [ set_unit_pulse_input, set_high_start, set_high_end, set_duration_end ]...
        = mypulse_gen...
        (PARA.SET_HIGH_VOLT, PARA.SET_PULSE_DURATION,...
        PARA.SET_PULSE_DUTY_CYCLE, 0, myDAQ.Rate);
    input_unit_set_mode = [ read_unit_pulse_input; set_unit_pulse_input ];
    
    %make zero mode voltage function
    [ zero_unit_pulse_input, zero_high_start, zero_high_end, zero_duration_end ]...
        = mypulse_gen...
        (0, PARA.SET_PULSE_DURATION,...
        50, 0, myDAQ.Rate);
    input_unit_zero_mode = [ read_unit_pulse_input; zero_unit_pulse_input ];
    
    %make reset mode voltage function
    [ reset_unit_pulse_input, reset_high_start, reset_high_end, reset_duration_end ]...
        = mypulse_gen...
        (PARA.ERASE_HIGH_VOLT, PARA.ERASE_PULSE_DURATION,...
        PARA.ERASE_PULSE_DUTY_CYCLE, 0, myDAQ.Rate );
    
    myavg_assert(read_high_start, read_high_end, PARA.READ_MEAN_START_PERCENT, PARA.READ_MEAN_END_PERCENT );

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
    plot(input_unit_zero_mode)
    title('Zore Mode Voltage Unit Function')
    xlabel("Scan Data (#)")
    ylabel("Voltage (V)")
    grid on
    
    subplot(4,4,3)
    plot(reset_unit_pulse_input)
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
    if (measure_number == 1)
        reconfirm = 'That Sweep is what you want? ( 1 : YES, else : NO )\n';
        excute    = input(reconfirm);
    end
    
    if (excute == 1)
        one_cycle_time = tic;
        
        for cycle_index = 1 : 1 : number_of_repeat
            one_cycle_finish_time = toc(one_cycle_time);
            while (one_cycle_finish_time < interval)           % new
                pause(0.5)
                one_cycle_finish_time = toc(one_cycle_time);
            end
            fprintf("\n\ninterval : ");
            fprintf("%d\n\n", one_cycle_finish_time);
            fprintf("measure_number : ");
            fprintf("%d\n", measure_number);
            one_cycle_time = tic;
            
            %integrate input voltage scandata
            row = size(PARA.NUMB_OF_BINARY(number_of_repeat, :));
            binary_length = row(2);
            binary_data = [zeros(myDAQ.Rate/10, 1)];
            
            if (PARA.READ_ONLY_ONE == 0)
                for index = 1:1:binary_length
                    if (PARA.NUMB_OF_BINARY(cycle_index, index) == 1)
                        binary_data = [binary_data; input_unit_set_mode];
                    elseif (PARA.NUMB_OF_BINARY(cycle_index, index) == 0)
                        binary_data = [binary_data; input_unit_zero_mode];
                    else
                        error("USER_ERROR : Bianary is only 0 or 1");
                    end
                end
                
            elseif (PARA.READ_ONLY_ONE == 1)
                for index = 1:1:binary_length
                    if (PARA.NUMB_OF_BINARY(cycle_index, index) == 1)
                        binary_data = [binary_data; set_unit_pulse_input];
                    elseif (PARA.NUMB_OF_BINARY(cycle_index, index) == 0)
                        binary_data = [binary_data; zero_unit_pulse_input];
                    else
                        error("USER_ERROR : Bianary is only 0 or 1");
                    end
                end
                
            else
                error("USER_ERROR : 'PARA.READ_ONLY_ONE' is only 0 or 1");
            end
            
            input_data = [ binary_data; read_unit_pulse_input; reset_unit_pulse_input ];
            
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
            % [5] Drow Retantion Data
            %
            % =========================================================================
            % ---------------------------------
            % [5-1] Set Retantion Data
            %
            % ----------------------------------
            % Drow Retantion Graph (SET_mode)
            subplot(2,1,2)
            
            if (PARA.READ_ONLY_ONE == 0)
                [binary_read.current, binary_read.cycle] =...
                    myavg_readpulse(...
                    caculated_data.currnet,...
                    binary_length + 1,...
                    myDAQ.Rate/10,...    // 0.1sec
                    set_duration_end + read_duration_end,...
                    read_high_start,...
                    read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
                
            elseif (PARA.READ_ONLY_ONE == 1)
                [binary_read.current, binary_read.cycle] =...
                    myavg_readpulse(...
                    caculated_data.currnet,...
                    2,...
                    myDAQ.Rate/10,...    // 0.1sec
                    set_duration_end * binary_length + read_duration_end,...
                    read_high_start,...
                    read_high_end,...
                    PARA.READ_MEAN_START_PERCENT,...
                    PARA.READ_MEAN_END_PERCENT);
            end
            hold on
            switch cycle_index   % new
                case 1 %rgbcmyk
                    subplot(2,1,2)
                    fig = plot(binary_read.cycle, binary_read.current, 'kd--');
                case 2
                    subplot(2,1,2)
                    fig = plot(binary_read.cycle, binary_read.current, 'mo-');
                case 3
                    subplot(2,1,2)
                    fig = plot(binary_read.cycle, binary_read.current, 'bo-');
                case 4
                    subplot(2,1,2)
                    fig = plot(binary_read.cycle, binary_read.current, 'ko-');
            end
            title('Output Voltage')
            xlabel("number of pulse")
            ylabel("Ampere (I)")
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
            
            if ~isfolder('b_binary_for_4bit')
                mkdir b_binary_for_4bit
            end
            cd(currentFolder);
            cd('b_binary_for_4bit');
            save (strcat(save_index, '_', '_PARA.mat'), 'PARA');
            writematrix(caculated_data.voltage, strcat(save_index, '_', '_caculated_data.voltage.txt'));
            writematrix(caculated_data.currnet, strcat(save_index, '_', '_caculated_data.currnet.txt'));
            writematrix(measured_data.Time, strcat(save_index, '_', '_measured_data.Time.txt'));
            writematrix(measured_data.Variables, strcat(save_index, '_', '_measured_data.Variables.txt'));
            writematrix((binary_read.cycle)', strcat(save_index, '_', '_binary.cycle.txt'));
            writematrix((binary_read.current)', strcat(save_index, '_', '_binary.current.txt'));
            saveas(fig, strcat(save_index, '_', '_figure.fig'));
            cd(currentFolder);
            
        end
    end
end
load gong.mat;
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
sound(y);
fprintf("b_binary_for_4bit END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : b_binary_for_4bit.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
