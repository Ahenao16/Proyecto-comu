function radio_gui
cfg.modelo  = 'radio_FM_simulink_2';
cfg.R_carga = 1;      % ohm: igual que el Spectrum Analyzer de Simulink
load_system(cfg.modelo);

%% ---------- Ventana con pestañas ----------
fig  = uifigure('Name','Radio FM superheterodina','Position',[80 60 1100 720]);
tg   = uitabgroup(fig,'Units','normalized','Position',[0 0 1 1]);
tab1 = uitab(tg,'Title','FDM y Receptor');
tab2 = uitab(tg,'Title','Modulador y Demodulador FM');

%% ---------- Pestaña 1: receptor ----------
g = uigridlayout(tab1,[4 3]);
g.RowHeight   = {170,'1x','1x',30};
g.ColumnWidth = {'1x','1x','1x'};

p = uipanel(g,'Title','Dial'); p.Layout.Row = 1; p.Layout.Column = [1 3];
pg = uigridlayout(p,[3 4]);
pg.ColumnWidth = {170,'1x',190,190};
pg.RowHeight = {'1x','1x','1x'};

lbl = uilabel(pg,'Text','Frecuencia sintonizada (Hz)','FontWeight','bold','WordWrap','on');
lbl.Layout.Row = 1; lbl.Layout.Column = 1;

sld = uislider(pg,'Limits',[0 900],'Value',400, ...
    'MajorTicks',[0 400 800],'MajorTickLabels',{'0','400','800'});
sld.Layout.Row = [1 2]; sld.Layout.Column = 2;

lblFc = uilabel(pg,'Text','','FontSize',22,'FontWeight','bold');
lblFc.Layout.Row = 1; lblFc.Layout.Column = 3;
lblFi = uilabel(pg,'Text','','FontSize',16);
lblFi.Layout.Row = 1; lblFi.Layout.Column = 4;
lblLo = uilabel(pg,'Text','','FontSize',14);
lblLo.Layout.Row = 2; lblLo.Layout.Column = 3;

btnSnd = uibutton(pg,'Text','Escuchar');
btnSnd.Layout.Row = 2; btnSnd.Layout.Column = 1;

lblEst = uilabel(pg,'Text','','FontSize',14,'FontColor',[0.1 0.5 0.2]);
lblEst.Layout.Row = 2; lblEst.Layout.Column = 4;
lblAviso = uilabel(pg,'Text','','FontSize',13,'FontWeight','bold', ...
    'FontColor',[0.8 0.1 0.1],'WordWrap','on');
lblAviso.Layout.Row = 2; lblAviso.Layout.Column = 4;

cbRuido = uicheckbox(pg,'Text','Ruido AWGN','Value',false);
cbRuido.Layout.Row = 3; cbRuido.Layout.Column = 1;

sldSNR = uislider(pg,'Limits',[0 40],'Value',30,'MajorTicks',0:10:40);
sldSNR.Layout.Row = 3; sldSNR.Layout.Column = 2;

lblSNR = uilabel(pg,'Text','Sin ruido','FontSize',14);
lblSNR.Layout.Row = 3; lblSNR.Layout.Column = 3;

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
ui = struct('sld',sld,'lblFc',lblFc,'lblFi',lblFi,'lblLo',lblLo, ...
    'lblEst',lblEst,'lblAviso',lblAviso,'cbRuido',cbRuido, ...
    'sldSNR',sldSNR,'lblSNR',lblSNR,'ax1',ax1,'ax2',ax2, ...
    'ax3',ax3,'ax4',ax4,'ax5',ax5,'ax6',ax6,'lblSt',lblSt);
fig.UserData = struct('ui',ui,'cfg',cfg,'yAud',[],'Fs_aud',100e3);

%% ---------- Callbacks ----------
sld.ValueChangedFcn     = @(~,~)actualizar(fig,imanes(sld.Value));
cbRuido.ValueChangedFcn = @(~,~)actualizar(fig,sld.Value);
sldSNR.ValueChangedFcn  = @(~,~)actualizar(fig,sld.Value);
btnSnd.ButtonPushedFcn  = @(~,~)escuchar(fig);

actualizar(fig,400);
end

%% =====================================================================
function actualizar(fig,f_rx)
S = fig.UserData;  ui = S.ui;
modelo = S.cfg.modelo;  R_carga = S.cfg.R_carga;

ui.sld.Value = f_rx;
ui.lblSt.Text = 'Simulando...'; drawnow;

if ui.cbRuido.Value
    assignin('base','SNR_dB',ui.sldSNR.Value);
    ui.lblSNR.Text = sprintf('SNR = %.0f dB',ui.sldSNR.Value);
else
    assignin('base','SNR_dB',Inf);
    ui.lblSNR.Text = 'Sin ruido';
end

assignin('base','f_rx',f_rx);
evalc('evalin(''base'',''parametros'')');
fi     = evalin('base','fi');
flo    = evalin('base','flo');
fsc    = evalin('base','fsc');
fc_fm  = evalin('base','fc_fm');
Bfm    = evalin('base','Bfm');
sint   = evalin('base','sintonizado');
select = evalin('base','select');

out = sim(modelo,'StopTime','2');
T   = out.tout(end);

