clc;
clear;
close all;

%% =========================================================
% COMPARACION DE ARQUITECTURAS DE LA ANN
% ==========================================================
%
% Este script compara diferentes numeros de neuronas en la
% capa oculta manteniendo las mismas condiciones de entrenamiento:
%
%   - Base de datos
%   - Normalizacion Z-score
%   - Algoritmo Levenberg-Marquardt
%   - Funcion logsig en capa oculta
%   - Funcion purelin en capa de salida
%   - Division 70% entrenamiento, 15% validacion y 15% prueba
%   - MSE objetivo
%
% Arquitecturas evaluadas:
%
%   2-3-1
%   2-5-1
%   2-7-1
%   2-10-1
%   2-15-1
%
% Cada arquitectura se entrena 10 veces.
%
% IMPORTANTE:
% La misma division de entrenamiento, validacion y prueba
% se utiliza para todas las arquitecturas y ejecuciones.
%
% Las redes generadas en este script NO sustituyen la red
% utilizada en el articulo.


%% =========================================================
% CONFIGURACION GENERAL
% ==========================================================

% Numero de neuronas ocultas a comparar
neuronas_ocultas = [3 5 7 10 15];

% Numero de entrenamientos independientes por arquitectura
n_ejecuciones = 10;

% Numero maximo de epocas
max_epocas = 30000;

% MSE objetivo
perf_objetivo = 1e-6;

% Archivo con la base de datos
archivo_datos = 'dataset_TG_Vmpp_Impp_Pmpp.xlsx';

% Archivo Excel donde se guardaran los resultados
archivo_resultados = 'comparacion_arquitecturas_ANN.xlsx';


%% =========================================================
% LECTURA DE DATOS
% ==========================================================

tabla = readtable(archivo_datos,'Sheet','Hoja1');

T    = tabla.T;
G    = tabla.G;
Impp = tabla.Impp;

N = numel(Impp);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' COMPARACION DE ARQUITECTURAS DE LA ANN\n');
fprintf('============================================================\n');
fprintf('Numero total de muestras = %d\n', N);


%% =========================================================
% NORMALIZACION Z-SCORE
% ==========================================================
%
% Se utiliza el mismo procedimiento del codigo original.

Media_T    = mean(T);
Media_G    = mean(G);
Media_Impp = mean(Impp);

Std_T    = std(T);
Std_G    = std(G);
Std_Impp = std(Impp);

Norm_T    = (T    - Media_T)    / Std_T;
Norm_G    = (G    - Media_G)    / Std_G;
Norm_Impp = (Impp - Media_Impp) / Std_Impp;


%% =========================================================
% MATRICES DE ENTRADA Y SALIDA
% ==========================================================

Datos = [Norm_T'; Norm_G'];

Target = Norm_Impp';


%% =========================================================
% DIVISION FIJA 70 / 15 / 15
% ==========================================================
%
% Esta division se genera una sola vez.
% Todas las arquitecturas utilizan exactamente las mismas
% muestras para entrenamiento, validacion y prueba.

rng(2026,'twister');

indices = randperm(N);

n_train = floor(0.70*N);
n_val   = floor(0.15*N);

trainInd = indices(1:n_train);

valInd = indices(n_train+1 : n_train+n_val);

testInd = indices(n_train+n_val+1 : end);

fprintf('\n');
fprintf('============= DIVISION DE DATOS =============\n');
fprintf('Entrenamiento = %d muestras (%.2f %%)\n', ...
    numel(trainInd),100*numel(trainInd)/N);

fprintf('Validacion    = %d muestras (%.2f %%)\n', ...
    numel(valInd),100*numel(valInd)/N);

fprintf('Prueba        = %d muestras (%.2f %%)\n', ...
    numel(testInd),100*numel(testInd)/N);


%% =========================================================
% PREASIGNACION DE RESULTADOS
% ==========================================================

n_arquitecturas = numel(neuronas_ocultas);

total_ejecuciones = n_arquitecturas*n_ejecuciones;

Arquitectura_col = strings(total_ejecuciones,1);

Neuronas_col = zeros(total_ejecuciones,1);

Ejecucion_col = zeros(total_ejecuciones,1);

ErrorRelMedio_col = zeros(total_ejecuciones,1);

ErrorRelMax_col = zeros(total_ejecuciones,1);

ErrorRelMin_col = zeros(total_ejecuciones,1);

MSE_col = zeros(total_ejecuciones,1);

Epoca_col = zeros(total_ejecuciones,1);

