clc;            % Limpia la ventana de comandos
clear all;      % Borra todas las variables del workspace
close all;      % Cierra todas las figuras

%% =========================================================
%  MODO DE OPERACION
% ==========================================================
% modo_red = 1 -> Entrenar una nueva red neuronal
% modo_red = 0 -> Cargar una red neuronal previamente guardada

modo_red = 0;   % Cambia a 0 si quieres usar la red guardada

nombre_red = 'net_Impp_TG.mat';   % Nombre del archivo donde se guarda/carga la red

%% =========================================================
%  OBJETIVO DE ERROR PARA EL ENTRENAMIENTO
% ==========================================================
% La red se entrenará hasta alcanzar este valor de MSE,
% o hasta llegar al número máximo de épocas.

perf_objetivo = 1e-6;   % Error cuadrático medio deseado


%% =========================================================
%  LECTURA DE DATOS DESDE EXCEL
% ==========================================================

% Lee el archivo Excel
tabla = readtable('dataset_TG_Vmpp_Impp_Pmpp.xlsx','Sheet','Hoja1');

% Extrae las columnas del Excel
T = tabla.T;          % Temperatura
G = tabla.G;          % Irradiancia
Impp = tabla.Impp;   % Corriente MPP (Target)


%% =========================================================
%  NORMALIZACION DE DATOS
% ==========================================================
% La red neuronal trabaja mejor cuando los datos
% están normalizados.
%
% IMPORTANTE:
% Si se entrena una nueva red, se calculan medias y desviaciones.
% Si se carga una red previamente guardada, también se cargan las
% mismas medias y desviaciones usadas durante su entrenamiento.

if modo_red == 1

    % Media de cada variable
    Media_T = mean(T);
    Media_G = mean(G);
    Media_Impp = mean(Impp);

    % Desviación estándar de cada variable
    Std_T = std(T);
    Std_G = std(G);
    Std_Impp = std(Impp);

else

    % Cargar red previamente entrenada y parámetros de normalización
    load(nombre_red, 'net', ...
                     'Media_T', 'Media_G', 'Media_Impp', ...
                     'Std_T', 'Std_G', 'Std_Impp');

end

% Normalización tipo Z-score
Norm_T = (T - Media_T) / Std_T;
Norm_G = (G - Media_G) / Std_G;
Norm_Impp = (Impp - Media_Impp) / Std_Impp;


%% =========================================================
%  CREACION DE MATRICES DE ENTRADA Y TARGET
% ==========================================================
% MATLAB espera:
% columnas = muestras
% filas = variables

% Entradas:
% fila 1 = Temperatura
% fila 2 = Irradiancia
Datos = [Norm_T'; Norm_G'];

% Salida objetivo
Target = Norm_Impp';


%% =========================================================
%  CREACION Y ENTRENAMIENTO DE LA RED NEURONAL
% ==========================================================
% Esta sección solo se ejecuta si modo_red = 1.
% Si modo_red = 0, esta parte se omite y se usa la red cargada.

