function create_ks_rms(sessions, raw_lfp_dir)
for i_session = 1:numel(sessions)
    session_name = sessions(i_session).daq_folder.name(1:6);
    if ~iscell(sessions(i_session).ks_folder)
        save_file    = fullfile(raw_lfp_dir, [session_name, '_hp_RMS.mat']);
        if isfile(save_file)
            fprintf(1, '%s already exists.\n', save_file)
        else
            fprintf(1, 'Start zw_computeRawRMS on %s.\n', session_name);
            [rmsPerChannel, madPerChannel] = zw_computeRawRMS(sessions(i_session).ks_folder, 1);
            save(save_file, 'rmsPerChannel', 'madPerChannel', '-v7.3');
        end
    else
        for i_probe = 1:numel(sessions(i_session).ks_folder)
            save_file    = fullfile(raw_lfp_dir, sprintf('%s_probe_%d%s', session_name, i_probe, '_hp_RMS.mat'));
            if isfile(save_file)
                fprintf(1, '%s already exists.\n', save_file)
            else
                fprintf(1, 'Start zw_computeRawRMS on %s.\n', session_name);
                [rmsPerChannel, madPerChannel] = zw_computeRawRMS(sessions(i_session).ks_folder{i_probe}, 1);
                save(save_file, 'rmsPerChannel', 'madPerChannel', '-v7.3');
            end
        end
    end
end
end