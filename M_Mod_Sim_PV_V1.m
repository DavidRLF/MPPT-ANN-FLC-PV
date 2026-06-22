clc; clear all; close all;

%% Arreglo fotovoltaico: Canadian Solar CS6X-280P
No_Cadenas_Paralelo = 2;     % Número de cadenas en paralelo
No_Modulos_PorCadena = 18;   % Módulos por cadena (conexión en serie)
Irr_in = 0;                  % Entrada de irradiancia (variable auxiliar)

%% Convertidor DC-DC elevador (selección de componentes y punto de operación)
% T = 25 °C, Pmp = 10.07 kW, Vmp = 640.8 V
vpv  = 640.8;         % Voltaje de entrada del arreglo fotovoltaico
vdc  = 1000;          % Voltaje deseado del bus de continua
Fs   = 5e3;           % Frecuencia de conmutación
Ppv  = 10.07e3;       % Potencia de entrada
ipv  = Ppv/vpv;       % Corriente de entrada
iL   = ipv;           % Corriente nominal del inductor
d    = (vdc-vpv)/vdc; % Ciclo de trabajo

Rdc   = vpv/ipv;              % Resistencia equivalente en el punto MPPT
Idc   = ipv*(1-d);            % Corriente de salida
Rload = vdc/Idc;              % Resistencia equivalente de carga

Lmin  = (d*(1-d)^2*Rload)/(2*Fs); % Inductancia mínima para conducción continua
L     = 68.2729*Lmin;             % Inductancia seleccionada

ILmax = vpv/((1-d)^2*Rload) + (vpv*d)/(2*L*Fs); % Corriente máxima del inductor
ILmin = vpv/((1-d)^2*Rload) - (vpv*d)/(2*L*Fs); % Corriente mínima del inductor

Cdc   = 470e-6;                   % Capacitor de salida
dVdc  = (d*vdc)/(Rload*Cdc*Fs);   % Estimación del rizado de voltaje de salida (~1 V)

Cin   = 1e-6;                     % Capacitor de entrada (100 uF maximiza la eficiencia)

b     = 16;                       % Resolución del modulador DPWM (bits)
Kf1   = (2^b-1);
Kdpwm = 1/Kf1;                    % Ganancia del DPWM

ki    = 1/ipv;                    % Ganancia del sensor de corriente

% Modelo continuo de pequeña señal (estados X = [iL; vdc], entrada U = d)
% Se asume Cin << Cdc y un bus de continua variable.
A = [0 (d-1)/L;
     (1-d)/Cdc -1/(Rload*Cdc)];   % Matriz de estados

B = [vdc/L;
     -iL/Cdc];                    % Matriz de entrada

B = B*Kdpwm;                      % Inclusión de la ganancia del DPWM

C = [1 0];                        % Salida: corriente del inductor
D = [0];                          % Término directo

X = {'iL' 'vdc'};                 % x1 = iL, x2 = vdc
U = {'d'};                        % Entrada: ciclo de trabajo
Y = {'iL'};                       % Salida: corriente del inductor

sys_cont = ss(A,B,C,D,'statename',X,'inputname',U,'outputname',Y);

tf(sys_cont);
GsiLd = ans(1,1);                 % Función de transferencia iL(s)/d(s)

Ts1 = 1/Fs;                       % Periodo de muestreo

GziLd = c2d(GsiLd,Ts1,'ZOH');     % Planta discreta con retenedor de orden cero

figure(1)
step(((1-d)*Kf1)/2*GsiLd);        % Respuesta en lazo abierto (modelo continuo)
hold on;
step(((1-d)*Kf1)/2*GziLd);        % Respuesta en lazo abierto (modelo discreto)
hold off;

%% Inversor DC-AC (valores base de diseño)
Fc  = 5e3;              % Frecuencia de la portadora triangular (Hz)
fs  = 60;               % Frecuencia de la red (Hz)
ws  = 2*pi*fs;          % Frecuencia angular de la red (rad/s)

vdc = 1000;             % Voltaje nominal del bus DC (V)

S   = 10e3*3/2;         % Potencia aparente base (VA)

VL  = (381.051/2);      % Voltaje línea-línea base (Vrms)
Vf  = VL/sqrt(3);       % Voltaje fase-neutro base (Vrms)