if modo_red == 1

    %% =========================================================
    %  CREACION DE LA RED NEURONAL
    % ==========================================================

    % Algoritmo de entrenamiento
    trainFcn = 'trainlm';

    % Número de neuronas ocultas
    hiddenLayerSize = 5;

    % Crear red neuronal feedforward
    net = feedforwardnet(hiddenLayerSize, trainFcn);

    % Número máximo de épocas
    net.trainParam.epochs = 30000;
    % Error objetivo de entrenamiento
    % Si la red alcanza este MSE, el entrenamiento se detiene automáticamente
    net.trainParam.goal = perf_objetivo;

    % División de datos:
    % 70% entrenamiento
    % 15% validación
    % 15% prueba
    net.divideParam.trainRatio = 70/100;
    net.divideParam.valRatio   = 15/100;
    net.divideParam.testRatio  = 15/100;

    % Desactivar procesamiento automático
    net.inputs{1}.processFcns = {};
    net.outputs{2}.processFcns = {};

    % Función de activación capa oculta
    net.layers{1}.transferFcn = 'logsig';

    % Función de activación capa salida
    net.layers{2}.transferFcn = 'purelin';
    
    %% =========================================================
    %  ENTRENAMIENTO DE LA RED
    % ==========================================================

    fprintf('\n');
    fprintf('============= CONFIGURACION DE ENTRENAMIENTO =============\n');
    fprintf('Epocas máximas = %d\n', net.trainParam.epochs);
    fprintf('MSE objetivo   = %.10e\n', perf_objetivo);

    % Entrenar red
    [net,tr] = train(net, Datos, Target);

    fprintf('\n');
    fprintf('============= RESULTADOS DEL ENTRENAMIENTO =============\n');
    fprintf('Mejor MSE alcanzado = %.10e\n', tr.best_perf);
    fprintf('Mejor época         = %d\n', tr.best_epoch);

    %% =========================================================
    %  GUARDAR RED ENTRENADA
    % ==========================================================
    % Se guarda la red junto con los parámetros de normalización.
    % Esto permite usar la misma red después sin volver a entrenar.

    save(nombre_red, 'net', ...
                     'Media_T', 'Media_G', 'Media_Impp', ...
                     'Std_T', 'Std_G', 'Std_Impp');

    fprintf('\n');
    fprintf('Red neuronal entrenada y guardada como: %s\n', nombre_red);

else

    fprintf('\n');
    fprintf('Red neuronal cargada desde: %s\n', nombre_red);

end


%% =========================================================
%  PREDICCION USANDO LOS DATOS DE ENTRENAMIENTO
% ==========================================================

% Salida predicha normalizada
Impp_pred_norm = net(Datos);

% Error cuadrático medio
fprintf('============= ERROR CUADRÁTICO MEDIO =============\n');
perf = mse(net, Target, Impp_pred_norm)

% Mostrar resultados
figure;
plot(Impp_pred_norm, 'r', 'LineWidth', 1.5);
hold on;
plot(Target, 'b', 'LineWidth', 1.5);

legend('Impp Predicho', 'Impp Real');

title('Comparación Red Neuronal');
xlabel('Muestras');
ylabel('Impp Normalizado');

grid on;


%% =========================================================
%  PREDICCION CON DATOS REALES DEL EXCEL
% ==========================================================
% Se selecciona una fila del Excel para comparar:
% Valor real vs valor predicho

indice = 10;   % Fila del Excel a evaluar


%% =========================================================
%  DATOS REALES TOMADOS DEL EXCEL
% ==========================================================

% Entradas reales
T_Aux = T(indice);
G_Aux = G(indice);

% Salida real del Excel
Impp_real = Impp(indice);

fprintf('============= DATOS DEL EXCEL =============\n');

fprintf('Fila seleccionada = %d\n', indice);

fprintf('Temperatura (T)   = %.4f\n', T_Aux);

fprintf('Irradiancia (G)   = %.4f\n', G_Aux);

fprintf('Impp REAL Excel   = %.4f A\n', Impp_real);


%% =========================================================
%  NORMALIZACION DE ENTRADAS
% ==========================================================

Norm_T_Aux = (T_Aux - Media_T) / Std_T;
Norm_G_Aux = (G_Aux - Media_G) / Std_G;

x1 = Norm_T_Aux;
x2 = Norm_G_Aux;


%% =========================================================
%  PREDICCION DE LA RED NEURONAL
% ==========================================================

% Predicción normalizada
Impp_pred_norm = net([x1; x2]);

% Desnormalización
Impp_pred = Impp_pred_norm * Std_Impp + Media_Impp;


%% =========================================================
%  CALCULO DEL ERROR
% ==========================================================

Error_abs = abs(Impp_real - Impp_pred);

Error_porcentaje = (Error_abs / Impp_real) * 100;


%% =========================================================
%  RESULTADOS
% ==========================================================

fprintf('\n');
fprintf('========== RESULTADOS DE LA RED ==========\n');

fprintf('Impp REAL      = %.4f A\n', Impp_real);

fprintf('Impp PREDICHO  = %.4f A\n', Impp_pred);

