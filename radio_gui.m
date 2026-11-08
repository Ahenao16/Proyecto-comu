function radio_gui
cfg.modelo  = 'radio_FM_simulink_final';
cfg.R_carga = 1;      % ohm: igual que el Spectrum Analyzer de Simulink
load_system(cfg.modelo);

% parametros.m define 'escala'. Se borran f_rx y fc_fm para partir de sus valores por defecto
evalin('base','clear f_rx fc_fm');
assignin('base','SNR_dB',Inf);
evalc('evalin(''base'',''parametros'')');
cfg.fi  = evalin('base','fi');                   % FI simulada (Hz)
cfg.k   = evalin('base','escala');
cfg.fsc = evalin('base','fsc')*cfg.k/1e3;        % subportadoras reales (kHz)
fc0     = evalin('base','fc_fm')*cfg.k/1e6;      % portadora FM real (MHz)

%% ---------- Ventana con pestañas ----------
sz = get(0,'ScreenSize');
w  = min(1100, sz(3)-80);  h = min(700, sz(4)-140);
fig  = uifigure('Name','Radio FM superheterodina', ...
    'Position',[max(20,(sz(3)-w)/2) max(40,(sz(4)-h)/2) w h]);
tg   = uitabgroup(fig,'Units','normalized','Position',[0 0 1 1]);
tab1 = uitab(tg,'Title','FDM y Receptor');
tab2 = uitab(tg,'Title','Modulador y Demodulador FM');

%% ---------- Pestaña 1: receptor ----------
g = uigridlayout(tab1,[4 3]);
g.RowHeight   = {150,'1x','1x',26};
g.ColumnWidth = {'1x','1x','1x'};

p = uipanel(g,'Title','Dial'); p.Layout.Row = 1; p.Layout.Column = [1 3];
pg = uigridlayout(p,[3 5]);
pg.ColumnWidth = {150,'1x',170,150,170};
pg.RowHeight = {'1x','1x','1x'};
pg.Padding = [8 4 8 4];  pg.RowSpacing = 2;

% Fila 1: portadora FM (MHz reales)
lblPort = uilabel(pg,'Text','Portadora FM (MHz)','FontWeight','bold','WordWrap','on');
lblPort.Layout.Row = 1; lblPort.Layout.Column = 1;
sldFc = uislider(pg,'Limits',[fc0/2 1.5*fc0],'Value',fc0, ...
    'MajorTicks',fc0/2:fc0/4:1.5*fc0);
sldFc.Layout.Row = 1; sldFc.Layout.Column = 2;
lblFcm = uilabel(pg,'Text','','FontSize',18,'FontWeight','bold');
lblFcm.Layout.Row = 1; lblFcm.Layout.Column = 3;
lblFi = uilabel(pg,'Text','','FontSize',14);
lblFi.Layout.Row = 1; lblFi.Layout.Column = 4;
btnSim = uibutton(pg,'Text','Simular','FontSize',15,'FontWeight','bold', ...
    'BackgroundColor',[0.2 0.6 0.3],'FontColor',[1 1 1]);
btnSim.Layout.Row = 1; btnSim.Layout.Column = 5;

% Fila 2: canal sintonizado (kHz reales)
lbl = uilabel(pg,'Text','Frecuencia sintonizada (kHz)','FontWeight','bold','WordWrap','on');
lbl.Layout.Row = 2; lbl.Layout.Column = 1;
sld = uislider(pg,'Limits',[0 cfg.fsc(end)*1.125],'Value',cfg.fsc(2), ...
    'MajorTicks',cfg.fsc, ...
    'MajorTickLabels',arrayfun(@(x)sprintf('%g',x),cfg.fsc,'UniformOutput',false));
