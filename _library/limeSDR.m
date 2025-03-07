% Copyright (c) 2019 DamirRakhimov
% Copyright (c) 2017 JiangWei
% Copyright (c) 2015 Nuand LLC
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.
%
% LimeSDR MATLAB interface
%
% (1) Open a device handle:
%
%   dev = limeSDR(); % Open device
%
% (2) Setup device parameters. These may be changed while the device
%     is actively streaming.
%
%   dev.rx0.frequency  = 917.45e6;
%   dev.rx0.samplerate = 5e6;
%   dev.rx0.gain = 30;
%   dev.rx0.antenna = 2;
%
% (3) Enable stream parameters. These may NOT be changed while the device
%     is streaming.
%
%   dev.rx0.enable;
%
% (4) Start the module
%
%   dev.start();
%
% (5) Receive 5000 samples on RX0 channel
%
%  samples = dev.receive(5000,0);
%
% (6) Cleanup and shutdown by stopping the RX stream and having MATLAB
%     delete the handle object.
%
%  dev.stop();
%  clear dev;

%% Top-level limesdr object
classdef limeSDR < handle
    
    properties (Access={?limeSDR_XCVR})
        device  % Device handle
        rx0_stream % rx stream handle
        tx0_stream % tx stream handle
        rx1_stream % rx stream handle
        tx1_stream % tx stream handle
    end
    
    properties
        rx0          % Receive chain
        tx0          % Transmit chain
        rx1          % Receive chain
        tx1          % Transmit chain
        chiptemp
    end
    
    properties (Access = private)
        running
    end
    
    properties(SetAccess=immutable)
        info        % Information about device properties and state
        versions    % Device and library version information
    end
    
    methods(Static, Hidden)
        function check_status(status)
            if status ~= 0
                err_str = calllib('libLimeSuite', 'LMS_GetLastErrorMessage');
                error([ 'LimeSDR error: ' err_str]);
            end
        end
    end
    
    methods(Static)
        %==================================================================
        function build_thunk
            % Build the MATLAB thunk library for use with the LimeSDR MATLAB wrapper
            %
            % limeSDR.build_thunk();
            %
            % This function is intended to provide developers with the means to
            % regenerate the libLimeSuite_thunk_<arch>.<library extension> files.
            % Users of pre-built binaries need not concern themselves with this
            % function.
            %
            % Use of this function requires that:
            %   - The system contains a MATLAB-compatible compiler
            %   - Any required libraries, DLLs, headers, etc. are in the search path or current working directory.
            %
            % For Windows users, the simplest approach is to copy the following
            % to this directory:
            %   - LimeSuite.dll
            
            if libisloaded('libLimeSuite') == true
                unloadlibrary('libLimeSuite');
            end
            
            arch = computer('arch');
            proto_output = 'delete_this_file';
            switch arch
                case 'win64'
                    [notfound, warnings] = loadlibrary('LimeSuite',          'LimeSuite.h', 'addheader', 'LMS7002M_parameters.h','includepath', pwd, 'notempdir', 'mfilename', 'libLimeSuite__proto', 'alias', 'libLimeSuite');
                case 'glnxa64'
                    [notfound, warnings] = loadlibrary('libLimeSuite',       'LimeSuite.h', 'addheader', 'LMS7002M_parameters.h','includepath', pwd, 'notempdir', 'mfilename', 'libLimeSuite__proto');
                case 'maci64'
                    [notfound, warnings] = loadlibrary('libLimeSuite.dylib', 'LimeSuite.h', 'addheader', 'LMS7002M_parameters.h','includepath', pwd, 'notempdir', 'mfilename', 'libLimeSuite__proto');
                otherwise
                    error(strcat('Unsupported architecture: ', arch))
            end
            
