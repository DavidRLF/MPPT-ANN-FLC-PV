clc; clear; close all;

%% ================== CARGAR RED NEURONAL ENTRENADA ==================
% Este script evalúa una red neuronal previamente entrenada para aproximar
% la corriente en el punto de máxima potencia, Impp.
%
% La red neuronal debe estar guardada en un archivo .mat con:
%
%   net          -> red neuronal entrenada
%   Media_T      -> media de temperatura usada en entrenamiento
%   Media_G      -> media de irradiancia usada en entrenamiento
%   Media_Impp   -> media de Impp usada en entrenamiento
%   Std_T        -> desviación estándar de temperatura
%   Std_G        -> desviación estándar de irradiancia
%   Std_Impp     -> desviación estándar de Impp
%
% La red usa:
%   Entrada 1 -> T en °C
%   Entrada 2 -> G en W/m^2
%   Salida    -> Impp en A

nombre_red = 'net_Impp_TG.mat';

load(nombre_red, 'net', ...
                 'Media_T', 'Media_G', 'Media_Impp', ...
                 'Std_T', 'Std_G', 'Std_Impp');


%% ================== PARAMETROS FISICOS DEL PANEL/ARREGLO PV ==================

Ncell    = 72;          
Voc_STC  = 44.2;        
Isc      = 8.42;        
Ki       = 0.005305;    
Rspanel  = 0.38773;     
Rshpanel = 300.2269;    
Is       = 7.7188e-10;  
n        = 1.0345;      

% Constantes físicas
k1   = 1.3806e-23;      
q    = 1.60218e-19;     
Tref = 298.15;          
Gref = 1000;            

% Parámetros del bandgap
Egref = 1.121;          
dEgdT = -0.0002677;     

% Geometría del panel
Apanel = 195.4*98.2;    
Acell  = Apanel/Ncell; %#ok<NASGU>

% Configuración del arreglo PV
Nser = 18;              
Npar = 2;               

% Factor fino de calibración de la corriente fotogenerada
gamma_IL = 1.00255;


%% ================== INTERRUPTORES DE CONTROL ==================

% Bandera para guardar la tabla de resultados en Excel
do_save = true;

% Nombre del archivo de salida
outfile_error = 'dataset_error_ANN_vs_full_model.xlsx';

% Activar o desactivar gráficas
plot_error_vs_G = true;
plot_error_surface = true;
plot_Impp_compare = true;


%% ================== RANGOS DE BARRIDO ==================

% Rango de temperatura en °C
T_min = 15;   
T_max = 55;   
dT    = 10;
T_vec = T_min:dT:T_max;

% Rango de irradiancia en W/m^2
G_min = 200;  
G_max = 1200; 
dG    = 200;
G_vec = G_min:dG:G_max;

% Barrido de voltaje del arreglo para construir la curva I-V
Va = 0:1:800;


%% ================== OPCIONES NUMERICAS ==================

% Opciones para resolver la ecuación no lineal con fsolve
opts = optimoptions('fsolve','Display','off', ...
    'FunctionTolerance',1e-12,'StepTolerance',1e-12);


%% ================== PREASIGNACION DE MEMORIA ==================

% Número de puntos de temperatura
nT = numel(T_vec);

% Número de puntos de irradiancia
nG = numel(G_vec);

% Número total de condiciones de operación
N  = nT * nG;

% Vectores para almacenar los resultados
T_col          = zeros(N,1);
G_col          = zeros(N,1);
Vmpp_col       = zeros(N,1);
Impp_full_col  = zeros(N,1);
Pmpp_col       = zeros(N,1);
Impp_ANN_col   = zeros(N,1);
ErrAbs_col     = zeros(N,1);
ErrRel_col     = zeros(N,1);

% Contador de filas
row = 0;


%% ================== BUCLES PRINCIPALES ==================

