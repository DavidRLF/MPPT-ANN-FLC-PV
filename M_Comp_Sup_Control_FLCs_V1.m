clc;
clear;
close all;

%% Configuración general

fontSize  = 32;
lineWidth = 1.5;

% Ángulo de visualización para que
% e[k] = -1 y ?e[k] = -1 queden al frente

viewAz = -45;
viewEl = 30;

%% Cargar sistemas difusos

fis49 = readfis('49_Rules_MaMPPTCtrlPaperShaikRAfi_V2.fis');
fis5  = readfis('5_Rules_MaMPPTCtrl_V1.fis');

%% Malla de evaluación
% Se reduce el número de puntos para visualizar la cuadrícula

e_range  = linspace(-1,1,31);
de_range = linspace(-1,1,31);

[E, DE] = meshgrid(e_range, de_range);

Z49 = zeros(size(E));
Z5  = zeros(size(E));

%% Evaluación de los FLC

for i = 1:numel(E)

    input_point = [E(i), DE(i)];

    Z49(i) = evalfis(input_point, fis49);
    Z5(i)  = evalfis(input_point, fis5);

end

%% Límites comunes para comparación

zmin = min([Z49(:); Z5(:)]);
zmax = max([Z49(:); Z5(:)]);

%% Propiedades visuales

edgeColor = [0 0 0];
edgeWidth = 0.5;

%% ==========================================================
%% Figura (a): FLC Mamdani convencional de 49 reglas
%% ==========================================================

figure('Color','w','Position',[100 100 1200 900]);

surf(E, DE, Z49, ...
    'EdgeColor', edgeColor, ...
    'LineWidth', edgeWidth, ...
    'FaceColor', 'interp');

colormap('parula')

grid on
box on

view(viewAz, viewEl)

set(gca,'XDir','normal')
set(gca,'YDir','normal')

xlabel('$e[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

ylabel('$\Delta e[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

zlabel('$\Delta d_{fuzzy}[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

title('(a)', ...
    'FontSize',fontSize, ...
    'FontWeight','normal');

xlim([-1 1]);
ylim([-1 1]);
zlim([zmin zmax]);

xticks([-1 -0.5 0 0.5 1]);
yticks([-1 -0.5 0 0.5 1]);

set(gca,...
    'FontSize',fontSize,...
    'LineWidth',lineWidth);

cb = colorbar;

ylabel(cb,'$\Delta d_{fuzzy}[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

cb.FontSize = fontSize;

%% Guardar figura

set(gcf,'PaperPositionMode','auto');
print(gcf,'Fig6a_49Rules','-dpng','-r600');

%% ==========================================================
%% Figura (b): FLC reducido de 5 reglas
%% ==========================================================

figure('Color','w','Position',[100 100 1200 900]);

surf(E, DE, Z5, ...
    'EdgeColor', edgeColor, ...
    'LineWidth', edgeWidth, ...
    'FaceColor', 'interp');

colormap('parula')

grid on
box on

view(viewAz, viewEl)

set(gca,'XDir','normal')
set(gca,'YDir','normal')

xlabel('$e[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

ylabel('$\Delta e[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

zlabel('$\Delta d_{fuzzy}[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

title('(b)', ...
    'FontSize',fontSize, ...
    'FontWeight','normal');

xlim([-1 1]);
ylim([-1 1]);
zlim([zmin zmax]);

xticks([-1 -0.5 0 0.5 1]);
yticks([-1 -0.5 0 0.5 1]);

set(gca,...
    'FontSize',fontSize,...
    'LineWidth',lineWidth);

cb = colorbar;

ylabel(cb,'$\Delta d_{fuzzy}[k]$', ...
    'Interpreter','latex', ...
    'FontSize',fontSize);

cb.FontSize = fontSize;

%% Guardar figura

set(gcf,'PaperPositionMode','auto');
print(gcf,'Fig6b_5Rules','-dpng','-r600');