sld.Layout.Row = 2; sld.Layout.Column = 2;
lblFc = uilabel(pg,'Text','','FontSize',16,'FontWeight','bold');
lblFc.Layout.Row = 2; lblFc.Layout.Column = 3;
lblLo = uilabel(pg,'Text','','FontSize',14);
lblLo.Layout.Row = 2; lblLo.Layout.Column = 4;
btnSnd = uibutton(pg,'Text','Escuchar','FontSize',14);
btnSnd.Layout.Row = 2; btnSnd.Layout.Column = 5;

% Fila 3: ruido y estado
cbRuido = uicheckbox(pg,'Text','Ruido AWGN','Value',false);
cbRuido.Layout.Row = 3; cbRuido.Layout.Column = 1;
sldSNR = uislider(pg,'Limits',[0 40],'Value',30,'MajorTicks',0:10:40);
sldSNR.Layout.Row = 3; sldSNR.Layout.Column = 2;
lblSNR = uilabel(pg,'Text','Sin ruido','FontSize',14);
lblSNR.Layout.Row = 3; lblSNR.Layout.Column = 3;
lblEst = uilabel(pg,'Text','','FontSize',13,'FontColor',[0.1 0.5 0.2],'WordWrap','on');
lblEst.Layout.Row = 3; lblEst.Layout.Column = 4;
lblAviso = uilabel(pg,'Text','','FontSize',11,'FontWeight','bold', ...
    'FontColor',[0.8 0.1 0.1],'WordWrap','on');
lblAviso.Layout.Row = 3; lblAviso.Layout.Column = 4;
lblPend = uilabel(pg,'Text','','FontSize',12,'FontWeight','bold', ...
    'FontColor',[0.85 0.45 0],'WordWrap','on');
lblPend.Layout.Row = 3; lblPend.Layout.Column = 5;

ax1 = uiaxes(g); ax1.Layout.Row = 2; ax1.Layout.Column = [1 2];
ax2 = uiaxes(g); ax2.Layout.Row = 2; ax2.Layout.Column = 3;
ax3 = uiaxes(g); ax3.Layout.Row = 3; ax3.Layout.Column = [1 2];
ax4 = uiaxes(g); ax4.Layout.Row = 3; ax4.Layout.Column = 3;
lblSt = uilabel(g,'Text','Listo'); lblSt.Layout.Row = 4; lblSt.Layout.Column = [1 3];

%% ---------- Pestaña 2: espectros de la cadena FM ----------
g2 = uigridlayout(tab2,[1 2]);
g2.ColumnWidth = {'1x','1x'};
ax5 = uiaxes(g2); ax5.Layout.Row = 1; ax5.Layout.Column = 1;
ax6 = uiaxes(g2); ax6.Layout.Row = 1; ax6.Layout.Column = 2;

%% ---------- Estado compartido (sin funciones anidadas) ----------
ui = struct('sld',sld,'sldFc',sldFc,'lblFcm',lblFcm,'lblFc',lblFc, ...
    'lblFi',lblFi,'lblLo',lblLo,'lblEst',lblEst,'lblAviso',lblAviso, ...
    'lblPend',lblPend,'btnSim',btnSim,'cbRuido',cbRuido, ...
    'sldSNR',sldSNR,'lblSNR',lblSNR,'ax1',ax1,'ax2',ax2, ...
    'ax3',ax3,'ax4',ax4,'ax5',ax5,'ax6',ax6,'lblSt',lblSt);
fig.UserData = struct('ui',ui,'cfg',cfg,'yAud',[],'Fs_aud',100e3);

%% ---------- Callbacks ----------
% Los controles solo actualizan etiquetas; la simulación la lanza el botón
sld.ValueChangedFcn     = @(~,~)cambio(fig);
sldFc.ValueChangedFcn   = @(~,~)cambio(fig);
cbRuido.ValueChangedFcn = @(~,~)cambio(fig);
sldSNR.ValueChangedFcn  = @(~,~)cambio(fig);
btnSim.ButtonPushedFcn  = @(~,~)simular(fig);
btnSnd.ButtonPushedFcn  = @(~,~)escuchar(fig);

