pkg load signal

%% filter length
flen = 511;

%% window
#win = ones(flen,1);
#win = chebwin(flen);
#win = blackmanharris(flen);
win = flattopwin(flen);

%% data width
bits = 16;

%% sampling frequency
fs = 20000

%% cutoff frequency
fc = 50;

%% stopband frequency
fb = 100;

%% amplification (dB)
amp_db = 10;

%% stopband attenuation (dB)
stop_db = -40;

%% filter
amp_k = 10^(amp_db/20);
stop_k = 10^((stop_db+amp_k)/20);
f = [0 fc/fs fb/fs 1];
m = [amp_k amp_k stop_k stop_k];
fcoeff = firls(flen-1, f, m) .* win;

%% scale and round to 16 bit
fcoeff_i16 = round(fcoeff .* 65536);

%% remove leading and trailing zeroes
fcoeff_i16_ms = fcoeff_i16(find(fcoeff_i16,1,'first'):find(fcoeff_i16,1,'last'));

function ret = to_hex(x)
  if (x < 0)
    ret = 65536+x;
  else
    ret = x;
  endif
endfunction

%% convert negative coeffs to 16-bit two's complement
fcoeff_i16_hex = arrayfun(@to_hex, fcoeff_i16_ms);

%% printf coeffs to file
filename = sprintf("fir_%d_%dhz_%dhz_%ddb_%ddb.rom", length(fcoeff_i16_ms), fc, fb, amp_db, -stop_db);
printf("Write %d coefficients to file %s\n", length(fcoeff_i16_ms), filename);

file = fopen(filename, "w");
fprintf(file, "%04x\n", fcoeff_i16_hex);
fclose(file);

%% make real coeffs for freqz
fcoeff_i = fcoeff_i16_ms ./ 65536;
freqz(fcoeff_i);
