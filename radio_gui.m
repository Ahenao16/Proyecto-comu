function radio_gui
modelo = 'radio_FM_simulink_2';
k_esc  = 100;
load_system(modelo);
yAud = [];

%% ---------- Ventana ----------
fig = uifigure('Name','Radio FM superheterodina','Position',[80 60 1100 720]);
g = uigridlayout(fig,[4 3]);
g.RowHeight   = {170,'1x','1x',30};
g.ColumnWidth = {'1x','1x','1x'};

%% ---------- Dial ----------
p = uipanel(g,'Title','Dial'); p.Layout.Row = 1; p.Layout.Column = [1 3];
pg = uigridlayout(p,[3 4]);
pg.ColumnWidth = {150,'1x',190,190};
pg.RowHeight = {'1x','1x','1x'};

lbl = uilabel(pg,'Text','Portadora (MHz)','FontWeight','bold');
lbl.Layout.Row = 1; lbl.Layout.Column = 1;

sld = uislider(pg,'Limits',[9.7 10.3],'Value',10.0, ...
    'MajorTicks',[9.8 10.0 10.2],'MajorTickLabels',{'9.8','10.0','10.2'});
sld.Layout.Row = [1 2]; sld.Layout.Column = 2;

lblFc = uilabel(pg,'Text','','FontSize',22,'FontWeight','bold');
lblFc.Layout.Row = 1; lblFc.Layout.Column = 3;
lblFi = uilabel(pg,'Text','','FontSize',16);
lblFi.Layout.Row = 1; lblFi.Layout.Column = 4;
lblLo = uilabel(pg,'Text','','FontSize',14);
lblLo.Layout.Row = 2; lblLo.Layout.Column = 3;

btnSnd = uibutton(pg,'Text','Escuchar','ButtonPushedFcn',@(~,~)escuchar());
btnSnd.Layout.Row = 2; btnSnd.Layout.Column = 1;

lblEst = uilabel(pg,'Text','','FontSize',14,'FontColor',[0.1 0.5 0.2]);
lblEst.Layout.Row = 2; lblEst.Layout.Column = 4;
lblAviso = uilabel(pg,'Text','','FontSize',13,'FontWeight','bold', ...
    'FontColor',[0.8 0.1 0.1],'WordWrap','on');
lblAviso.Layout.Row = 2; lblAviso.Layout.Column = 4;

%% ---------- Ruido ----------
cbRuido = uicheckbox(pg,'Text','Ruido AWGN','Value',false, ...
    'ValueChangedFcn',@(~,~)actualizar(sld.Value));
cbRuido.Layout.Row = 3; cbRuido.Layout.Column = 1;

sldSNR = uislider(pg,'Limits',[0 40],'Value',30,'MajorTicks',0:10:40, ...
    'ValueChangedFcn',@(~,~)actualizar(sld.Value));
sldSNR.Layout.Row = 3; sldSNR.Layout.Column = 2;

lblSNR = uilabel(pg,'Text','Sin ruido','FontSize',14);
lblSNR.Layout.Row = 3; lblSNR.Layout.Column = 3;

%% ---------- Gráficas ----------
ax1 = uiaxes(g); ax1.Layout.Row = 2; ax1.Layout.Column = [1 2];
ax2 = uiaxes(g); ax2.Layout.Row = 2; ax2.Layout.Column = 3;
ax3 = uiaxes(g); ax3.Layout.Row = 3; ax3.Layout.Column = [1 2];
ax4 = uiaxes(g); ax4.Layout.Row = 3; ax4.Layout.Column = 3;
lblSt = uilabel(g,'Text','Listo'); lblSt.Layout.Row = 4; lblSt.Layout.Column = [1 3];

sld.ValueChangedFcn = @(~,~)actualizar(imanes(sld.Value));
actualizar(10.0);