refrescar(fig);
lblSt.Text = 'Listo. Presione "Simular" para correr el modelo.';
end

%% =====================================================================
function cambio(fig)
S = fig.UserData;  ui = S.ui;
ui.sld.Value   = imanes(ui.sld.Value,S.cfg.fsc,3);   % imán de 3 kHz reales
ui.sldFc.Value = round(ui.sldFc.Value*10)/10;        % pasos de 0.1 MHz
refrescar(fig);
ui.lblPend.Text = 'Cambios sin simular';
end

%% =====================================================================
function refrescar(fig)
S = fig.UserData;  ui = S.ui;
fi   = S.cfg.fi*S.cfg.k;             % FI real (Hz)
f_rx = ui.sld.Value;                 % kHz reales
fc   = ui.sldFc.Value;               % MHz reales

ui.lblFcm.Text = sprintf('fc = %.1f MHz',fc);
ui.lblFc.Text  = sprintf('f_rx = %.0f kHz',f_rx);
ui.lblFi.Text  = sprintf('FI = %.2f MHz',fi/1e6);
ui.lblLo.Text  = sprintf('LO = %.2f MHz',(f_rx*1e3+fi)/1e6);
if ui.cbRuido.Value
    ui.lblSNR.Text = sprintf('SNR = %.0f dB',ui.sldSNR.Value);
else
    ui.lblSNR.Text = 'Sin ruido';
end
end

%% =====================================================================
function simular(fig)
S = fig.UserData;  ui = S.ui;
modelo = S.cfg.modelo;  R_carga = S.cfg.R_carga;  k = S.cfg.k;
ek = k/1e3;                          % Hz simulados -> kHz reales
eM = k/1e6;                          % Hz simulados -> MHz reales

% Valores reales de la GUI -> unidades de simulación
f_rx = ui.sld.Value*1e3/k;
fc   = round(ui.sldFc.Value*1e6/k);
ui.btnSim.Enable = 'off';
ui.lblPend.Text = '';
ui.lblSt.Text = 'Simulando...'; drawnow;

try
    if ui.cbRuido.Value
        assignin('base','SNR_dB',ui.sldSNR.Value);
    else
        assignin('base','SNR_dB',Inf);
    end
    assignin('base','f_rx',f_rx);
    assignin('base','fc_fm',fc);
    evalc('evalin(''base'',''parametros'')');
    out = sim(modelo,'StopTime','2');
catch err
    ui.btnSim.Enable = 'on';
    ui.lblSt.Text = 'Error en la simulación';
    uialert(fig,err.message,'Error de simulación');
    return;
end

fi     = evalin('base','fi');
fsc    = evalin('base','fsc');
fc_fm  = evalin('base','fc_fm');
Bfm    = evalin('base','Bfm');
sint   = evalin('base','sintonizado');
select = evalin('base','select');
T      = out.tout(end);

% Señales (cada una con su propia frecuencia de muestreo)
[sfdm,f1] = getv(out,'s_fdm',T);  sfdm = sfdm(round(0.15*f1)+1:end);
[sfi, f2] = getv(out,'s_fi', T);  sfi  = sfi(round(0.15*f2)+1:end);
[sfm, f3] = getv(out,'s_fm', T);  sfm  = sfm(round(0.15*f3)+1:end);
[sdem,f4] = getv(out,'s_dem',T);  sdem = sdem(round(0.15*f4)+1:end);
[mh,  Fa] = getv(out,'m_hat',T);
[mr,  fr] = getv(out,'m_ref',T);
if fr ~= Fa, mr = resample(mr,Fa,fr); end
n0 = round(0.15*Fa)+1;
mh = mh(n0:end);  mr = mr(n0:end);
nn = min(numel(mh),numel(mr));  mh = mh(1:nn);  mr = mr(1:nn);