vdc_ref = vdc;          % Referencia del bus DC (V)

Lbase = vdc^2/(ws*S);   % Inductancia base (H)

% Selección final de la inductancia (criterio: THD < 10 %)
L_pu = 0.3;
Linv = L_pu*Lbase;
Linv = 0.035;

Rinv = (Linv*377/fs/2); % Estimación de la resistencia interna
Rinv = 0.0417;

Cinv = 470e-6;          % Capacitor de entrada del inversor

Ts4 = 1/(4*Fc);         % Periodo de muestreo del controlador
Td  = Ts4/2;            % Retardo de actualización del PWM

Ts_inv = 1/(100*Fc);    % Muestreo de bloques auxiliares

Vp = 1;                 % Voltaje pico de la portadora PWM

%% Controlador PI digital (corrientes dq) despreciando el retardo del PWM

% Lazo de corriente (ejes d-q)
Porcentaje1 = 1;
Mp1 = Porcentaje1/100;

Zeta1 = sqrt(log(Mp1)^2/(log(Mp1)^2+pi^2));

tset1 = 10e-3;

Porcentaje = 2;
E1 = Porcentaje/100;

wn1 = -log(E1)/(Zeta1*tset1);

Kp2 = 2*Linv*Vp*Zeta1*wn1 - Rinv*Vp;
Ki2 = Linv*Vp*wn1^2;

% Lazo de voltaje sin filtro en id
Porcentaje = 1;
Mp2 = Porcentaje/100;

Zeta2 = sqrt(log(Mp2)^2/(log(Mp2)^2+pi^2));

n = 0.6;
tset2 = tset1*n;

Porcentaje = 4;
E2 = Porcentaje/100;

wn2 = -log(E2)/(Zeta2*tset2);

Kp4 = 2*Cinv*Zeta2*wn2;
Ki4 = Cinv*wn2^2;

% Controlador PLL
Zeta3 = 0.707;
wn3 = (120*pi)/2;

Kp5 = 2*Zeta3*wn3;
Ki5 = wn3^2;

% Conversión de ganancias continuas a discretas
KI2 = Ki2*Ts4;
KP2 = Kp2 - KI2/2;

KI4 = Ki4*Ts4;
KP4 = Kp4 - KI4/2;

KI5 = Ki5*Ts_inv;
KP5 = Kp5*Ts_inv - KI5/2;

%% Transformador (~50 kVA equivalente a un edificio pequeño)
Ptrafo  = 100e3;        % Potencia nominal
Ftrafo  = fs;           % Frecuencia de operación

VLLsec  = 33000;        % Voltaje línea-línea del lado de red (Vrms)
VLLprim = VL;           % Voltaje línea-línea del lado del inversor (Vrms)

%% Red eléctrica (parámetros básicos)
VLngrid = 33000/sqrt(3); % Voltaje fase-neutro (Vrms)
Fred    = fs;            % Frecuencia de la red (Hz)

In       = 1e6/(1.73*Vf); % Corriente nominal de referencia
Icc_calc = In/(5/100);    % Estimación de corriente de cortocircuito (5 %)

%% Parámetros del sistema difuso Mamdani
Ts2 = Ts1;
Ts_Ma=10e-3;
Scala = 0.03;            % Factor de escalamiento de dD
dDmax = 0.0051;          % Valor máximo de salida de dD

Kf1 = Scala/dDmax;

Ts3 = Ts1;

%% Método MPPT

% Factor de ajuste
dIL = (vpv/L)*d*Ts1;

%% ======================
% Configuración de figuras
% ======================

% Apariencia global de las figuras (solo fuentes)
set(groot,'defaultAxesFontName','Times New Roman');
set(groot,'defaultTextFontName','Times New Roman');

set(groot,'defaultAxesFontSize',12);
set(groot,'defaultTextFontSize',12);

% --- Figura 1: Respuesta en lazo abierto (continua vs discreta)
figure(1);

grid on;
box on;

title('Fig. 1. Respuesta en lazo abierto (continua y discreta): i_{in} en función del ciclo de trabajo d. Nota: i_L = i_{in}','FontWeight','normal');

xlabel('Tiempo (s)');
ylabel('Corriente de entrada i_{in} (A)');

legend('FT continua (dominio s)', ...
       'FT discreta (dominio z)', ...
       'Location','southeast');