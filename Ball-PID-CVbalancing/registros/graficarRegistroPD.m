%% =========================================================
%% GRAFICAS DE LOS REGISTROS DEL CONTROL PD
%% VARIABLES X E Y UNIFICADAS EN UN MISMO GRAFICO
%% =========================================================
clear;
clc;
close all;

%% =========================================================
%% 1. SELECCIONAR CSV
%% =========================================================
carpetaRegistros = 'registros';
[archivo,ruta] = uigetfile( ...
    fullfile(carpetaRegistros,'*.csv'), ...
    'Selecciona un registro del control PD');
if isequal(archivo,0)
    disp('No se ha seleccionado ningun archivo.');
    return;
end
nombreCompleto = fullfile(ruta,archivo);

%% =========================================================
%% 2. LEER DATOS
%% =========================================================
datos = readtable(nombreCompleto);

%% =========================================================
%% 3. EXTRAER VARIABLES
%% =========================================================
% Tiempo empezando en cero
t = datos.Tiempo_s - datos.Tiempo_s(1);
x = datos.X_mm;
y = datos.Y_mm;
distancia = datos.DistanciaCentro_mm;
vx = datos.Vx_mm_s;
vy = datos.Vy_mm_s;
betaX = datos.BetaX_deg;
betaY = datos.BetaY_deg;
propX = x * 0.06;
propY = y * 0.06;
dervX = vx * 0.05;
dervY = vy * 0.05;


% Modulo de la velocidad
velocidad = sqrt(vx.^2 + vy.^2);

%% =========================================================
%% 4. TODAS LAS VARIABLES X E Y EN EL MISMO GRAFICO
%% =========================================================
figure( ...
    'Name','Variables X', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');
hold on;

% Posicion [mm] - Linea continua
subplot(2,1,1);
plot(t, x, 'b-', 'LineWidth', 1.3);

% Velocidad [mm/s] - Linea discontinua

plot(t, vx, 'b--', 'LineWidth', 1.2);
hold off;

% Accion del controlador [deg] - Linea punteada
subplot(2,1,2);
hold on;
plot(t, betaX, 'b:', 'LineWidth', 1.5);
plot(t, propX, 'r');
plot(t, dervX, 'g');
hold off;

yline(0, '--k', 'HandleVisibility', 'off');
grid on;
xlabel('Tiempo [s]');
ylabel('Magnitud (mm | mm/s | grados)');
title('Posicion, Velocidad y Accion de Control (Ejes X e Y)');
legend( ...
    'X [mm]', ...
    'Vx [mm/s]', ...
    '\beta_X [grados]', ...
    'Location','best');

%% PLOT Y
figure( ...
    'Name','Variables Y', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');
hold on;

% Posicion [mm] - Linea continua
plot(t, y, 'r-', 'LineWidth', 1.3);

% Velocidad [mm/s] - Linea discontinua
plot(t, vy, 'r--', 'LineWidth', 1.2);

% Accion del controlador [deg] - Linea punteada
plot(t, betaY, 'r:', 'LineWidth', 1.5);

yline(0, '--k', 'HandleVisibility', 'off');
grid on;
xlabel('Tiempo [s]');
ylabel('Magnitud (mm | mm/s | grados)');
title('Posicion, Velocidad y Accion de Control (Eje Y)');
legend( ...
    'Y [mm]', ...
    'Vy [mm/s]', ...
    '\beta_Y [grados]', ...
    'Location','best');

%% =========================================================
%% 5. DISTANCIA AL CENTRO
%% =========================================================
figure( ...
    'Name','Distancia al centro', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');
plot(t,distancia,'LineWidth',1.2);
grid on;
xlabel('Tiempo [s]');
ylabel('Distancia [mm]');
title('Distancia al centro');

%% =========================================================
%% 6. TRAYECTORIA X-Y
%% =========================================================
figure( ...
    'Name','Trayectoria X-Y', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');
plot(x,y,'LineWidth',1.2);
hold on;
% Centro
plot(0, 0, 'k+', 'MarkerSize',15, 'LineWidth',2);
% Inicio
plot(x(1), y(1), 'o', 'MarkerSize',8, 'LineWidth',1.5);
% Final
plot(x(end), y(end), 's', 'MarkerSize',8, 'LineWidth',1.5);
grid on;
axis equal;
xlabel('X [mm]');
ylabel('Y [mm]');
title('Trayectoria de la bola');
legend( ...
    'Trayectoria', ...
    'Centro', ...
    'Inicio', ...
    'Final', ...
    'Location','best');

%% =========================================================
%% 7. VELOCIDAD TOTAL
%% =========================================================
figure( ...
    'Name','Velocidad total', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');
plot(t,velocidad,'LineWidth',1.2);
grid on;
xlabel('Tiempo [s]');
ylabel('Velocidad [mm/s]');
title('Modulo de la velocidad');