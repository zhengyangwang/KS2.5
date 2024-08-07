function D=load_open_ephys_binary_timestamp_rescue(jsonFile, type, index, varargin)
%function D=load_open_ephys_binary_timestamp_rescue(jsonFile, type, index,
%varargin) 
%Edited from load_open_ephys_binary to correct for missing
%timestamps in the continous data stream observed in OE GUI v0.5.5.3.

%function D=load_open_ephys_binary(oebinFile, type, index)
%
%Loads data recorded by Open Ephys in Binary format
%  oebinFile: The path for the structure.oebin json file
%  type: The type of data to load. Can be 'continuous', 'events' or
%  'spikes'
%  index: The index of the recorded element as appears in the oebin file
%(See also list_open_ephys_binary to extract recorded elements and indexes)
%
%Returns a structure with the header and relevant loaded data
%
%Example:
%D=load_open_ephys_binary('recording_1/structure.oebin','spikes',2)
%
%When loading continuous data, an optional fourth argument 'mmap' can be
%used:
%D=load_open_ephys_binary('recording_1/structure.oebin','continuous',1,'mmap')
%In this case, the Data member from the returned structure contains not an
%array with the data itself but a memory-mapped object of the file, which
%can be used to access its contents. This helps loading big-sized files, as
%it does not require loading the entire file in memory.
%In this case, the data may be accessed using the field D.Data.Data(1).mapped
%For example: D.Data.Data(1).mapped(chan,startSample:endSample)
%
%
%Limitations:
%-TEXT events are not supported by the NPY reading library, so their data
%will not load, but all other fields will.
%-Some metadata structures might not be supported by the NPY reading
%library. In this case the metadata will not be loaded
%In both cases a warning message will be displayed but the program will not
%fail
%
%
%This functions requires the functions readNPY and readNPYHeader 
%from npy-matlab package from kwik-team
%(https://github.com/kwikteam/npy-matlab)
%Requires minimum MATLAB version: R2016b

if (exist('readNPY.m','file') == 0)
    error('OpenEphys:loadBinary:npyLibraryNotfound','readNPY not found. Please be sure that npy-matlab is accessible');
end

if (exist('readNPYheader.m','file') == 0)
    error('OpenEphys:loadBinary:npyLibraryNotfound','readNPYheader not found. Please be sure that npy-matlab is accessible');
end
if (nargin > 3 && strcmp(varargin{1},'mmap'))
    continuousmap = true;
else
    continuousmap = false;
end


json=jsondecode(fileread(jsonFile));
newer_version = '0.6.0';
if at_least_version(newer_version, json.GUIVersion)
    timestamp_filename = 'sample_numbers.npy';
else
    timestamp_filename = 'timestamps.npy';
end

%Load appropriate header data from json
switch type
    case 'continuous'
        header=json.continuous(index);
    case 'spikes'
        header=json.spikes(index);
    case 'events'
        if (iscell(json.events))
            header=json.events{index}; 
        else
            header=json.events(index);
        end
    otherwise
        error('Data type not supported');
end

%Look for folder
f=java.io.File(jsonFile);
if (~f.isAbsolute())
    f=java.io.File(fullfile(pwd,jsonFile));
end
start_timestamp = read_sync_message(dir(fullfile(char(f.getParentFile()), '*sync_message*')));
f=java.io.File(f.getParentFile(),fullfile(type, header.folder_name));
if(~f.exists())
    error('Data folder not found');
end
folder = char(f.getCanonicalPath());
D=struct();
D.Header = header;
switch type
    case 'continuous'
        D.Timestamps = readNPY(fullfile(folder, timestamp_filename));
        contFile=fullfile(folder,'continuous.dat');
        if (continuousmap)
            file=dir(contFile);
            samples=file.bytes/2/header.num_channels;
            D.Data=memmapfile(contFile,'Format',{'int16' [header.num_channels samples] 'mapped'});
        else
            file=fopen(contFile);
            D.Data=fread(file,[header.num_channels Inf],'int16');
            fclose(file);
            samples = size(D.Data, 2);
        end
         if samples ~= numel(D.Timestamps)
             warning('Timestamp corruption in: %s', jsonFile)
             f=java.io.File(jsonFile);
             start_timestamp = read_sync_message(dir(fullfile(char(f.getParentFile()), '*sync_message*')));
             if ~isempty(start_timestamp)
                 D.Timestamps = start_timestamp + int64(0:(samples - 1))';
             elseif (D.Timestamps(end) - D.Timestamps(1) + 1) == int64(samples)
                 D.Timestamps = D.Timestamps(1):D.Timestamps(end);
             else
                 error('No correction found for imestamp corruption in: %s', jsonFile)
             end
        end
    case 'spikes'
        D.Timestamps = readNPY(fullfile(folder,'spike_times.npy'));
        D.Waveforms = readNPY(fullfile(folder,'spike_waveforms.npy'));
        D.ElectrodeIndexes = readNPY(fullfile(folder,'spike_electrode_indices.npy'));
        D.SortedIndexes = readNPY(fullfile(folder,'spike_clusters.npy'));
    case 'events'
        D.Timestamps = readNPY(fullfile(folder, timestamp_filename));
        D.ChannelIndex = readNPY(fullfile(folder, 'channels.npy'));
        f=java.io.File(folder);
        group=char(f.getName());
        if (strncmp(group,'TEXT',4))
            %D.Data = readNPY(fullfile(folder,'text.npy'));
            warning('TEXT files not supported by npy library');
        elseif (strncmp(group,'TTL',3))
            D.Data = readNPY(fullfile(folder,'channel_states.npy'));
            wordfile = fullfile(folder,'full_words.npy');
            if (isfile(wordfile))
                D.FullWords = readNPY(wordfile);
            end
        elseif (strncmp(group,'BINARY',6))
           D.Data = readNPY(fullfile(folder,'data_array.npy'));
        end       
end


metadatafile = fullfile(folder,'metadata.npy');
if (isfile(metadatafile))
    try
    D.MetaData = readNPY(metadatafile);
    catch EX
        fprintf('WARNING: cannot read metadata file.\nData structure might not be supported.\n\nError message: %s\nTrace:\n',EX.message);
        for i=1:length(EX.stack)
            fprintf('File: %s Function: %s Line: %d\n',EX.stack(i).file,EX.stack(i).name,EX.stack(i).line);
        end
    end
end
end