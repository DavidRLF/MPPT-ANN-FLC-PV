# MPPT-ANN-FLC-PV

Algoritmo MPPT basado en una red neuronal artificial (ANN) y controladores de lógica difusa Mamdani para un sistema fotovoltaico conectado a la red.

Este repositorio contiene los archivos utilizados para generar la base de datos fotovoltaica, entrenar la red neuronal para estimar la corriente de referencia `Impp`, evaluar el error relativo de la ANN, simular el sistema PV y comparar el desempeño de controladores difusos Mamdani convencional, simplificado y propuesto.

## Descripción general

El método MPPT emplea una red neuronal multicapa con arquitectura 2-5-1 para estimar la corriente de referencia en el punto de máxima potencia a partir de la temperatura y la irradiancia. Posteriormente, el seguimiento de dicha referencia se realiza mediante controladores de lógica difusa Mamdani.

Se consideran tres esquemas principales:

- Controlador Mamdani convencional de 49 reglas.
- Controlador Mamdani simplificado de 5 reglas.
- Controlador Mamdani propuesto de 5 reglas con compensación dinámica mediante la variación del error.

## Archivos incluidos

| Archivo | Descripción |
|---|---|
| `M_Gen_Base_Datos_PVNREL_V1.m` | Genera la base de datos del arreglo fotovoltaico usando el modelo PV tipo NREL y obtiene variables como `Vmpp`, `Impp` y `Pmpp`. |
| `M_Dis_Net_Impp_V1.m` | Entrena la red neuronal ANN para estimar `Impp` a partir de temperatura e irradiancia. También permite guardar la red entrenada y exportar parámetros. |
| `Error_Relativo_V1.m` | Evalúa el error relativo entre la salida de la ANN y el modelo fotovoltaico completo. |
| `M_Mod_Sim_PV_V1.m` | Define parámetros del sistema PV, convertidor DC-DC, inversor, red eléctrica y controladores para la simulación. |
| `M_Comp_Sup_Control_FLCs_V1.m` | Compara superficies de control de los sistemas difusos Mamdani considerados. |
| `S_Mod_Sim_PV_V1.slx` | Modelo principal de simulación del sistema fotovoltaico conectado a la red. |
| `S_Med_TE_MPPT_Conv_V1.slx` | Modelo para medir el tiempo de ejecución del MPPT con FLC convencional de 49 reglas. |
| `S_Med_TE_MPPT_Simp_V1.slx` | Modelo para medir el tiempo de ejecución del MPPT con FLC simplificado de 5 reglas. |
| `S_Med_TE_MPPT_Prop_V1.slx` | Modelo para medir el tiempo de ejecución del MPPT propuesto con FLC de 5 reglas y compensación dinámica. |
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
6. Usar los modelos `S_Med_TE_MPPT_Conv_V1.slx`, `S_Med_TE_MPPT_Simp_V1.slx` y `S_Med_TE_MPPT_Prop_V1.slx` para medir tiempos de ejecución.
7. Usar `M_Comp_Sup_Control_FLCs_V1.m` para comparar las superficies de control de los FLC.

## Requisitos

- MATLAB
- Simulink
- Fuzzy Logic Toolbox
- Deep Learning Toolbox
- Control System Toolbox

## Nota

Los nombres de los archivos se mantienen tal como fueron utilizados durante el desarrollo del proyecto para conservar compatibilidad con los scripts y modelos de Simulink.