%% ----- Pestaña 1 -----
% Espectro del FDM (kHz reales), con las subportadoras marcadas
espectro(ui.ax1,sfdm,f1,[0 1200],ek,'kHz',R_carga);
title(ui.ax1,'Espectro del FDM (transmisor)');
xline(ui.ax1,fsc*ek,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax1,f_rx*ek,'r','LineWidth',1.5);

% Espectro en la FI (MHz reales), centrado en fi
espectro(ui.ax2,sfi,f2,[fi-1e3 fi+1e3],eM,'MHz',R_carga);
title(ui.ax2,'Espectro en la FI');
xline(ui.ax2,fi*eM,'r','LineWidth',1.5);

cla(ui.ax3); cla(ui.ax4); legend(ui.ax3,'off');
estado = sprintf('Listo. fc = %.1f MHz | f_rx = %.0f kHz',fc*eM,f_rx*ek);

if sint
    ui.lblAviso.Text = '';
    ui.lblEst.Text = sprintf('Sintonizada: estación %d', select);
    d = finddelay(mr,mh,round(0.03*Fa));
    if d > 0, mh_a = mh(d+1:end); mr_a = mr(1:end-d);
    else,     mh_a = mh;          mr_a = mr; end
    t = (0:numel(mr_a)-1)'/Fa;  m = t < 0.15;
    plot(ui.ax3,t(m)*1e3/k,mr_a(m),t(m)*1e3/k,mh_a(m)); grid(ui.ax3,'on');
    legend(ui.ax3,'Original','Recuperada');
    title(ui.ax3,'Audio demodulado vs. original');
    thd_pct = calcula_thd(mh,Fa);
    estado = sprintf('%s | THD = %.2f %%',estado,thd_pct);
else
    ui.lblEst.Text = '';
    ui.lblAviso.Text = sprintf('No se está sintonizando una subportadora (%s kHz)', ...
        strjoin(arrayfun(@(x)sprintf('%g',x),S.cfg.fsc,'UniformOutput',false),', '));
    t = (0:numel(mh)-1)'/Fa;  m = t < 0.15;
    plot(ui.ax3,t(m)*1e3/k,mh(m),'Color',[0.85 0.33 0.1]); grid(ui.ax3,'on');
    title(ui.ax3,'Señal demodulada (sin comparación)');
    estado = sprintf('%s | THD = n/d',estado);
end
xlabel(ui.ax3,'Tiempo (ms)');

[P,F] = pwelch(mh-mean(mh),hann(min(2^15,2^floor(log2(numel(mh)/2)))), ...
    [],2*min(2^15,2^floor(log2(numel(mh)/2))),Fa,'power');
Pdbm = 10*log10((P/R_carga)/1e-3 + eps);
plot(ui.ax4,F(F<400)*ek,Pdbm(F<400)); grid(ui.ax4,'on');
xlabel(ui.ax4,'Frecuencia (kHz)'); ylabel(ui.ax4,'dBm');
title(ui.ax4,'Espectro del audio recuperado');

%% ----- Pestaña 2: salida del modulador FM (RF) -----
[F,P,Pd] = psd_dbm(sfm,f3,R_carga);
m = F>=fc_fm-20e3 & F<=fc_fm+20e3;
cla(ui.ax5);
plot(ui.ax5,F(m)*eM,Pd(m)); grid(ui.ax5,'on');
xline(ui.ax5,(fc_fm-Bfm/2)*eM,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax5,(fc_fm+Bfm/2)*eM,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax5,fc_fm*eM,'r','LineWidth',1.5);
xlabel(ui.ax5,'Frecuencia (MHz)'); ylabel(ui.ax5,'dBm');
title(ui.ax5,sprintf('Salida del modulador FM: BW 99%% = %.2f MHz (Carson %.2f MHz)', ...
    bw99(F,P)*eM,Bfm*eM));

