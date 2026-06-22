# MPPT-ANN-FLC-PV

Algoritmo MPPT basado en una red neuronal artificial (ANN) y controladores de lógica difusa Mamdani para un sistema fotovoltaico conectado a la red.

Este repositorio contiene los archivos utilizados para generar la base de datos fotovoltaica, entrenar una red neuronal para estimar la corriente de referencia Impp, evaluar su error relativo, simular el sistema fotovoltaico conectado a la red y comparar el desempeño de los controladores difusos Mamdani convencional, simplificado y propuesto. La Figura 1 muestra la arquitectura general del algoritmo MPPT y la interacción entre sus principales componentes.

<p align="center">
  <img src="https://github.com/user-attachments/assets/44bf5d61-7485-4f95-9832-27c5e1df0518"
       alt="Arquitectura general del algoritmo MPPT basado en ANN y FLC"
       width="900">
</p>

<p align="center">
  <em><strong>Figura 1.</strong> Arquitectura general del sistema fotovoltaico conectado a la red y del algoritmo MPPT basado en una red neuronal artificial y controladores difusos Mamdani.</em>
</p>

## Descripción general

El método MPPT emplea una red neuronal multicapa con arquitectura 2-5-1 para estimar la corriente de referencia en el punto de máxima potencia a partir de la temperatura y la irradiancia. Posteriormente, el seguimiento de dicha referencia se realiza mediante controladores de lógica difusa Mamdani.

Se consideran tres esquemas principales:

- Controlador Mamdani convencional de 49 reglas.
- Controlador Mamdani simplificado de 5 reglas.
- Controlador Mamdani propuesto de 5 reglas con compensación dinámica mediante la variación del error.

## Evaluación experimental del tiempo de ejecución

Con el fin de analizar la viabilidad de implementación del algoritmo MPPT en plataformas embebidas, el tiempo de ejecución (TE) de los controladores difusos Mamdani convencional, simplificado y propuesto fue evaluado experimentalmente sobre la tarjeta de desarrollo Texas Instruments TMS320F28069M.

La evaluación se realizó mediante dos metodologías complementarias:

- Priorización de bloques (BP): el TE se determinó midiendo con un osciloscopio el intervalo durante el cual un pin GPIO permaneció en nivel lógico alto.
- Perfilado de ejecución de código (CEP): el TE se obtuvo utilizando las herramientas de perfilado integradas en el entorno de desarrollo.

La Figura 2 muestra el esquema de implementación del algoritmo MPPT en la tarjeta TMS320F28069M para la adquisición de variables, el procesamiento del algoritmo y la generación de la señal PWM utilizada durante la evaluación del TE.

<p align="center">
  <img src="https://github.com/user-attachments/assets/d0dfd79d-05e0-4c2b-b595-44a2faef7b5c"
       alt="Implementación del algoritmo MPPT en la tarjeta TMS320F28069M"
       width="650">
</p>

<p align="center">
  <em><strong>Figura 2.</strong> Esquema de implementación del algoritmo MPPT en la tarjeta Texas Instruments TMS320F28069M para la adquisición de variables, el procesamiento del algoritmo y la evaluación experimental del tiempo de ejecución (TE).</em>
</p>

## Archivos incluidos

| Archivo | Descripción |
|---|---|
| `M_Gen_Base_Datos_PVNREL_V1.m` | Genera la base de datos del arreglo fotovoltaico usando el modelo PV tipo NREL y obtiene variables como `Vmpp`, `Impp` y `Pmpp`. |
| `M_Dis_Net_Impp_V1.m` | Entrena la red neuronal ANN para estimar `Impp` a partir de temperatura e irradiancia. También permite guardar la red entrenada y exportar parámetros. |
| `Error_Relativo_V1.m` | Evalúa el error relativo entre la salida de la ANN y el modelo fotovoltaico completo. |
| `M_Mod_Sim_PV_V1.m` | Define parámetros del sistema PV, convertidor DC-DC, inversor, red eléctrica y controladores para la simulación. |
| `M_Comp_Sup_Control_FLCs_V1.m` | Compara superficies de control de los sistemas difusos Mamdani considerados. |
| `S_Mod_Sim_PV_V1.slx` | Modelo principal de simulación del sistema fotovoltaico conectado a la red. |
| `S_Med_TE_MPPT_Conv_V1.slx` | Modelo para evaluar experimentalmente el tiempo de ejecución del algoritmo MPPT basado en un FLC Mamdani convencional de 49 reglas sobre la tarjeta TMS320F28069M. |
| `S_Med_TE_MPPT_Simp_V1.slx` | Modelo para evaluar experimentalmente el tiempo de ejecución del algoritmo MPPT basado en un FLC Mamdani simplificado de 5 reglas sobre la tarjeta TMS320F28069M. |
| `S_Med_TE_MPPT_Prop_V1.slx` | Modelo para evaluar experimentalmente el tiempo de ejecución del algoritmo MPPT propuesto, basado en un FLC Mamdani de 5 reglas con compensación dinámica, sobre la tarjeta TMS320F28069M. |
| `49_Rules_MaMPPTCtrlPaperShaikRAfi_V2.fis` | Sistema difuso Mamdani convencional de 49 reglas usado como referencia. |
| `5_Rules_MaMPPTCtrl_V1.fis` | Sistema difuso Mamdani reducido de 5 reglas. |
| `dataset_TG_Vmpp_Impp_Pmpp.xlsx` | Base de datos con temperatura, irradiancia y valores de `Vmpp`, `Impp` y `Pmpp`. |
| `dataset_error_ANN_vs_full_model.xlsx` | Datos utilizados para analizar el error de la ANN frente al modelo fotovoltaico completo. |
| `net_Impp_TG.mat` | Red neuronal entrenada para estimar `Impp`. |
| `ANN_parametros.mat` | Pesos, bias y parámetros de normalización exportados para implementación en Simulink/MATLAB Coder. |

## Flujo de uso sugerido

1. Ejecutar `M_Gen_Base_Datos_PVNREL_V1.m` para generar o revisar la base de datos PV.
2. Ejecutar `M_Dis_Net_Impp_V1.m` para entrenar o cargar la red neuronal ANN.
3. Usar `Error_Relativo_V1.m` para evaluar el error relativo de la ANN.
4. Ejecutar `M_Mod_Sim_PV_V1.m` antes de abrir los modelos de Simulink.
5. Simular `S_Mod_Sim_PV_V1.slx` para evaluar el sistema PV completo.
6. Utilizar los modelos `S_Med_TE_MPPT_Conv_V1.slx`, `S_Med_TE_MPPT_Simp_V1.slx` y `S_Med_TE_MPPT_Prop_V1.slx` para evaluar experimentalmente el tiempo de ejecución de los algoritmos MPPT en la tarjeta TMS320F28069M.
7. Usar `M_Comp_Sup_Control_FLCs_V1.m` para comparar las superficies de control de los FLC.

## Requisitos

- MATLAB
- Simulink
- Fuzzy Logic Toolbox
- Deep Learning Toolbox
- Control System Toolbox

## Nota

Los nombres de los archivos se mantienen tal como fueron utilizados durante el desarrollo del proyecto para conservar compatibilidad con los scripts y modelos de Simulink.