% Bucle externo sobre temperatura
for it = 1:nT

    T_degC = T_vec(it);             % Temperatura en °C
    Tcell  = 273.15 + T_degC;       % Temperatura en Kelvin

    % Energía de bandgap actualizada con la temperatura
    Eg = Egref*(1 + dEgdT*(Tcell - Tref));  

    % Ecuación no lineal del modelo PV escrita como función residual.
    % fsolve busca la corriente I que hace que esta función sea igual a cero.
    residual = @(I,Va_loc,G_loc) ...
        + gamma_IL * Npar * ( Isc/Apanel + Ki*(Tcell - Tref)/Apanel ) * (G_loc/Gref) * Apanel ...
        - ( Npar*Is*(Tcell/Tref)^3 .* exp( (q*Egref)/(k1*Tref) - (q*Eg)/(k1*Tcell) ) ) ...
            .* ( exp( ( Va_loc + I.*Rspanel*(Nser/Npar) ) ./ ( Nser * n * Ncell * (k1*Tcell/q) ) ) - 1 ) ...
        - ( Va_loc + I.*Rspanel*(Nser/Npar) ) ./ ( Rshpanel*(Nser/Npar) ) .* ( G_loc/Gref ) ...
        - I;

    % Bucle interno sobre irradiancia
    for ig = 1:nG

        G = G_vec(ig);              % Irradiancia actual

        % Semilla inicial para el solucionador no lineal.
        % Se aproxima con la corriente fotogenerada.
        Iseed = gamma_IL * Npar * ( Isc/Apanel + Ki*(Tcell - Tref)/Apanel ) * (G/Gref) * Apanel;
        Iseed = max(0, Iseed);

        % Resolver la curva I-V punto por punto
        Ivals = zeros(size(Va));

        for k = 1:numel(Va)

            Vk = Va(k);             % Voltaje actual del barrido

            % Mantener semilla no negativa
            Iseed = max(0, Iseed);

            % Resolver corriente para el voltaje actual
            Ivals(k) = fsolve(@(I) residual(I, Vk, G), Iseed, opts);

            % Usar la solución previa como semilla para el siguiente punto
            Iseed = Ivals(k);

        end

        % Magnitudes físicas
        % Se recortan valores negativos por consistencia física
        Ivis = max(Ivals, 0);
        Pvis = max(Va .* Ivis, 0);

        % Mantener solo valores finitos y físicamente válidos
        mask = isfinite(Pvis) & isfinite(Ivis) & Va >= 0;

        Vphys = Va(mask);
        Iphys = Ivis(mask);
        Pphys = Pvis(mask);

        % Encontrar el punto de máxima potencia del modelo completo
        [Pmpp, iM] = max(Pphys);

        Vmpp      = Vphys(iM);
        Impp_full = Iphys(iM);


        %% ================== PREDICCION DE Impp CON LA RED NEURONAL ==================
        % La red neuronal aproxima Impp a partir de:
        %
        %   Entrada 1 -> Temperatura T en °C
        %   Entrada 2 -> Irradiancia G en W/m^2
        %
        % IMPORTANTE:
        % La red fue entrenada con variables normalizadas.
        % Por eso, antes de evaluar la red se debe aplicar la misma
        % normalización usada durante el entrenamiento.

        % Normalizar temperatura
        Norm_T_Aux = (T_degC - Media_T) / Std_T;

        % Normalizar irradiancia
        Norm_G_Aux = (G - Media_G) / Std_G;

        % Entradas normalizadas de la red
        x1 = Norm_T_Aux;
        x2 = Norm_G_Aux;

        % Evaluar la red neuronal con las entradas normalizadas
        Impp_ANN_norm = net([x1; x2]);

        % Desnormalizar la salida para obtener Impp en amperes
        Impp_ANN = Impp_ANN_norm * Std_Impp + Media_Impp;


        %% ================== ERROR ENTRE ANN Y MODELO COMPLETO ==================

        % Error absoluto en amperes
        ErrAbs = abs(Impp_ANN - Impp_full);

        % Error relativo porcentual
        ErrRel = 100 * ErrAbs / Impp_full;


        %% ================== ALMACENAR RESULTADOS ==================

        row = row + 1;

        T_col(row)         = T_degC;
        G_col(row)         = G;
        Vmpp_col(row)      = Vmpp;
        Impp_full_col(row) = Impp_full;
        Pmpp_col(row)      = Pmpp;
        Impp_ANN_col(row)  = Impp_ANN;
        ErrAbs_col(row)    = ErrAbs;
        ErrRel_col(row)    = ErrRel;

    end
end


%% ================== TABLA DE RESULTADOS ==================

