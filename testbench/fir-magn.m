pkg load signal

data = csvread("filtered.txt");
data = data(8:length(data));
spec = abs(fft(data ./ 32768));
len = length(data);
x = 1:len/2;

plot(x ./ len, mag2db(spec(1:len/2)));
