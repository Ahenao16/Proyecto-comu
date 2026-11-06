%% ---------- Muestreo ----------
sampling_time = 2e-6;
sampling_frec = 1/sampling_time;      % 500 kHz
Fn = sampling_frec/2;

%% ---------- Mensajes, AM y FDM ----------
W     = 150;                  % ancho de cada mensaje (Hz)
mu    = 0.5;                  % índice de modulación AM
fsc   = [0 400 800];          % canal 1 en banda base (portadora 0 Hz)
% Bandas: 0-150 | 250-550 | 650-950 Hz -> FDM real 950 Hz
B_fdm = 1.2e3;                % límite
G_fdm = 1/(3*(1+mu));         % ganancia antes de la FM (|m| <= 1)

%% ---------- FM (una sola portadora) ----------
fc_fm = 100e3;
beta  = 5;
df    = beta*B_fdm;           % 6 kHz
Bfm   = 2*(df + B_fdm);       % Carson: 14.4 kHz

%% ---------- Receptor (f_rx lo define la GUI) ----------
if ~exist('f_rx','var'), f_rx = fsc(1); end   % canal: 0, 400 u 800 Hz
fi   = 17e3;
flo  = f_rx + fi;             % LO automático (usar 2*pi*flo en el Sine Wave)

%% ---------- Demodulador FM (a 500 kHz) ----------
Bf = 1.5*Bfm;                 % margen para el desplazamiento por DC
[z,p,k] = cheby1(4, 0.1, [fc_fm-Bf/2, fc_fm+Bf/2]/Fn, 'bandpass');
sos_rf  = zp2sos(z,p,k);
[z,p,k] = butter(6, 1.2e3/Fn, 'low');
sos_fmlp = zp2sos(z,p,k);     % Filtro AUD1 (pasa todo el FDM)
% Sign -> derivador -> abs -> sos_fmlp  da  y = 4*(fc_fm + df*m)
Kdem  = 1/(4*df);
DC_fm = fc_fm/df;             % 16.667

%% ---------- Diezmado ----------
Fs_d_obj = 100e3;                % antes 20e3: con FI de 17 kHz no cabe
M    = sampling_frec/Fs_d_obj;   % 5
Ts_d = M*sampling_time;          % 10 us
Fs_d = 1/Ts_d;                   % 100 kHz
Fn_d = Fs_d/2;                   % 50 kHz

%% ---------- Filtro FI (selector de canal AM) ----------
% Deseada: fi ± 150 Hz. Vecina: empieza en fi ± 250 Hz (separación 400 Hz)
Ap = 0.1;  As = 50;
Wp = [fi-160, fi+160]/Fn_d;
Ws = [fi-250, fi+250]/Fn_d;
[n, Wn] = ellipord(Wp, Ws, Ap, As);
[z,p,k] = ellip(n, Ap, As, Wn, 'bandpass');
sos_fi  = zp2sos(z,p,k);
fprintf('Orden del prototipo FI: %d | max|polo| = %.6f\n', n, max(abs(p)));

%% ---------- Verificación rápida ----------
[h,f] = freqz(sos_rf, 16384, sampling_frec);
for fx = [fc_fm-Bfm/2 fc_fm fc_fm+Bfm/2 fc_fm+2*Bfm]
    [~,i] = min(abs(f-fx));
    fprintf('RF a %.1f kHz: %.1f dB\n', fx/1e3, 20*log10(abs(h(i))));
end
[h,f] = freqz(sos_fi, 16384, Fs_d);
for o = [0 160 250 400]
    [~,i] = min(abs(f-(fi+o)));
    fprintf('FI offset %.0f Hz: %.1f dB\n', o, 20*log10(abs(h(i))));
end

%% ---------- Bloques del superheterodino (a Fs_d) ----------
[z,p,k] = butter(4, 30e3/Fn_d, 'low'); sos_lp1 = zp2sos(z,p,k);   % tras mezclador (antes 3 kHz)
[z,p,k] = butter(4, 200/Fn_d, 'low');  sos_aud = zp2sos(z,p,k);   % tras envolvente
[z,p,k] = butter(1, 10/Fn_d, 'high');  sos_dc  = zp2sos(z,p,k);   % solo tras envolvente

%% ---------- Referencia ----------
est = fsc;
[~, select] = min(abs(est - f_rx));
sintonizado = abs(est(select) - f_rx) < 1e-6;   % solo coincidencia exacta

%% ---------- Ruido AWGN (después de la FM) ----------
if ~exist('SNR_dB','var'), SNR_dB = Inf; end    % Inf = sin ruido
Ps = 0.5;                     % portadora FM única, A=1 -> A^2/2
B  = Bfm;                     % ancho donde se define la SNR
if isinf(SNR_dB)
    sigma2 = 0;
else
    sigma2 = (Ps/10^(SNR_dB/10)) * (Fn/B);
end
seed_ruido = 1234;

%% ---------- Ganancia de salida del receptor ----------
K_am = pi/(G_fdm*mu) / (1 + (select == 1));     % canal 1 sale 2x en la FI
epsilon = 1e-8;