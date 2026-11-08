%% =========================================================
%% GRAFICAS DE LOS REGISTROS DEL CONTROL PD
%% UNA GRAFICA POR PESTAÑA
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


% Modulo de la velocidad
velocidad = sqrt(vx.^2 + vy.^2);


%% =========================================================
%% 4. POSICION X E Y
%% =========================================================

figure( ...
    'Name','Posicion X-Y', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');

plot(t,x,'LineWidth',1.2);
hold on;

plot(t,y,'LineWidth',1.2);

yline(0,'--');

grid on;

xlabel('Tiempo [s]');
ylabel('Posicion [mm]');

title('Posicion de la bola');

legend( ...
    'X', ...
    'Y', ...
    'Centro', ...
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
%% 6. VELOCIDAD X E Y
%% =========================================================

figure( ...
    'Name','Velocidad X-Y', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');

plot(t,vx,'LineWidth',1.2);
hold on;

plot(t,vy,'LineWidth',1.2);

yline(0,'--');

grid on;

xlabel('Tiempo [s]');
ylabel('Velocidad [mm/s]');

title('Velocidad de la bola');

legend( ...
    'Vx', ...
    'Vy', ...
    'Location','best');


%% =========================================================
%% 7. ACCION DEL CONTROLADOR
%% =========================================================

figure( ...
    'Name','Accion de control', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');

plot(t,betaX,'LineWidth',1.2);
hold on;

plot(t,betaY,'LineWidth',1.2);

yline(0,'--');

grid on;

xlabel('Tiempo [s]');
ylabel('\beta [grados]');

title('Accion del controlador');

legend( ...
    '\beta_X', ...
    '\beta_Y', ...
    'Location','best');


%% =========================================================
%% 8. TRAYECTORIA X-Y
%% =========================================================

figure( ...
    'Name','Trayectoria X-Y', ...
    'NumberTitle','off', ...
    'WindowStyle','docked');

plot(x,y,'LineWidth',1.2);
hold on;


% Centro
plot( ...
    0, ...
    0, ...
    'k+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


% Inicio
plot( ...
    x(1), ...
    y(1), ...
    'o', ...
    'MarkerSize',8, ...
    'LineWidth',1.5);


% Final
plot( ...
    x(end), ...
    y(end), ...
    's', ...
    'MarkerSize',8, ...
    'LineWidth',1.5);


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
%% 9. VELOCIDAD TOTAL
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