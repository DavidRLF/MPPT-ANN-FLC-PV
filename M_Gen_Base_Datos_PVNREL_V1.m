clc; clear; close all;

%% ================== PARÁMETROS FÍSICOS DEL PANEL/ARREGLO ==================
Ncell    = 72;          % celdas en serie por panel
Voc_STC  = 44.2;        % V (para rango de barrido del arreglo)
Isc      = 8.42;        % A (Short-circuit current)
Ki       = 0.005305;    % A/K, coef temp de corto circ = (%/C/100)*Isc
Rspanel  = 0.38773;     % Ohm (serie)
Rshpanel = 300.2269;    % Ohm (shunt)
Is       = 7.7188e-10;  % A (Io @STC)
n        = 1.0345;      % idealidad

% Constantes
k1   = 1.3806e-23;      % J/K (Boltzmann)
q    = 1.60218e-19;     % C
Tref = 298.15;          % K
Gref = 1000;            % W/m^2

% Bandgap
Egref = 1.121;          % eV
dEgdT = -0.0002677;     % eV/K

% Geometría (para IL)
Apanel = 195.4*98.2;    % cm^2
Acell  = Apanel/Ncell;

% Arreglo
Nser = 18;              % paneles en serie
Npar = 2;               % ramas en paralelo

% Calibración fina de IL (opcional)
gamma_IL = 1.00255;

%% ================== SWITCHS DE CONTROL ==================
plot_enable_2D = 0;    % 1 = mostrar curvas I–V (2D), 0 = no
plot_enable_3D = 1;    % 1 = mostrar superficies T–G (3D), 0 = no
do_save        = true; % 1 = guardar Excel principal T,G,Vmpp,Impp,Pmpp
do_save_curves = false; % 1 = guardar Excel con Vp,Ip + Vmpp,Impp,Pmpp por punto

% --- SOLO para las 3D: orientación de ejes ---
flip_T_axis = false;   % false = Tmin al frente; true = Tmax al frente
flip_G_axis = true;    % true = Gmax al frente (eje G invertido)

outfile         = 'dataset_TG_Vmpp_Impp_Pmpp.xlsx';
outfile_curves  = 'dataset_TG_Vp_Ip_Vmpp_Impp_Pmpp.xlsx';

%% ================== RANGOS DE BARRIDO ==================
% Temperatura en °C
T_min = -25;     T_max = 85;    dT = 2;
T_vec = T_min:dT:T_max;

% Irradiancia en W/m^2
G_min = 100;   G_max = 1200;  dG = 25;
G_vec = G_min:dG:G_max;

% Vector de voltajes para las curvas I–V del ARREGLO
Va = 0:1:800;

%% === Chequeo de tamaño de datasets (antes de simular/guardar) ===
N_T  = numel(T_vec);
N_G  = numel(G_vec);
N_Va = numel(Va);

N_comb         = N_T * N_G;        % combinaciones T–G
rows_compacto  = N_comb;           % filas T,G,Vmpp,Impp,Pmpp
rows_extendido = N_comb * N_Va;    % filas T,G,Vp,Ip,Vmpp,Impp,Pmpp

excel_limit = 1048576; % filas por hoja en Excel

fprintf('\n=== Plan de generación de datos ===\n');
fprintf('T valores: %d | G valores: %d | Puntos por curva (Va): %d\n', N_T, N_G, N_Va);
fprintf('Dataset compacto (T,G,Vmpp,Impp,Pmpp): %d filas\n', rows_compacto);
fprintf('Dataset extendido (T,G,Vp,Ip,Vmpp,Impp,Pmpp): %d filas (límite Excel=%d)\n', ...
    rows_extendido, excel_limit);

if rows_extendido > excel_limit
    warning('El dataset extendido excede el límite de Excel. Se desactiva do_save_curves para evitar error.');
    do_save_curves = false;
end

%% ================== OPCIONES NUMÉRICAS ==================
opts = optimoptions('fsolve','Display','off', ...
    'FunctionTolerance',1e-14,'StepTolerance',1e-14);

%% ================== PREASIGNACIÓN DE DATASET ==================
nT = numel(T_vec); nG = numel(G_vec);
T_col    = zeros(nT*nG,1);
G_col    = zeros(nT*nG,1);
Vmpp_col = zeros(nT*nG,1);
Impp_col = zeros(nT*nG,1);
Pmpp_col = zeros(nT*nG,1);
row = 0;

% --- Acumuladores para el segundo Excel (curvas Vp/Ip + MPP) ---
T_all    = [];
G_all    = [];
Vp_all   = [];
Ip_all   = [];
Vmpp_all = [];
Impp_all = [];
Pmpp_all = [];

