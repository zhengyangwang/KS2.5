function AllData = add_spikes_sparse(AllData, sp, oe, analog_events, task_counter, varargin)
p = inputParser;
p.addParameter('add_rs', false); % Raw ss, relative to raw data index
p.parse(varargin{:});
add_rs = p.Results.add_rs;

%   Decode task type in behavior data
[~, ~, align_event_order_in_queue] = detect_task_type(AllData);
%   CONVERTS DATA MATRIX IDX TO TIMESTAMP!
%   Pads a very short amount of time bins at the end of the timestamps to
%   escape when KS spits spike times beyond the original data since KS
%   pads the raw data during processing.
oe.continuous_timestamp     = [oe.continuous_timestamp; oe.continuous_timestamp(end) + int64(1:100)'];
ss                          = oe.continuous_timestamp(sp.ss);    % "ss" is MATLAB-generated and thus assumed to use 1-indexing
photodiode_time_event       = oe.photodiode_time_event;
adc_helper_time_event       = oe.adc_helper_time_event;
fs_raw                      = sp.sample_rate;
clu                         = ismember_locb(sp.clu, sp.cids);
ss_in_idx                   = logical(clu);
clu                         = clu(ss_in_idx);
ss                          = ss(ss_in_idx);
n_cids                      = numel(sp.cids);
trials                      = AllData.trials;
bound_dur                   = get_task_trial_bound(AllData);
n_inbound_samples           = bound_dur * fs_raw;
trial_time_event_in_session = get_event_in_boundary(oe.session_time_event(task_counter, :), oe.trial_time_event);
analog_time_event           = analog_events.time_sample;

if add_rs
    sp_ss_in = sp.ss(ss_in_idx);
end


n_diff_trial = numel(trials) - size(trial_time_event_in_session, 1);
if n_diff_trial > 0
    corr_r_thresh = 0.99;
    corr_r_offset = zeros(1, n_diff_trial + 1);
    %   Missing trial gate
    for i_shift = 1:(n_diff_trial + 1)
        corr_r_offset(i_shift) = corr(diff([trials([1:(end - n_diff_trial)] + i_shift - 1).time])', double(diff(trial_time_event_in_session(:, 1))));
    end
    candidate_shift = corr_r_offset > corr_r_thresh;
    switch sum(candidate_shift)
        case 0
            error('Trial mismatch by %d in %s task no. %d, with no likely offsets.', n_diff_trial, sp.session_name{1}, task_counter);
        case 1
            to_shift = find(candidate_shift);
            warning('Trial mismatch by %d in %s task no. %d, offsets were found to be %d trials.', n_diff_trial, sp.session_name{1}, task_counter, i_shift);         
            trial_time_event_in_session = [oe.session_time_event(task_counter, 1) + repmat(int64([0, 1]), [to_shift - 1, 1]); trial_time_event_in_session; oe.session_time_event(task_counter, 2) + repmat(int64([-1, 0]), [n_diff_trial - to_shift + 1, 1])];
        otherwise
            error('Trial mismatch by %d in %s task no. %d, with more than 1 likely offsets.', n_diff_trial, sp.session_name{1}, task_counter)         
    end
end
for i = 1:numel(trials)
% parfor i = 1:numel(trials)
    cpu_trial_to_photodiode_latency = trials(i).timestamp_queue(min(align_event_order_in_queue, numel(trials(i).timestamp_queue))) - trials(i).time;
    trial_time_event_in_trial       = trial_time_event_in_session(i, :);
    photodiode_time_event_in_trial  = get_event_in_boundary(trial_time_event_in_trial, photodiode_time_event);
    analog_time_event_in_trial      = get_event_in_boundary(trial_time_event_in_trial, analog_time_event);
    adc_helper_time_event_in_trial  = get_event_in_boundary(trial_time_event_in_trial, adc_helper_time_event);
    if ~isempty(photodiode_time_event_in_trial)
        %   Photodiode on detected
        %   Align ss to photodiode event
        ss_offset                          = photodiode_time_event_in_trial(1, 1) - n_inbound_samples(1) - 1;
        %   Shift Psychtoolbox-generated timestamps by aligning cpu_trial_photodiode_latency w/ real_trial_to_photodiode_latency
        real_trial_to_photodiode_latency   = double(photodiode_time_event_in_trial(1, 1) - trial_time_event_in_trial(1))/fs_raw;
        trials(i).timestamp_queue          = trials(i).timestamp_queue + (real_trial_to_photodiode_latency - cpu_trial_to_photodiode_latency);
        trials(i).photodiode_on_event      = photodiode_time_event_in_trial(1, 1) - ss_offset;
        trials(i).photodiode_off_event     = photodiode_time_event_in_trial(1, 2) - ss_offset;
        if size(photodiode_time_event_in_trial, 1) > 1
            trials(i).add_photodiode_on_event  = photodiode_time_event_in_trial(2:end, 1) - ss_offset;
            trials(i).add_photodiode_off_event = photodiode_time_event_in_trial(2:end, 2) - ss_offset;
        else
            trials(i).add_photodiode_on_event  = int64([]);
            trials(i).add_photodiode_off_event = int64([]);            
        end
    else
        %   Photodiode on not detected
        %   Align ss to estimated photodiode event/last cpu event
        photodiode_time_event_in_trial     = trial_time_event_in_trial(1) + ceil(cpu_trial_to_photodiode_latency * fs_raw);
        ss_offset                          = photodiode_time_event_in_trial(1, 1) - n_inbound_samples(1) - 1;
        trials(i).photodiode_on_event      = int64([]);
        trials(i).photodiode_off_event     = int64([]);
        trials(i).add_photodiode_on_event  = int64([]);
        trials(i).add_photodiode_off_event = int64([]);
    end
    trials(i).trial_on_event        = trial_time_event_in_trial(1) - ss_offset;
    [ss_in_bound, s_idx_in_bound]   = get_event_in_boundary(photodiode_time_event_in_trial(1, 1) + int64(n_inbound_samples .* [-1, 1] + [0, -1]), ss);
    trials(i).ss                    = sparse(ss_in_bound - ss_offset, int64(clu(s_idx_in_bound)), true(size(ss_in_bound)), sum(n_inbound_samples), n_cids);
    if add_rs
        trials(i).rs = sparse(ss_in_bound - ss_offset, int64(clu(s_idx_in_bound)), double(sp_ss_in(s_idx_in_bound)), sum(n_inbound_samples), n_cids);
    end
    if ~isempty(analog_time_event_in_trial)
        trials(i).analog_on_event  = analog_time_event_in_trial(:, 1) - ss_offset;
        trials(i).analog_off_event = analog_time_event_in_trial(:, 2) - ss_offset;
    else
        trials(i).analog_on_event  = int64([]);
        trials(i).analog_off_event = int64([]);
    end
    if ~isempty(adc_helper_time_event_in_trial)
        trials(i).adc_helper_on_event  = adc_helper_time_event_in_trial(:, 1) - ss_offset;
        trials(i).adc_helper_off_event = adc_helper_time_event_in_trial(:, 2) - ss_offset;
    else
        trials(i).adc_helper_on_event  = int64([]);
        trials(i).adc_helper_off_event = int64([]);
    end
end
AllData.trials = trials;
fprintf('Spikes assigned.\n');
end
%%
function [event_in_boundary, event_sample] = get_event_in_boundary(boundary_event, base_event)
% event_idx = and(base_event(:, 1) >= boundary_event(1), base_event(:, end) <= boundary_event(2));
event_idx = and(base_event(:, 1) >= boundary_event(1), base_event(:, 1) <= boundary_event(2));
event_in_boundary = base_event(event_idx, :);
event_sample = find(event_idx);
end