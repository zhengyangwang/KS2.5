clc
clear
fclose all;
%%
zw_setpath;
log_file = 'ks_log.txt';
%%  Find behavior and OE files
% subject_identifier = {'PIC', 'ROS', 'UNI', 'OLI', 'TRI', 'VIK'};
subject_identifier = {'ROS'};
session_range = [188];
beh_dir = 'F:\Database\VanderbiltDAQ\beh'; % Folder for behavior files
daq_dir = 'F:\Database\VanderbiltDAQ\Open Ephys'; % Folder for raw ephys data files
ks_dir  = 'F:\Database\VanderbiltDAQ\KS_out'; % Folder for storing sorted data
raw_lfp_dir = 'F:\Database\VanderbiltDAQ\raw_LFP'; % Folder for storing filtered and downsampled LFP data
sessions = find_oe_beh_files(beh_dir, daq_dir, subject_identifier, session_range);
% check_sorted_session(sessions);
%%  list of ops parameters to test
%   Do not change parameters used for whitening, since whitened data is
%   shared across runs.
start_ops = 1;
remove_duplicate = 1;
ops_list = {};
ops_ = struct;
%   Default
ops_ = struct;
ops_.nblocks = 4;
ops_.remove_duplicate = 1;
ops_list{1} = ops_;
%%  Sorting and creating LFP
log_ks(sessions, log_file, 0);
for i = 1:numel(sessions)
    chanMapFile = find_chanMapFile(sessions(i));
    if iscell(chanMapFile)
        sessions(i).ks_folder = cell(size(chanMapFile));
        for i_chanmap = 1:numel((chanMapFile))
        ks_working_directory = fullfile(ks_dir, sessions(i).subject_identifier);
        rootO = fullfile(ks_working_directory, sprintf('%s_probe_%d', sessions(i).daq_folder.name, i_chanmap));
        sessions(i).ks_folder{i_chanmap} = test_ks_params(sessions(i).daq_files.continuous_file.folder, rootO, chanMapFile{i_chanmap}, ops_list, 'start_ops', start_ops);            
        end
    else
        ks_working_directory = fullfile(ks_dir, sessions(i).subject_identifier);
        rootO = fullfile(ks_working_directory, sessions(i).daq_folder.name);
        sessions(i).ks_folder = test_ks_params(sessions(i).daq_files.continuous_file.folder, rootO, chanMapFile, ops_list, 'start_ops', start_ops);
    end
%     close all
    log_ks(sessions(i), log_file, 1);
end
fclose all
log_ks(sessions, log_file, 2);
% for i = 1:numel(sessions)
%     create_lfp_raw(sessions(i), raw_lfp_dir);
%     log_ks(sessions(i), log_file, 3);
% end
log_ks(sessions, log_file, 4);
%%  Compute RMS from high-pass filtered data
log_ks(sessions, log_file, 5);
create_ks_rms(sessions, raw_lfp_dir);
log_ks(sessions, log_file, 6);
%%  Find ADC events
for i = 1:numel(sessions)
    chanMapFile = find_chanMapFile(sessions(i));
    if ~isempty(regexp(chanMapFile, 'adc|NP', 'once'))
        create_adc_raw(sessions(i), raw_lfp_dir)
    end
end