%% ----- Pestaña 2: salida del demodulador FM (banda base) -----
legend(ui.ax6,'off'); cla(ui.ax6);
[F,~,Pd]   = psd_dbm(sdem,f4,R_carga);   m  = F<=1200;
[F0,~,Pd0] = psd_dbm(sfdm,f1,R_carga);   m0 = F0<=1200;
plot(ui.ax6,F(m)*ek,Pd(m),'LineWidth',1.3); hold(ui.ax6,'on');
plot(ui.ax6,F0(m0)*ek,Pd0(m0),'Color',[0.6 0.6 0.6]); hold(ui.ax6,'off');
grid(ui.ax6,'on');
lg = legend(ui.ax6,'Tras demodulador FM','FDM transmitido');
lg.AutoUpdate = 'off';
xline(ui.ax6,fsc*ek,':','Color',[0.4 0.4 0.4]);
xlim(ui.ax6,[0 1200]*ek);
xlabel(ui.ax6,'Frecuencia (kHz)'); ylabel(ui.ax6,'dBm');
title(ui.ax6,'Salida del demodulador FM vs. FDM transmitido');

% Guardar el audio para el botón "Escuchar"
S = fig.UserData;
S.yAud = mh;  S.Fs_aud = Fa;
fig.UserData = S;
ui.lblSt.Text = estado;
ui.btnSim.Enable = 'on';
end

%% =====================================================================
function escuchar(fig)
% Se reproduce la señal a escala de simulación (tonos de ~100 Hz, audibles)
S = fig.UserData;
yAud = S.yAud;  Fs_aud = S.Fs_aud;
if isempty(yAud)
    uialert(fig,'No hay señal para reproducir.','Sin señal');
    return;
end
n0_aud = round(0.30*Fs_aud);
if length(yAud) > n0_aud, y = yAud(n0_aud:end); else, y = yAud; end
y = y - mean(y);
y = resample(y,16000,round(Fs_aud));
max_val = max(abs(y));
if max_val > 0, y = 0.8*y/max_val; end
sound(y,16000);
end

%% =====================================================================
function [v,fs] = getv(out,name,T)
v  = squeeze(out.get(name)); v = v(:);
fs = round((numel(v)-1)/T);          % frecuencia de muestreo de esta señal
end

function [F,P,Pdbm] = psd_dbm(x,Fs,R)
% Potencia por bin (V^2) y su equivalente en dBm sobre la carga R
nseg = min(2^16, 2^floor(log2(numel(x)/2)));
[P,F] = pwelch(x,hann(nseg),[],2*nseg,Fs,'power');
Pdbm  = 10*log10((P/R)/1e-3 + eps);
end

function bw = bw99(F,P)
% Ancho que contiene el 99 % de la potencia (0.5 % por cada lado)
c  = cumsum(P)/sum(P);
bw = F(find(c>=0.995,1)) - F(find(c>=0.005,1));
end

function thd_pct = calcula_thd(x,Fs)
x = x(:) - mean(x);
r = thd(x,Fs,5);                     % dB respecto a la fundamental, 5 armónicos
thd_pct = 100*10^(r/20);
end

function espectro(ax,x,Fs,rango,esc,unidad,R)
% No se resta la media: el DC del canal 1 (portadora de 0 Hz) debe verse
% 'rango' en Hz simulados; 'esc' convierte al eje que se muestra
[F,~,Pdbm] = psd_dbm(x,Fs,R);
m = F>=rango(1) & F<=rango(2);
plot(ax,F(m)*esc,Pdbm(m)); grid(ax,'on');
xlabel(ax,['Frecuencia (' unidad ')']); ylabel(ax,'dBm');
xlim(ax,rango*esc);
end

function v = imanes(x,est,tol)
% est y tol en kHz reales
[d,i] = min(abs(est-x));
if d <= tol, v = est(i); else, v = x; end
end