fila = 0;


%% =========================================================
% BUCLE DE ARQUITECTURAS
% ==========================================================

for ia = 1:n_arquitecturas

    hiddenLayerSize = neuronas_ocultas(ia);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' ARQUITECTURA 2-%d-1\n', hiddenLayerSize);
    fprintf('============================================================\n');


    %% =====================================================
    % BUCLE DE ENTRENAMIENTOS
    % ======================================================

    for ejecucion = 1:n_ejecuciones

        fprintf('\n');
        fprintf('Ejecucion %d de %d\n', ejecucion, n_ejecuciones);


        %% =================================================
        % SEMILLA PARA INICIALIZACION DE LA RED
        % ==================================================
        %
        % Se utiliza una semilla diferente en cada ejecucion.
        % La misma secuencia de semillas se utiliza para todas
        % las arquitecturas.

        rng(1000 + ejecucion,'twister');


        %% =================================================
        % CREACION DE LA RED
        % ==================================================

        trainFcn = 'trainlm';

        net = feedforwardnet(hiddenLayerSize,trainFcn);


        %% =================================================
        % CONFIGURACION DE ENTRENAMIENTO
        % ==================================================

        net.trainParam.epochs = max_epocas;

        net.trainParam.goal = perf_objetivo;

        % Evitar abrir 50 ventanas de entrenamiento
        net.trainParam.showWindow = false;

        % Utilizar los mismos indices para todas las redes
        net.divideFcn = 'divideind';

        net.divideParam.trainInd = trainInd;
        net.divideParam.valInd   = valInd;
        net.divideParam.testInd  = testInd;


        %% =================================================
        % DESACTIVAR PROCESAMIENTO AUTOMATICO
        % ==================================================

        net.inputs{1}.processFcns = {};

        net.outputs{2}.processFcns = {};


        %% =================================================
        % FUNCIONES DE ACTIVACION
        % ==================================================

        net.layers{1}.transferFcn = 'logsig';

        net.layers{2}.transferFcn = 'purelin';


        %% =================================================
        % ENTRENAMIENTO
        % ==================================================

        [net,tr] = train(net,Datos,Target);


        %% =================================================
        % EVALUACION SOBRE EL CONJUNTO DE PRUEBA
        % ==================================================
        %
        % IMPORTANTE:
        % El error se calcula solamente con las muestras
        % pertenecientes al conjunto de prueba.

        Datos_test = Datos(:,testInd);

        Impp_test_real = Impp(testInd);


        % Prediccion normalizada
        Impp_test_pred_norm = net(Datos_test);


        % Desnormalizacion
        Impp_test_pred = ...
            Impp_test_pred_norm*Std_Impp + Media_Impp;


        %% =================================================
        % ERROR ABSOLUTO Y ERROR RELATIVO
        % ==================================================

        Error_abs = abs(Impp_test_pred(:) - Impp_test_real(:));

        Error_rel = ...
            100*Error_abs ./ Impp_test_real(:);


        %% =================================================
        % RESULTADOS DE LA EJECUCION
        % ==================================================

        error_rel_medio = mean(Error_rel);

        error_rel_max = max(Error_rel);

        error_rel_min = min(Error_rel);


        %% =================================================
        % GUARDAR RESULTADOS
        % ==================================================

        fila = fila + 1;

        Arquitectura_col(fila) = ...
            sprintf('2-%d-1',hiddenLayerSize);

        Neuronas_col(fila) = hiddenLayerSize;

        Ejecucion_col(fila) = ejecucion;

        ErrorRelMedio_col(fila) = error_rel_medio;

        ErrorRelMax_col(fila) = error_rel_max;

        ErrorRelMin_col(fila) = error_rel_min;

        MSE_col(fila) = tr.best_perf;

        Epoca_col(fila) = tr.best_epoch;


        %% =================================================
        % MOSTRAR RESULTADOS
        % ==================================================

        fprintf('Mejor MSE              = %.10e\n', ...
            tr.best_perf);

        fprintf('Mejor epoca            = %d\n', ...
            tr.best_epoch);

        fprintf('Error relativo medio   = %.6f %%\n', ...
            error_rel_medio);

        fprintf('Error relativo maximo  = %.6f %%\n', ...
            error_rel_max);

    end

end


%% =========================================================
% TABLA CON TODAS LAS EJECUCIONES
% ==========================================================