fprintf('Error absoluto = %.6f\n', Error_abs);

fprintf('Error %%        = %.4f %%\n', Error_porcentaje);


%% =========================================================
%  EXTRACCION DE PESOS Y BIASES
% ==========================================================
% Esto sirve si luego quieres implementar la red
% en FPGA, DSP, Arduino, C, VHDL, etc.

% Pesos entrada -> capa oculta
w1 = net.IW{1,1};

% Pesos capa oculta -> salida
w2 = net.LW{2,1};

% Bias capa oculta
b1 = net.b{1,1};

% Bias capa salida
b2 = net.b{2,1};

if modo_red == 1
    save('ANN_parametros.mat', ...
         'w1', 'w2', 'b1', 'b2', ...
         'Media_T', 'Media_G', 'Media_Impp', ...
         'Std_T', 'Std_G', 'Std_Impp');
end

%% =========================================================
%  ESQUEMA DEL CALCULO MANUAL DE LA RED
% ==========================================================
%
%          RED NEURONAL 2 - 5 - 1
%
%      Entradas            Capa oculta              Salida
%
%        x1  --------->  N1  \
%                        N2   \
%        x2  --------->  N3 ----->  Salida_norm
%                        N4   /
%                        N5  /
%
%
%  x1 = Temperatura normalizada
%  x2 = Irradiancia normalizada
%
%  N1 ... N5 = neuronas ocultas (logsig)
%
%  Salida_norm = salida normalizada de Impp
%
%
% ----------------------------------------------------------
% ECUACION DE CADA NEURONA OCULTA
% ----------------------------------------------------------
%
%  N1 = logsig( b1(1) + x1*w1(1,1) + x2*w1(1,2) )
%
%  N2 = logsig( b1(2) + x1*w1(2,1) + x2*w1(2,2) )
%
%  N3 = logsig( b1(3) + x1*w1(3,1) + x2*w1(3,2) )
%
%  N4 = logsig( b1(4) + x1*w1(4,1) + x2*w1(4,2) )
%
%  N5 = logsig( b1(5) + x1*w1(5,1) + x2*w1(5,2) )
%
%
% ----------------------------------------------------------
% ECUACION DE LA CAPA DE SALIDA
% ----------------------------------------------------------
%
%  Salida_norm =
%
%      b2 + ...
%      N1*w2(1,1) + ...
%      N2*w2(1,2) + ...
%      N3*w2(1,3) + ...
%      N4*w2(1,4) + ...
%      N5*w2(1,5)
%
%
% ----------------------------------------------------------
% DESNORMALIZACION
% ----------------------------------------------------------
%
%  Salida_real =
%
%      Salida_norm*Std_Impp + Media_Impp
%


%% =========================================================
%  CALCULO MANUAL DE LA RED
% ==========================================================
% Aquí se replica matemáticamente lo que hace MATLAB

% Neurona 1
N1 = b1(1) + x1*w1(1,1) + x2*w1(1,2);
N1 = 1/(1+exp(-N1));

% Neurona 2
N2 = b1(2) + x1*w1(2,1) + x2*w1(2,2);
N2 = 1/(1+exp(-N2));

% Neurona 3
N3 = b1(3) + x1*w1(3,1) + x2*w1(3,2);
N3 = 1/(1+exp(-N3));

% Neurona 4
N4 = b1(4) + x1*w1(4,1) + x2*w1(4,2);
N4 = 1/(1+exp(-N4));

% Neurona 5
N5 = b1(5) + x1*w1(5,1) + x2*w1(5,2);
N5 = 1/(1+exp(-N5));

% Capa de salida
Salida_norm = b2 + ...
               N1*w2(1,1) + ...
               N2*w2(1,2) + ...
               N3*w2(1,3) + ...
               N4*w2(1,4) + ...
               N5*w2(1,5);

% Desnormalización
Salida_real = Salida_norm * Std_Impp + Media_Impp;

fprintf('\n');
fprintf('Predicción MANUAL = %.4f A\n', Salida_real);