DataError = table(T_col, G_col, Vmpp_col, Impp_full_col, Pmpp_col, ...
                  Impp_ANN_col, ErrAbs_col, ErrRel_col, ...
    'VariableNames', {'T','G','Vmpp','Impp_full','Pmpp','Impp_ANN','ErrAbs_A','ErrRel_pct'});

% Mostrar tabla completa en la ventana de comandos
disp(DataError);

% Guardar tabla en Excel si la bandera está activada
if do_save
    writetable(DataError, outfile_error, 'FileType','spreadsheet');
end


%% ================== RESUMEN GLOBAL ==================

% Estadísticas globales del error relativo
mean_err = mean(ErrRel_col);
max_err  = max(ErrRel_col);
min_err  = min(ErrRel_col);

fprintf('\n==== RESUMEN DEL ERROR DE LA ANN ====\n');
fprintf('Error relativo medio  = %.4f %%\n', mean_err);
fprintf('Error relativo maximo = %.4f %%\n', max_err);
fprintf('Error relativo minimo = %.4f %%\n', min_err);


%% ================== ERROR PROMEDIO POR TEMPERATURA ==================

fprintf('\n==== ERROR RELATIVO PROMEDIO POR TEMPERATURA ====\n');

for it = 1:nT

    Tnow = T_vec(it);
    idxT = (T_col == Tnow);

    fprintf('T = %5.1f °C --> Error medio = %.4f %% | Error maximo = %.4f %%\n', ...
        Tnow, mean(ErrRel_col(idxT)), max(ErrRel_col(idxT)));

end


%% ================== FIGURA 1: ERROR vs G PARA CADA T ==================

if plot_error_vs_G

    figure;
    hold on; grid on; box on;

    % Graficar error relativo contra irradiancia para cada temperatura
    for it = 1:nT

        Tnow = T_vec(it);
        idxT = (T_col == Tnow);

        plot(G_col(idxT), ErrRel_col(idxT), '-o', 'LineWidth', 1.3, ...
            'DisplayName', sprintf('T = %g °C', Tnow));

    end

    xlabel('Irradiancia G (W/m^2)');
    ylabel('Error relativo de la ANN (%)');
    title('Error relativo de aproximación de la ANN bajo diferentes temperaturas');
    legend('Location','best');

end


%% ================== FIGURA 2: SUPERFICIE DE ERROR ==================

if plot_error_surface

    % Obtener valores únicos ordenados
    Tu = unique(T_col, 'sorted');
    Gu = unique(G_col, 'sorted');

    % Construir malla para la superficie
    [TT, GG] = meshgrid(Tu, Gu);
    EE = nan(numel(Gu), numel(Tu));

    % Llenar matriz de error
    for i = 1:height(DataError)

        iT = find(Tu == DataError.T(i));
        iG = find(Gu == DataError.G(i));

        EE(iG, iT) = DataError.ErrRel_pct(i);

    end

    figure('Color','w','Position',[100 100 1200 900]);

    surf(TT, GG, EE, ...
        'EdgeColor','k', ...
        'LineWidth',0.8, ...
        'FaceColor','interp');

    colormap('parula');
    colorbar;

    grid on;
    box on;

    view(-45,30);

    xlabel('Temperatura T (°C)');
    ylabel('Irradiancia G (W/m^2)');
    zlabel('Error relativo (%)');

    title('Superficie de error de aproximación de la ANN');

    set(gca, ...
        'FontSize',18, ...
        'LineWidth',1.2);

end


%% ================== FIGURA 3: Impp COMPLETO vs ANN ==================

if plot_Impp_compare

    figure;
    hold on; grid on; box on;

    % Comparar Impp del modelo completo contra Impp predicho por la ANN
    for it = 1:nT

        Tnow = T_vec(it);
        idxT = (T_col == Tnow);

        plot(G_col(idxT), Impp_full_col(idxT), '-o', 'LineWidth', 1.4, ...
            'DisplayName', sprintf('Modelo completo, T=%g °C', Tnow));

        plot(G_col(idxT), Impp_ANN_col(idxT), '--s', 'LineWidth', 1.2, ...
            'DisplayName', sprintf('ANN, T=%g °C', Tnow));

    end

    xlabel('Irradiancia G (W/m^2)');
    ylabel('I_{mpp} (A)');
    title('Comparación entre I_{mpp} del modelo completo y la ANN');
    legend('Location','best');

end