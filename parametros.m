    %% ---------- Muestreo ----------
sampling_time = 2e-6;
sampling_frec = 1/sampling_time;      % 500 kHz
Fn = sampling_frec/2;
epsilon = 1e-8;

%% ---------- Estaciones (FDM, fijas) ----------
fc1 = 100.0e3;   % central
fc2 =  98.0e3;   % inferior
fc3 = 102.0e3;   % superior

W    = 150;                  % ancho del mensaje por canal (Hz)
beta = 3;
df   = beta*W;               % 450 Hz
Bfm  = 2*(df + W);           % Carson por estación: 1.2 kHz

%% ---------- Receptor (lo cambia la GUI) ----------
if ~exist('f_rx','var'), f_rx = fc1; end
fc   = f_rx;
fi   = 17e3;
flo  = fc + fi;              % LO automático

%% ---------- Filtro RF (FIJO, centrado en el FDM) ----------
[z,p,k] = cheby1(4, 0.1, [fc1-4.5e3, fc1+4.5e3]/Fn, 'bandpass');
sos_rf  = zp2sos(z,p,k);

%% ---------- Tasa del receptor (sin diezmado) ----------
M      = 1;
Ts_d   = M*sampling_time;
Fs_d   = 1/Ts_d;             % 500 kHz
Fn_d   = Fs_d/2;

%% ---------- Filtro FI (selector de canal) ----------
% Deseada: fi ± 0.6 kHz (Carson/2). Vecina: empieza en fi ± 1.4 kHz.
Ap = 0.1;  As = 60;
Wp = [fi-0.7e3, fi+0.7e3]/Fn_d;      % paso con 0.1 kHz de margen
Ws = [fi-1.3e3, fi+1.3e3]/Fn_d;      % rechazo antes de la vecina
[n, Wn] = ellipord(Wp, Ws, Ap, As);
[z,p,k] = ellip(n, Ap, As, Wn, 'bandpass');
sos_fi  = zp2sos(z,p,k);
fprintf('Orden del prototipo FI: %d | max|polo| = %.8f\n', n, max(abs(p)));

%% ---------- Verificación rápida ----------
[h,f] = freqz(sos_rf, 16384, sampling_frec);
for fx = [fc2 fc1 fc3 fc+2*fi]
    [~,i] = min(abs(f-fx));
    fprintf('RF a %.0f kHz: %.1f dB\n', fx/1e3, 20*log10(abs(h(i))));
end
[h,f] = freqz(sos_fi, 16384, Fs_d);
for o = [0 0.6e3 0.7e3 1.3e3 1.4e3 2e3]
    [~,i] = min(abs(f-(fi+o)));
    fprintf('FI offset %.2f kHz: %.1f dB\n', o/1e3, 20*log10(abs(h(i))));
end



%% ---------- Receptor: bloques nuevos ----------

[z,p,k] = butter(4, 30e3/Fn_d, 'low');  sos_lp1 = zp2sos(z,p,k);       % tras el mezclador
[z,p,k] = butter(2, [12e3 22e3]/Fn_d, 'bandpass'); sos_lim = zp2sos(z,p,k);  % tras el limitador
[z,p,k] = butter(4, 400/Fn_d, 'low');   sos_aud = zp2sos(z,p,k);       % audio
Kdem = 1/(5.1*df)*1.2;           % ganancia aprox.; ajústarla viendo el scope
[z,p,k] = butter(1, 10/Fn_d, 'high');  sos_dc = zp2sos(z,p,k);


%% ---------- Seleccionar referencia (para comparar al final) ----------
est      = [fc1 fc2 fc3];
[dmin, select] = min(abs(est - f_rx));
tol_sint = 100;
sintonizado = dmin <= tol_sint;


%% ---------- Ruido AWGN ----------
if ~exist('SNR_dB','var'), SNR_dB = Inf; end     % Inf = sin ruido

Ps = 0.5;                  % potencia de UNA estación (portadora de amplitud 1)
B  = Bfm;                  % ancho en el que se define la SNR (1.2 kHz)
if isinf(SNR_dB)
    sigma2 = 0;
else
    % densidad espectral plana en [0, Fs/2]: potencia en B = sigma2*B/(Fs/2)
    sigma2 = (Ps/10^(SNR_dB/10)) * (Fn/B);
end
seed_ruido = 1234;         % semilla fija