%% ================== PROGRESO Y ETA ==================
total_iters = nT * nG * numel(Va);   % se cuenta cada evaluación I(V) en fsolve
iter_done   = 0;
tStart      = tic;
hbar = waitbar(0, 'Iniciando simulación...', 'Name','Progreso T–G–V');
lastUpdate  = 0;           % último porcentaje mostrado (0..1)

%% ================== BUCLES PRINCIPALES ==================
for it = 1:nT
    T_degC = T_vec(it);
    Tcell  = 273.15 + T_degC;
    Eg     = Egref*(1 + dEgdT*(Tcell - Tref));     % eV

    % Residual (ecuación implícita) para esta T
    residual = @(I,Va_loc,G_loc) ...
        + gamma_IL * Npar * ( Isc/Apanel + Ki*(Tcell - Tref)/Apanel ) * (G_loc/Gref) * Apanel ...
        - ( Npar*Is*(Tcell/Tref)^3 .* exp( (q*Egref)/(k1*Tref) - (q*Eg)/(k1*Tcell) ) ) ...
            .* ( exp( ( Va_loc + I.*Rspanel*(Nser/Npar) ) ./ ( Nser * n * Ncell * (k1*Tcell/q) ) ) - 1 ) ...
        - ( Va_loc + I.*Rspanel*(Nser/Npar) ) ./ ( Rshpanel*(Nser/Npar) ) .* ( G_loc/Gref ) ...
        - I;

    % ====== Gráfica 2D por temperatura (I–V del arreglo) ======
    if plot_enable_2D
        figure('Name',sprintf('I–V | T = %g °C',T_degC));
        hold on; grid on; box on
        xlabel('Voltage (V)'); ylabel('Current (A)');
        title(sprintf('Curvas I–V del arreglo | T = %g °C',T_degC));
    end
    legtxt = cell(numel(G_vec),1);

    for ig = 1:nG
        G = G_vec(ig);

        % Semilla inicial
        Iseed = gamma_IL * Npar * ( Isc/Apanel + Ki*(Tcell - Tref)/Apanel ) * (G/Gref) * Apanel;
        Iseed = max(0, Iseed);

        % Resolver I(V)
        Ivals = zeros(size(Va));
        for k = 1:numel(Va)
            Vk = Va(k);
            Iseed    = max(0, Iseed);
            Ivals(k) = fsolve(@(I) residual(I, Vk, G), Iseed, opts);
            Iseed    = Ivals(k);

            % ---- Actualizar progreso/ETA cada 100 iteraciones ----
            iter_done = iter_done + 1;
            if mod(iter_done, 100) == 0 || iter_done == 1 || iter_done == total_iters
                elapsed   = toc(tStart);
                frac      = iter_done / total_iters;
                rate      = max(iter_done / max(elapsed, eps), eps);  % iters/seg
                remain_s  = max((total_iters - iter_done) / rate, 0);
                eta_str   = fmtTime(remain_s);
                % waitbar (evitar exceso de updates)
                if frac - lastUpdate >= 0.005 || iter_done == total_iters
                    if isvalid(hbar)
                        waitbar(frac, hbar, sprintf('Progreso: %5.1f%% | ETA: %s', 100*frac, eta_str));
                    end
                    lastUpdate = frac;
                end
                % Consola (línea única)
                %fprintf('\rProgreso: %6.2f%% | Transcurrido: %s | ETA: %s', 100*frac, fmtTime(elapsed), eta_str);
            end
        end

        % Magnitudes no negativas
        Pvals = Va .* Ivals;
        Ivis  = max(Ivals, 0);
        Pvis  = max(Pvals, 0);

        % MPP
        mask  = isfinite(Pvis) & isfinite(Ivis) & Va>=0;
        Pphys = Pvis(mask);  Vphys = Va(mask);  Iphys = Ivis(mask);
        [Pmpp, iM] = max(Pphys);
        Vmpp       = Vphys(iM);
        Impp       = Iphys(iM);

        % Guardar fila (dataset principal)
        row = row + 1;
        T_col(row)    = T_degC;
        G_col(row)    = G;
        Vmpp_col(row) = Vmpp;
        Impp_col(row) = Impp;
        Pmpp_col(row) = Pmpp;

        % --- Acumular para el segundo Excel ---
        Va_col   = Va(:);
        Ivis_col = Ivis(:);
        mask_curve = isfinite(Ivis_col) & (Ivis_col >= 0) & isfinite(Va_col);
        Vp_tmp   = Va_col(mask_curve);
        Ip_tmp   = Ivis_col(mask_curve);

        Vmpp_tmp = repmat(Vmpp, numel(Vp_tmp), 1);
        Impp_tmp = repmat(Impp, numel(Vp_tmp), 1);
        Pmpp_tmp = repmat(Pmpp, numel(Vp_tmp), 1);
        T_tmp    = repmat(T_degC, numel(Vp_tmp), 1);
        G_tmp    = repmat(G,      numel(Vp_tmp), 1);

        T_all    = [T_all;    T_tmp];
        G_all    = [G_all;    G_tmp];
        Vp_all   = [Vp_all;   Vp_tmp];
        Ip_all   = [Ip_all;   Ip_tmp];
        Vmpp_all = [Vmpp_all; Vmpp_tmp];
        Impp_all = [Impp_all; Impp_tmp];
        Pmpp_all = [Pmpp_all; Pmpp_tmp];

        % ----- Curvas 2D (I–V) y punto MPP -----
        if plot_enable_2D
            plot(Va, Ivis, 'LineWidth', 1.1);
            legtxt{ig} = sprintf('G=%g W/m^2', G);
            plot(Vmpp, Impp, 'ko', 'MarkerFaceColor','k', 'HandleVisibility','off');
        end
    end

    if plot_enable_2D
        legend(legtxt, 'Location','northeastoutside');
    end
