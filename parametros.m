sampling_time = 2e-6;
sampling_frec = 1/sampling_time;

fc  = 100e3;            % despues hay que hacer que se pueda cambiar en la GUI
fi  = 17e3;
flo = fc + fi;

W    = 1.2e3;
beta = 4;
df   = beta*W;          % 4.8 kHz
Bfm  = 2*(df + W);      % Carson ≈ 12 kHz

Fn = sampling_frec/2;
% Filtro RF (depende de fc)
[z,p,k] = cheby1(5, 0.1, [fc-8e3 fc+8e3]/Fn, 'bandpass');
sos_rf  = zp2sos(z,p,k);

% Filtro FI (fijo)
[z,p,k] = cheby1(5, 0.1, [fi-8e3 fi+8e3]/Fn, 'bandpass');
sos_fi  = zp2sos(z,p,k);