Resultados = table( ...
    Arquitectura_col, ...
    Neuronas_col, ...
    Ejecucion_col, ...
    ErrorRelMedio_col, ...
    ErrorRelMax_col, ...
    ErrorRelMin_col, ...
    MSE_col, ...
    Epoca_col, ...
    'VariableNames',{ ...
    'Arquitectura', ...
    'NeuronasOcultas', ...
    'Ejecucion', ...
    'ErrorRelMedio_pct', ...
    'ErrorRelMax_pct', ...
    'ErrorRelMin_pct', ...
    'MSE', ...
    'MejorEpoca'});


%% =========================================================
% TABLA RESUMEN POR ARQUITECTURA
% ==========================================================

Arquitectura_res = strings(n_arquitecturas,1);

Neuronas_res = zeros(n_arquitecturas,1);

ErrorRelMedio_res = zeros(n_arquitecturas,1);

ErrorRelMax_res = zeros(n_arquitecturas,1);

for ia = 1:n_arquitecturas

    h = neuronas_ocultas(ia);

    idx = Resultados.NeuronasOcultas == h;

    Arquitectura_res(ia) = sprintf('2-%d-1',h);

    Neuronas_res(ia) = h;


    % Promedio del error relativo medio obtenido
    % en los 10 entrenamientos
    ErrorRelMedio_res(ia) = ...
        mean(Resultados.ErrorRelMedio_pct(idx));


    % Mayor error relativo observado entre los
    % 10 entrenamientos
    ErrorRelMax_res(ia) = ...
        max(Resultados.ErrorRelMax_pct(idx));

end


Resumen = table( ...
    Arquitectura_res, ...
    Neuronas_res, ...
    ErrorRelMedio_res, ...
    ErrorRelMax_res, ...
    'VariableNames',{ ...
    'Arquitectura', ...
    'NeuronasOcultas', ...
    'ErrorRelMedio_pct', ...
    'ErrorRelMax_pct'});


%% =========================================================
% MOSTRAR RESULTADOS COMPLETOS
% ==========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' RESULTADOS DE LOS 50 ENTRENAMIENTOS\n');
fprintf('============================================================\n');

disp(Resultados);


%% =========================================================
% MOSTRAR RESUMEN FINAL
% ==========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' RESUMEN DE LA COMPARACION DE ARQUITECTURAS\n');
fprintf('============================================================\n');

disp(Resumen);


%% =========================================================
% GUARDAR RESULTADOS EN EXCEL
% ==========================================================

writetable(Resultados, ...
    archivo_resultados, ...
    'Sheet','Ejecuciones');

writetable(Resumen, ...
    archivo_resultados, ...
    'Sheet','Resumen');


%% =========================================================
% GUARDAR INFORMACION DE LA COMPARACION
% ==========================================================
%
% Se guardan tambien los indices utilizados para que pueda
% reproducirse exactamente la misma division de datos.

save('comparacion_arquitecturas_ANN.mat', ...
     'Resultados', ...
     'Resumen', ...
     'trainInd', ...
     'valInd', ...
     'testInd', ...
     'Media_T', ...
     'Media_G', ...
     'Media_Impp', ...
     'Std_T', ...
     'Std_G', ...
     'Std_Impp', ...
     'neuronas_ocultas', ...
     'n_ejecuciones');


%% =========================================================
% GRAFICA DE ERROR RELATIVO MEDIO
% ==========================================================

figure;

bar(Neuronas_res,ErrorRelMedio_res);

grid on;
box on;

xlabel('Número de neuronas ocultas');

ylabel('Error relativo medio (%)');

title('Comparación del error relativo medio de las arquitecturas ANN');


%% =========================================================
% GRAFICA DE ERROR RELATIVO MAXIMO
% ==========================================================

figure;

bar(Neuronas_res,ErrorRelMax_res);

grid on;
box on;

xlabel('Número de neuronas ocultas');

ylabel('Error relativo máximo (%)');

title('Comparación del error relativo máximo de las arquitecturas ANN');


%% =========================================================
% ARQUITECTURA CON MENOR ERROR RELATIVO MEDIO
% ==========================================================

[mejor_error,idx_mejor] = min(ErrorRelMedio_res);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' MENOR ERROR RELATIVO MEDIO\n');
fprintf('============================================================\n');

fprintf('Arquitectura = %s\n', ...
    Arquitectura_res(idx_mejor));

fprintf('Error relativo medio = %.6f %%\n', ...
    mejor_error);

fprintf('\nResultados guardados en:\n');
fprintf('%s\n',archivo_resultados);