%% Escalamiento de frecuencias
% Todo el sistema se simula con las frecuencias divididas entre 100 para no
% saturar la simulación. 
% En la GUI se toma en cuenta la escala para mostrar valores reales.
escala = 100;   % 1 Hz simulado = escala Hz reales



%% Muestreo
% Se muestrea a 500 kHz, que es 5 veces la mayor frecuencia simulada (la portadora FM)
sampling_time = 2e-6;
sampling_frec = 1/sampling_time;      % 500 kHz
Fn = sampling_frec/2;                 % frecuencia de Nyquist



%% Normalizador de señal (AGC)
% epsilon evita la división por cero dentro del AGC cuando la envolvente es casi nula
epsilon = 1e-8;



%% Mensajes, AM y FDM
W     = 150;                  % ancho de banda de cada mensaje (Hz)
mu    = 0.5;                  % índice de modulación AM

% El canal 1 va en banda base y los canales 2 y 3 se trasladan con AM
fc_am1 = 0;
fc_am2 = 400;
fc_am3 = 800;
fsc    = [fc_am1 fc_am2 fc_am3];
% Bandas ocupadas: 0-150 | 250-550 | 650-950 Hz, o sea unos 950 Hz de FDM

B_fdm = 1.2e3;                % ancho de banda máximo permitido (120 kHz reales)

% Ganancia que deja la señal multiplexada con |m| <= 1 antes de la FM.
% Cada canal AM llega a 1+mu como máximo y son tres canales.
G_fdm = 1/(3*(1+mu));

% Especificaciones del filtro pasabajos que limita cada mensaje
fp_in = 150;                  % frecuencia de paso (Hz)
fs_in = 170;                  % frecuencia de rechazo (Hz)
Ap_in = 0.1;                  % rizado máximo en la banda de paso (dB)
As_in = 20;                   % atenuación mínima en la banda de rechazo (dB)



%% Modulador FM
% La portadora la define la GUI. Si se corre el script solo, se usa el valor nominal.
if ~exist('fc_fm','var'), fc_fm = 100e3; end   % portadora FM (10 MHz reales)

% Con beta = 5 (como en FM comercial) se obtiene la desviación de frecuencia
beta  = 5;
df    = beta*B_fdm;           % 6 kHz
Bfm   = 2*(df + B_fdm);       % ancho de banda por Carson: 14.4 kHz



%% Canal con ruido AWGN
% El ruido se suma después del modulador FM. Si no hay SNR definida, el canal es ideal.
if ~exist('SNR_dB','var'), SNR_dB = Inf; end    % Inf = sin ruido

Ps = 0.5;                     % potencia de la portadora FM con A = 1 (A^2/2)
B  = Bfm;                     % ancho de banda sobre el que se define la SNR

% La potencia de ruido se reparte en todo Fn, pero solo importa la que cae en Bfm
if isinf(SNR_dB)
    var_n = 0;
else
    var_n = (Ps/10^(SNR_dB/10)) * (Fn/B);   % varianza por muestra (V^2)
end

% Valor para el bloque Band-Limited White Noise (su varianza es Noise power / Ts)
sigma2 = var_n*sampling_time;
seed_ruido = 1234;



%% Receptor superheterodino: canal y oscilador local
% La GUI define el canal que se quiere sintonizar. Por defecto se usa el canal 1.
if ~exist('f_rx','var'), f_rx = fsc(1); end   % canal: 0, 400 u 800 Hz

% Frecuencia intermedia (1.7 MHz reales) y oscilador local calculado solo
fi   = 17e3;
flo  = f_rx + fi;             % usar 2*pi*flo en el bloque Sine Wave del LO

% Se busca el canal más cercano a f_rx y se avisa si no coincide con ninguno
est = fsc;
[~, select] = min(abs(est - f_rx));
sintonizado = abs(est(select) - f_rx) < 1e-6;   % solo cuenta la coincidencia exacta