end

% Cerrar barra y salto de línea después del \r
if exist('hbar','var') && isvalid(hbar), close(hbar); end
fprintf('\n');

%% ================== TABLA RESULTANTE (principal) ==================
Data = table(T_col, G_col, Vmpp_col, Impp_col, Pmpp_col, ...
    'VariableNames', {'T','G','Vmpp','Impp','Pmpp'});

if do_save
    writetable(Data, outfile, 'FileType','spreadsheet');
end

%% ================== SEGUNDO EXCEL: curvas Vp/Ip + MPP ==================
if do_save_curves
    DataCurves = table(T_all, G_all, Vp_all, Ip_all, Vmpp_all, Impp_all, Pmpp_all, ...
        'VariableNames', {'T','G','Vp','Ip','Vmpp','Impp','Pmpp'});
    writetable(DataCurves, outfile_curves, 'FileType','spreadsheet');
end

%% ===== Gráficas 3D T–G vs Vmpp/Impp/Pmpp (sin malla punteada) =====
if plot_enable_3D
    Tfile = readtable(outfile);

    Tall  = Tfile.T(:);
    Gall  = Tfile.G(:);
    VmppA = Tfile.Vmpp(:);
    ImppA = Tfile.Impp(:);
    PmppA = Tfile.Pmpp(:);

    Tu = unique(Tall,'sorted');
    Gu = unique(Gall,'sorted');
    nT = numel(Tu);
    nG = numel(Gu);

    Vm = nan(nG,nT); Im = nan(nG,nT); Pm = nan(nG,nT);
    [~,jT] = ismember(Tall, Tu);
    [~,iG] = ismember(Gall, Gu);
    idx = sub2ind([nG,nT], iG, jT);
    Vm(idx) = VmppA;  Im(idx) = ImppA;  Pm(idx) = PmppA;

    dotSize = 22; cmap = jet(256);
    viewAz  = 225; viewEl = 26;

    xdirMode = 'normal'; if flip_T_axis, xdirMode = 'reverse'; end
    ydirMode = 'normal'; if flip_G_axis, ydirMode = 'reverse'; end

    [TT,GG] = meshgrid(Tu, Gu);

    % Vmpp
    figure; scatter3(TT(:),GG(:),Vm(:),dotSize,Vm(:),'*','MarkerEdgeColor','flat');
    colormap(cmap); colorbar; grid on; box on
    set(gca,'XDir',xdirMode,'YDir',ydirMode)
    view([viewAz viewEl]); axis tight
    xlabel('Temperature T (°C)'); ylabel('Irradiation G (W/m^2)'); zlabel('Vmpp (V)');
    title('Vmpp en función de T y G (archivo)');

    % Impp
    figure; scatter3(TT(:),GG(:),Im(:),dotSize,Im(:),'*','MarkerEdgeColor','flat');
    colormap(cmap); colorbar; grid on; box on
    set(gca,'XDir',xdirMode,'YDir',ydirMode)
    view([viewAz viewEl]); axis tight
    xlabel('Temperature T (°C)'); ylabel('Irradiation G (W/m^2)'); zlabel('Impp (A)');
    title('Impp en función de T y G (archivo)');

    % Pmpp
    figure; scatter3(TT(:),GG(:),Pm(:),dotSize,Pm(:),'*','MarkerEdgeColor','flat');
    colormap(cmap); colorbar; grid on; box on
    set(gca,'XDir',xdirMode,'YDir',ydirMode)
    view([viewAz viewEl]); axis tight
    xlabel('Temperature T (°C)'); ylabel('Irradiation G (W/m^2)'); zlabel('Pmpp (W)');
    title('Pmpp en función de T y G (archivo)');
end

%% ====== Función local para formatear tiempos (hh:mm:ss) ======
function s = fmtTime(sec)
    sec = max(sec,0);
    h = floor(sec/3600); m = floor(mod(sec,3600)/60); s2 = floor(mod(sec,60));
    s = sprintf('%02d:%02d:%02d', h, m, s2);
end