ui.lblFc.Text = sprintf('f_rx = %.0f Hz', f_rx);
ui.lblFi.Text = sprintf('FI = %.1f kHz', fi/1e3);
ui.lblLo.Text = sprintf('LO = %.1f kHz', flo/1e3);

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
% Espectro del FDM: 0 a 1.2 kHz, con las subportadoras marcadas
espectro(ui.ax1,sfdm,f1,[0 1200],1,'Hz',R_carga);
title(ui.ax1,'Espectro del FDM (transmisor)');
xline(ui.ax1,fsc,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax1,f_rx,'r','LineWidth',1.5);

% Espectro en la FI: centrado en fi
espectro(ui.ax2,sfi,f2,[fi-1e3 fi+1e3],1e-3,'kHz',R_carga);
title(ui.ax2,'Espectro en la FI');
xline(ui.ax2,fi/1e3,'r','LineWidth',1.5);

cla(ui.ax3); cla(ui.ax4); legend(ui.ax3,'off');
estado = sprintf('Listo. f_rx = %.0f Hz',f_rx);

if sint
    ui.lblAviso.Text = '';
    ui.lblEst.Text = sprintf('Sintonizada: estación %d', select);
    d = finddelay(mr,mh,round(0.03*Fa));
    if d > 0, mh_a = mh(d+1:end); mr_a = mr(1:end-d);
    else,     mh_a = mh;          mr_a = mr; end
    t = (0:numel(mr_a)-1)'/Fa;  m = t < 0.15;
    plot(ui.ax3,t(m),mr_a(m),t(m),mh_a(m)); grid(ui.ax3,'on');
    legend(ui.ax3,'Original','Recuperada');
    title(ui.ax3,'Audio demodulado vs. original');
    thd_pct = calcula_thd(mh,Fa);
    estado = sprintf('%s | THD = %.2f %%',estado,thd_pct);
else
    ui.lblEst.Text = '';
    ui.lblAviso.Text = 'No se está sintonizando una subportadora (0, 400 u 800 Hz)';
    t = (0:numel(mh)-1)'/Fa;  m = t < 0.15;
    plot(ui.ax3,t(m),mh(m),'Color',[0.85 0.33 0.1]); grid(ui.ax3,'on');
    title(ui.ax3,'Señal demodulada (sin comparación)');
    estado = sprintf('%s | THD = n/d',estado);
end
xlabel(ui.ax3,'Tiempo (s)');

[P,F] = pwelch(mh-mean(mh),hann(min(2^15,2^floor(log2(numel(mh)/2)))), ...
    [],2*min(2^15,2^floor(log2(numel(mh)/2))),Fa,'power');
Pdbm = 10*log10((P/R_carga)/1e-3 + eps);
plot(ui.ax4,F(F<400),Pdbm(F<400)); grid(ui.ax4,'on');
xlabel(ui.ax4,'Frecuencia (Hz)'); ylabel(ui.ax4,'dBm');
title(ui.ax4,'Espectro del audio recuperado');

%% ----- Pestaña 2: salida del modulador FM (RF) -----
[F,P,Pd] = psd_dbm(sfm,f3,R_carga);
m = F>=fc_fm-20e3 & F<=fc_fm+20e3;
cla(ui.ax5);
plot(ui.ax5,F(m)/1e3,Pd(m)); grid(ui.ax5,'on');
xline(ui.ax5,(fc_fm-Bfm/2)/1e3,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax5,(fc_fm+Bfm/2)/1e3,'--','Color',[0.6 0.6 0.6]);
xline(ui.ax5,fc_fm/1e3,'r','LineWidth',1.5);
xlabel(ui.ax5,'Frecuencia (kHz)'); ylabel(ui.ax5,'dBm');
title(ui.ax5,sprintf('Salida del modulador FM: BW 99%% = %.1f kHz (Carson %.1f kHz)', ...
    bw99(F,P)/1e3,Bfm/1e3));

%% ----- Pestaña 2: salida del demodulador FM (banda base) -----
legend(ui.ax6,'off'); cla(ui.ax6);
[F,~,Pd]   = psd_dbm(sdem,f4,R_carga);   m  = F<=1200;
[F0,~,Pd0] = psd_dbm(sfdm,f1,R_carga);   m0 = F0<=1200;
plot(ui.ax6,F(m),Pd(m),'LineWidth',1.3); hold(ui.ax6,'on');
plot(ui.ax6,F0(m0),Pd0(m0),'Color',[0.6 0.6 0.6]); hold(ui.ax6,'off');
grid(ui.ax6,'on');
lg = legend(ui.ax6,'Tras demodulador FM','FDM transmitido');
lg.AutoUpdate = 'off';
xline(ui.ax6,fsc,':','Color',[0.4 0.4 0.4]);
xlim(ui.ax6,[0 1200]);
xlabel(ui.ax6,'Frecuencia (Hz)'); ylabel(ui.ax6,'dBm');
title(ui.ax6,'Salida del demodulador FM vs. FDM transmitido');

% Guardar el audio para el botón "Escuchar"
S.yAud = mh;  S.Fs_aud = Fa;
fig.UserData = S;
ui.lblSt.Text = estado;
end

%% =====================================================================
function escuchar(fig)
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
[F,~,Pdbm] = psd_dbm(x,Fs,R);
m = F>=rango(1) & F<=rango(2);
plot(ax,F(m)*esc,Pdbm(m)); grid(ax,'on');
xlabel(ax,['Frecuencia (' unidad ')']); ylabel(ax,'dBm');
xlim(ax,rango*esc);
end

function v = imanes(x)
est = [0 400 800];                   % subportadoras (Hz)
[d,i] = min(abs(est-x));
if d <= 30, v = est(i); else, v = x; end
end