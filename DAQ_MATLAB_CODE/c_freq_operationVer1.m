%% ========================================================================
% [1] Parameter
%
% =========================================================================
% --------------------------
% [1-1] Setting Param
%
% --------------------------
%        -----  <-(PULSE_VOLTAGE)
%       |     | 
%       |     |                     
%  ------     ----------------------
%  <----------------><------------->
%       P_DURATION       P_INTERVAL
% =========================================================================
PARA.SENSITIVITY      = 1e-0;
PARA.RATE             = 2e5;

PARA.NUMB_OF_PULSE    = [10, 20, 30, 40, 10, 20, 30, 40];

PARA.PULSE_VOLT          = 1;                                  % Uint : voltage
PARA.DRAIN_VOLT          = 2;                                  % Uint : voltage
PARA.PULSE_DURATION      = [0.01, 0.01, 0.01, 0.01, 0.005, 0.005, 0.005, 0.005];     % Uint : millisec
PARA.AFTER_INTERVAL      = [0.01, 0.01, 0.01, 0.01, 0.005, 0.005, 0.005, 0.005];     % Uint : millisec
PARA.OPERATION_INTERVAL  = 1;                                  % Uint : millisec
PARA.START_BUFFER        = 1;                                  % Uint : millisec
PARA.PULSE_DUTY_CYCLE    = 100;

myDAQ.Rate = PARA.RATE;

%% ========================================================================
% [2] INPUT
%
% =========================================================================
% --------------------------
% [2-1] Check Parameter
%
% --------------------------
myfreq_assert(PARA);

% --------------------------
% [2-2] Prepare input voltage
%
% --------------------------
% start buffer (period : 1ms)
input_data = [zeros(myDAQ.Rate/ 1000 * PARA.START_BUFFER, 1)];   

% integrate scandata (input voltage)
for index = 1:1:size(PARA.NUMB_OF_PULSE, 2)
    % check operation parameter
    mytime_assert(PARA.PULSE_DURATION(index), PARA.PULSE_DUTY_CYCLE, PARA.AFTER_INTERVAL(index), myDAQ.Rate );
    
    % generate unit pulse
    unit_pulse = mypulse_gen(PARA.PULSE_VOLT, PARA.PULSE_DURATION(index),...
        PARA.PULSE_DUTY_CYCLE, PARA.AFTER_INTERVAL(index), myDAQ.Rate );
    
    % integrate a frequency set
    input_data = [input_data ; repmat(unit_pulse, PARA.NUMB_OF_PULSE(index), 1)];
    
    % make interval between frequency set
    input_data = [input_data ; zeros(myDAQ.Rate/1000 * PARA.OPERATION_INTERVAL, 1)];
    
    % make window for figure
    set(gcf, 'Position',  [0, 0, 1920, 1080])
    
    % Drow graph (Unit Pulse)
    subplot(4, 2, rem(index - 1, 4) + 1)
    plot(unit_pulse)
    title("Unit Pulse #" + string(rem(index - 1, 4) + 1))
    xlabel("Scan Data (#)")
    ylabel("Voltage (V)")
    legend('Location','best')
    hold on

end

input_data = [input_data, ones(size(input_data, 1), 1) .* PARA.DRAIN_VOLT];

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
% [4] Drow Data
%
% =========================================================================
% ------------------------------
% [2-2] Drow Input Voltage Grape
%
% -------------------------------
    subplot(2,1,2)
    plot(measured_data.Time, input_data, 'b-')
    yyaxis left
    title('Input & Output')
    xlabel("Time (sec)")
    ylabel("Voltage (V)")
    hold on
% ---------------------------------
% [4-2] Caculate & Drow Currnet Data
%
% ----------------------------------
    % Caculate Output I, V
    measured_data.Variables = measured_data.Variables * -PARA.SENSITIVITY;
    % Drow Output I-V Grape
    subplot(2,1,2)
    yyaxis right
    fig = plot(measured_data.Time, measured_data.Variables, 'r-');
    title('Input & Output')
    xlabel("Time (sec)")
    ylabel("Current (A)")
    legend({'input', 'output'},'Location','best')
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

    if ~isfolder('c_freq_operationVer1')
        mkdir c_freq_operationVer1
    end
    cd(currentFolder);
    cd('c_freq_operationVer1');
    save (strcat(save_index, '_PARA.mat'), 'PARA');
    writematrix(measured_data.Time,     strcat(save_index, '_measured_data.Time.txt'));
    writematrix(measured_data.Dev1_ai0, strcat(save_index, '_measured_data.currnet.txt'));
    writematrix(input_data,             strcat(save_index, 'input_data.txt'));
    saveas(fig, strcat(save_index, '_figure.fig'));
    cd(currentFolder);
    
end
fprintf("c_freq_operationVer1 END\n");

%   Copyright (c) 2022 by ENTIS, All rights reserved.
% 
%   File name  : c_freq_operationVer1.m
%   Written by : Jeong, Hakcheon
%                M.S.&PH.D. integ
%                School of Electrical Engineering, KAIST
%   Written on : April 31, 2022