%             if isempty(notfound) == false
%                 fprintf('\nMissing functions:\n');
%                 disp(notfound.');
%                 error('Failed to find the above functions in libLimeSuite.');
%             end
%             
%             if isempty(warnings) == false
%                 warning('Encountered the following warnings while loading libLimeSuite:\n%s\n', warnings);
%             end
        end
        
        %==================================================================
        function [major, minor, patch] = version()
            major = 0;
            minor = 0;
            patch = 1;
        end
        
        %==================================================================
        function [version_string] = library_version()
            limeSDR.load_library();
            version_string=char(calllib('libLimeSuite', 'LMS_GetLibraryVersion'));
        end
        
        %==================================================================
        function devs = devices
            limeSDR.load_library();
            pdevlist = libpointer('int8Ptr');
            
            [count, ~] = calllib('libLimeSuite', 'LMS_GetDeviceList', pdevlist);
            if count < 0
                error(calllib('libLimeSuite', 'LMS_GetLastErrorMessage'));
            end
            
            if count > 0
                devs = repmat(struct('deviceName', [], 'expansionName', [], 'firmwareVersion', [], 'hardwareVersion', [], 'protocolVersion', [], 'boardSerialNumber', [], 'gatewareVersion', [], 'gatewareRevision', [], 'gatewareTargetBoard', []), 1, count);
                for x = 0:(count-1)
                    dptr = libpointer('voidPtrPtr');
                    calllib('libLimeSuite', 'LMS_Open', dptr,pdevlist+x,0);
                    dinfo=libstruct('lms_dev_info_t',calllib('libLimeSuite', 'LMS_GetDeviceInfo', dptr));
                    devs(x+1).deviceName            = char(dinfo.deviceName);
                    devs(x+1).expansionName         = char(dinfo.expansionName);
                    devs(x+1).firmwareVersion       = char(dinfo.firmwareVersion);
                    devs(x+1).hardwareVersion       = char(dinfo.hardwareVersion);
                    devs(x+1).protocolVersion       = char(dinfo.protocolVersion);
                    devs(x+1).boardSerialNumber     = char(dinfo.boardSerialNumber);
                    devs(x+1).gatewareVersion       = char(dinfo.gatewareVersion);
                    devs(x+1).gatewareTargetBoard   = char(dinfo.gatewareTargetBoard);
                    calllib('libLimeSuite', 'LMS_Close', dptr);
                end
            else
                devs = [];
            end
        end
    end
    
    methods(Static, Access = private)
        %==================================================================
        function load_library
            if libisloaded('libLimeSuite') == false
                arch = computer('arch');
                switch arch
                    case 'win64'
                        [notfound, warnings] = loadlibrary('LimeSuite', @libLimeSuite__proto, 'alias', 'libLimeSuite');
                    case 'glnxa64'
                        [notfound, warnings] = loadlibrary('libLimeSuite', @libLimeSuite__proto);
                    case 'maci64'
                        [notfound, warnings] = loadlibrary('libLimeSuite.dylib', @libLimeSuite__proto);
                    otherwise
                        error(strcat('Unsupported architecture: ', arch))
                end
                
                if isempty(notfound) == false
                    error('Failed to find functions in libLimeSuite.');
                end
                
                if isempty(warnings) == false
                    warning('Encountered the following warnings while loading libLimeSuite:\n%s\n', warnings);
                end
            end
            
        end
    end
    
    methods
        %==================================================================
        function obj = limeSDR(serial)
            
            if nargin < 1
                serial = '';
            end
            
            limeSDR.load_library();
            %TODO serial select device
            pdevlist = libpointer('int8Ptr');
            
            [count, ~] = calllib('libLimeSuite', 'LMS_GetDeviceList', pdevlist);
            if count < 0
                error(calllib('libLimeSuite', 'LMS_GetLastErrorMessage'));
            end
            
            dptr = libpointer('voidPtrPtr');
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_Open', dptr,pdevlist,0));
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_Init', dptr));
            obj.device = dptr;
            
            dinfo = libstruct('lms_dev_info_t',calllib('libLimeSuite', 'LMS_GetDeviceInfo', obj.device));
            obj.info.deviceName          = char(dinfo.deviceName);
            obj.info.expansionName       = char(dinfo.expansionName);
            obj.info.firmwareVersion     = char(dinfo.firmwareVersion);
            obj.info.hardwareVersion     = char(dinfo.hardwareVersion);
            obj.info.protocolVersion     = char(dinfo.protocolVersion);
            obj.info.boardSerialNumber   = char(dinfo.boardSerialNumber);
            obj.info.gatewareVersion     = char(dinfo.gatewareVersion);
            obj.info.gatewareTargetBoard = char(dinfo.gatewareTargetBoard);
            
            obj.versions.library_version = char(calllib('libLimeSuite', 'LMS_GetLibraryVersion'));
            
            obj.rx0 = limeSDR_XCVR(obj, 'RX',0);
            obj.rx1 = limeSDR_XCVR(obj, 'RX',1);
            obj.tx0 = limeSDR_XCVR(obj, 'TX',0);
            obj.tx1 = limeSDR_XCVR(obj, 'TX',1);
            obj.running= false;
            
        end
        
        %==================================================================
        function delete(obj)
            
            %disp('Delete limeSDR called');
            if isempty(obj.device) == false
                calllib('libLimeSuite', 'LMS_Close', obj.device);
            end
            
        end
        
        %==================================================================
        function [samples, timestamp_out, actual_count] = receive(obj, num_samples, chan,timeout_ms, timestamp_in)
            
            if nargin < 3
                chan = 0;
            end
            
            if nargin < 4
                timeout_ms = 1000;
            end
            
            if nargin < 5
                timestamp_in = 0;
            end
            
            if ~obj.running
                error('please start device');
            end
            
            f32     = single(zeros(2*num_samples, 1));
            
            metad   = libstruct('lms_stream_meta_t');
            
            if timestamp_in == 0
                metad.waitForTimestamp=false;
            else
                metad.waitForTimestamp=true;
            end
            metad.timestamp=timestamp_in;
            if chan==0
                rx_stream=obj.rx0_stream;
                if isempty(rx_stream)
                    error('rx0 stream not enabled');
                end
            else
                rx_stream=obj.rx1_stream;
                
                if isempty(rx_stream)
                    error('rx1 stream not enabled');
                end
            end
            
            [actual_count, ~, f32, ~]=calllib('libLimeSuite', 'LMS_RecvStream', rx_stream,f32,num_samples,metad,timeout_ms);
            samples=(double(f32(1:2:end)) + double(f32(2:2:end))*1j);
            timestamp_out = metad.timestamp;
        end
        
        %==================================================================
        function transmit(obj, samples,chan, timeout_ms, timestamp_in)
            if nargin < 3
                chan = 0;
            end
            
            if nargin < 4
                timeout_ms = 1000;
            end
            
            if nargin < 5
                timestamp_in = 0;
            end
            
            if ~obj.running
                error('please start device');
            end
            
            metad = libstruct('lms_stream_meta_t');
            
            if timestamp_in == 0
                metad.waitForTimestamp=false;
            else
                metad.waitForTimestamp=true;
            end
            metad.timestamp=timestamp_in;
            
            
            if chan==0
                tx_stream=obj.tx0_stream;
                if isempty(tx_stream)
                    error('tx0 stream not enabled');
                end
            else
                tx_stream=obj.tx1_stream;
                if isempty(tx_stream)
                    error('tx1 stream not enabled');
                end
            end
            
            f32 = zeros(2 * length(samples), 1, 'single');
            f32(1:2:end) = real(samples);
            f32(2:2:end) = imag(samples);
            
            calllib('libLimeSuite', 'LMS_SendStream', tx_stream,f32,length(samples),metad,timeout_ms);
        end
        
        %==================================================================
        function start(obj)
            % if isempty(obj.rx0_stream)==false
            %     limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.rx0_stream));
            % end
            %
            % if isempty(obj.rx1_stream)==false
            %     limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.rx1_stream));
            % end
            %
            % if isempty(obj.tx0_stream)==false
            %     limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.tx0_stream));
            % end
            %
            % if isempty(obj.tx1_stream)==false
            %     limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.tx1_stream));
            % end
            if obj.rx0.running
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.rx0_stream));
            end
            if obj.rx1.running
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.rx1_stream));
            end
            
            if obj.tx0.running
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.tx0_stream));
            end
            
            if obj.tx1.running
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_StartStream', obj.tx1_stream));
            end
            
            obj.running=true;
        end
        
        %==================================================================
        function stop(obj)
            
            if obj.rx0.running
                obj.rx0.disable();
            end
            if obj.rx1.running
                obj.rx1.disable();
            end
            
            if obj.tx0.running
                obj.tx0.disable();
            end
            
            if obj.tx1.running
                obj.tx1.disable();
            end
            
            if isempty(obj.rx0_stream)==false
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_DestroyStream',obj.device, obj.rx0_stream));
                obj.rx0_stream=[];
            end
            
            if isempty(obj.rx1_stream)==false
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_DestroyStream',obj.device, obj.rx1_stream));
                obj.rx1_stream=[];
            end
            
            if isempty(obj.tx0_stream)==false
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_DestroyStream',obj.device, obj.tx0_stream));
                obj.tx0_stream=[];
            end
            
            if isempty(obj.tx1_stream)==false
                limeSDR.check_status(calllib('libLimeSuite', 'LMS_DestroyStream',obj.device, obj.tx1_stream));
                obj.tx1_stream=[];
            end
            
        end
        
        %==================================================================
        function loadconfig(obj,filename)
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_LoadConfig', obj.device, filename));
        end
        
        %==================================================================
        function val = get.chiptemp(obj)
            chiptemp_val = libpointer('doublePtr', 0);
            limeSDR.check_status(calllib('libLimeSuite', 'LMS_GetChipTemperature', obj.device, 0, chiptemp_val));
            val = chiptemp_val.value;
        end
        
        %==================================================================
        function status = stream_status(obj, dir, chan)
            
            if nargin < 2
                error('Direction is not specified');
            end
            
            if nargin < 3
                chan = 0;
            end
            
            if strcmpi(dir,'RX') == false && strcmpi(dir, 'TX') == false
                error('Invalid direction specified');
            end
            
            if(strcmpi(dir,'RX') == false)
                if chan==0
                    stream = obj.tx0_stream;
                else
                    stream = obj.tx1_stream;
                end
            else
                if chan==0
                    stream = obj.rx0_stream;
                else
                    stream = obj.rx1_stream;
                end
            end
            
            if isempty(stream)
                error('stream is not enabled');
            end
            status_struct   = struct('active', false, 'fifoFilledCount', uint32(0), 'fifoSize', uint32(0), 'underrun', uint32(0), 'overrun', uint32(0), 'droppedPackets', uint32(0), 'sampleRate', 0, 'linkRate', 0, 'timestamp', uint64(0));
            % create empty structure, without this line Matlab crashes
            status          = libstruct('lms_stream_status_t', status_struct); % create pointer
            
            [~] = calllib('libLimeSuite', 'LMS_GetStreamStatus', stream, status);
            
        end
    end
    
end