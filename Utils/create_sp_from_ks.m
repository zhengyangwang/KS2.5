function create_sp_from_ks(ks_output_dirs, exp_pattern, sp_output_dir, varargin)
p = inputParser;
p.addParameter('do_assign_session_probe_info', false);
%KS option order when spike sorting was repeated
p.addParameter('session_table', []);
p.addParameter('probe_table', []);
p.parse(varargin{:});
do_assign_session_probe_info = p.Results.do_assign_session_probe_info;
session_table          = p.Results.session_table;
probe_table        = p.Results.probe_table;

for i = 1:numel(ks_output_dirs)
    current_session_name = regexp(ks_output_dirs(i).folder, exp_pattern, 'match');
    if isempty(current_session_name)
        continue
    end
    current_probe_name   = regexp(ks_output_dirs(i).folder, '(probe_)\d', 'match');
    if isempty(current_probe_name)
        current_output_name = [current_session_name{1}, '_sp.mat'];
    else
        current_output_name = [current_session_name{1}, '_', current_probe_name{1}, '_sp.mat'];
    end
    fprintf('Formatting Kilosort files into: %s\n', current_output_name);
    current_output_fullpath = fullfile(sp_output_dir, current_output_name);
    if isfile(current_output_fullpath)
        continue
    end
    current_dir = fullfile(ks_output_dirs(i).folder, ks_output_dirs(i).name);
    sp = loadKSdir(current_dir, setfield(struct, 'excludeNoise', 0));
    sp = load_ks_extra(current_dir, sp);
    sp.session_name = current_session_name;
    if ~isempty(sp.cids)
        sp = zw_merge_clusters(sp);
        if do_assign_session_probe_info
            sp = assign_session_probe_info(sp, session_table, probe_table, 'probe_name', current_probe_name);
        end
    end
    save(current_output_fullpath, "sp");
end