%% Demodulador FM
% Filtro RF pasabanda (Chebyshev) centrado en la portadora. El margen extra
% de 1.5 veces Carson deja pasar el corrimiento que mete el DC.
Bf = 1.5*Bfm;
assert(fc_fm-Bf/2 > 0 && fc_fm+Bf/2 < Fn, 'fc_fm fuera de rango para Fs = %g Hz', sampling_frec);
[z,p,k] = cheby1(4, 0.1, [fc_fm-Bf/2, fc_fm+Bf/2]/Fn, 'bandpass');
sos_rf  = zp2sos(z,p,k);

% Pasabajos que deja pasar todo el FDM (filtro fmlp, 1.2 kHz)
[z,p,k] = butter(6, 1.2e3/Fn, 'low');
sos_fmlp = zp2sos(z,p,k);

% Cadena de detección de pendiente: limitador -> derivador -> abs -> sos_fmlp,
% lo que da y = 4*(fc_fm + df*m)
G_dem = 1.26227;              % ganancia de calibración del demodulador (se ajustó con pruebas)
Kdem  = G_dem/(4*df);
DC_fm = G_dem*fc_fm/df;       % nivel DC de la portadora, escala igual que Kdem y se resta a la salida



%% Diezmado
% Se baja la frecuencia de muestreo para aliviar el resto del receptor.
% Con la FI en 17 kHz no cabía en 20 kHz, por eso se usa 100 kHz.
Fs_d_obj = 100e3;
M    = sampling_frec/Fs_d_obj;   % factor de diezmado (5)
Ts_d = M*sampling_time;          % 10 us
Fs_d = 1/Ts_d;                   % 100 kHz
Fn_d = Fs_d/2;                   % 50 kHz



%% Filtro de FI (selector de canal AM)
% Debe dejar pasar el canal deseado en fi ± 150 Hz y rechazar al vecino,
% que empieza en fi ± 250 Hz (separación de 400 Hz entre subportadoras).
Ap = 0.1;  As = 50;
Wp = [fi-160, fi+160]/Fn_d;
Ws = [fi-250, fi+250]/Fn_d;
[n, Wn] = ellipord(Wp, Ws, Ap, As);
[z,p,k] = ellip(n, Ap, As, Wn, 'bandpass');
sos_fi  = zp2sos(z,p,k);
fprintf('Orden del prototipo FI: %d | max|polo| = %.6f\n', n, max(abs(p)));



%% Bloques del superheterodino (a Fs_d)
% Pasabajos después del mezclador, quita los productos de suma
[z,p,k] = butter(4, 30e3/Fn_d, 'low'); sos_lp1 = zp2sos(z,p,k);

% Pasabajos después del detector de envolvente, deja pasar el mensaje (150 Hz)
% y quita los armónicos de la rectificación
[z,p,k] = butter(4, 200/Fn_d, 'low');  sos_aud = zp2sos(z,p,k);

% Pasaaltos que elimina el nivel continuo del término (1 + mu*m)
[z,p,k] = butter(1, 10/Fn_d, 'high');  sos_dc  = zp2sos(z,p,k);



%% Ganancia de salida del receptor
% Ajusta el nivel de la señal recuperada. El canal 1 sale al doble de amplitud
% por estar en banda base, así que su ganancia se divide entre 2.
K_am = pi/(G_fdm*mu) / (1 + (select == 1));



%% Verificación rápida de los filtros
% Imprime la atenuación del filtro RF en el borde de la banda, el centro y fuera de banda
[h,f] = freqz(sos_rf, 16384, sampling_frec);
for fx = [fc_fm-Bfm/2 fc_fm fc_fm+Bfm/2 fc_fm+2*Bfm]
    [~,i] = min(abs(f-fx));
    fprintf('RF a %.1f kHz: %.1f dB\n', fx/1e3, 20*log10(abs(h(i))));
end

% Lo mismo para el filtro de FI, medido a distintos desplazamientos de fi
[h,f] = freqz(sos_fi, 16384, Fs_d);
for o = [0 160 250 400]
    [~,i] = min(abs(f-(fi+o)));
    fprintf('FI offset %.0f Hz: %.1f dB\n', o, 20*log10(abs(h(i))));
end