%% ---------- Callbacks ----------
    function actualizar(f_MHz)
        sld.Value = f_MHz;
        lblSt.Text = 'Simulando...'; drawnow;

        if cbRuido.Value
            assignin('base','SNR_dB',sldSNR.Value);
            lblSNR.Text = sprintf('SNR = %.0f dB',sldSNR.Value);
        else
            assignin('base','SNR_dB',Inf);
            lblSNR.Text = 'Sin ruido';
        end

        f_rx = f_MHz*1e6/k_esc;
        assignin('base','f_rx',f_rx);
        evalc('evalin(''base'',''parametros'')');
        fi = evalin('base','fi');   flo = evalin('base','flo');
        Fs = evalin('base','sampling_frec');
        sint   = evalin('base','sintonizado');
        select = evalin('base','select');

        out = sim(modelo,'StopTime','2');

        lblFc.Text = sprintf('%.3f MHz', f_MHz);
        lblFi.Text = sprintf('FI = %.2f MHz', fi*k_esc/1e6);
        lblLo.Text = sprintf('LO = %.3f MHz', flo*k_esc/1e6);

        n0 = round(0.15*Fs);
        sfdm = getv(out,'s_fdm'); sfdm = sfdm(n0:end);
        sfi  = getv(out,'s_fi');  sfi  = sfi(n0:end);
        mh   = getv(out,'m_hat'); mh   = mh(n0:end);
        mr   = getv(out,'m_ref'); mr   = mr(n0:end);

        espectro(ax1,sfdm,Fs,[94 106]*1e3,k_esc);
        title(ax1,'Espectro del FDM (transmisor)');
        xline(ax1,f_MHz,'r','LineWidth',1.5);
        espectro(ax2,sfi,Fs,[10 24]*1e3,k_esc);
        title(ax2,'Espectro en la FI');
        xline(ax2,fi*k_esc/1e6,'r','LineWidth',1.5);

        cla(ax3); cla(ax4); legend(ax3,'off');
        t = (0:numel(mh)-1)'/Fs;  m = t < 0.08;
        [P,F] = pwelch(mh-mean(mh),hann(2^17),[],2^18,Fs);

        estado = sprintf('Listo. f_rx simulada = %.1f kHz',f_rx/1e3);
        if sint
            lblAviso.Text = '';
            lblEst.Text = sprintf('Sintonizada: estación %d',select);
            plot(ax3,t(m),mr(m),t(m),mh(m)); grid(ax3,'on');
            legend(ax3,'Original','Recuperada');
            title(ax3,'Audio demodulado vs. original');
            nn = min(numel(mh),numel(mr));
            estado = sprintf('%s | RMSE = %.3f',estado,rms(mh(1:nn)-mr(1:nn)));
        else
            lblEst.Text = '';
            lblAviso.Text = 'No se está sintonizando una frecuencia portadora exacta';
            plot(ax3,t(m),mh(m),'Color',[0.85 0.33 0.1]); grid(ax3,'on');
            title(ax3,'Señal demodulada (sin comparación)');
        end
        xlabel(ax3,'Tiempo (s, simulado)');

        plot(ax4,F(F<400),10*log10(P(F<400)+eps)); grid(ax4,'on');
        xlabel(ax4,'Hz (simulado)'); ylabel(ax4,'dB');
        title(ax4,'Espectro del audio recuperado');

        yAud = mh;
        lblSt.Text = estado;
    end

    function escuchar()
        if isempty(yAud)
            uialert(fig,'No hay señal para reproducir.','Sin señal');
            return;
        end

        Fs = evalin('base','sampling_frec');

        % Descartar el transitorio inicial
        n0_aud = round(0.30 * Fs);

        if length(yAud) > n0_aud
            y = yAud(n0_aud:end);
        else
            y = yAud;
        end

        % Eliminar componente DC
        y = y - mean(y);

        % Remuestrear directamente a 16 kHz
        y = resample(y, 16000, Fs);

        % Normalizar amplitud
        max_val = max(abs(y));

        if max_val > 0
            y = 0.8 * y / max_val;
        end

        % Reproducir
        sound(y, 16000);
    end
end

function v = getv(out,name)
v = squeeze(out.get(name)); v = v(:);
end

function espectro(ax,x,Fs,rango,k_esc)
[P,F] = pwelch(x-mean(x),hann(2^15),[],2^16,Fs);
m = F>=rango(1) & F<=rango(2);
plot(ax,F(m)*k_esc/1e6,10*log10(P(m)+eps)); grid(ax,'on');
xlabel(ax,'MHz (nominal)'); ylabel(ax,'dB'); xlim(ax,rango*k_esc/1e6);
end

function v = imanes(x)
est = [9.8 10.0 10.2];
[d,i] = min(abs(est-x));
if d <= 0.03, v = est(i); else, v = x; end
end