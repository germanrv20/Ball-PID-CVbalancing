clc;
listaCamaras = webcamlist;
fprintf('Camaras disponibles:\n\n');
for k = 1:length(listaCamaras)
    fprintf('%d -> %s\n', k, listaCamaras{k});
end
if length(listaCamaras) == 1
    indiceCamara = 1;
else
    indiceCamara = 2;
end
cam = webcam(indiceCamara);
if any(strcmp(cam.AvailableResolutions, '640x480'))
    cam.Resolution = '640x480';
end
fprintf('\nCamara seleccionada: %s | Resolucion: %s\n', listaCamaras{indiceCamara}, cam.Resolution);

%% 1. Conexión con Arduino y posición inicial
if ~exist('puerto', 'var')
    puerto = serialport("COM16", 115200);
    configureTerminator(puerto, "LF");
    pause(2);
end
moverPlataforma(0, 0, puerto);

%% 2. Parámetros del controlador LQI de dos zonas + Kalman
betaMax = 7.5;    % Límite exclusivo del controlador (±7.5°)
dt_nom  = 0.0334; % Periodo medio real Iriun 640x480 (30 FPS)

amortig = 0.35;
ku      = 150.0;

A = [0, 1;
     0, -amortig];
B = [0;
     ku];
C = [1, 0];

M  = expm([A, B; zeros(1, 3)] * dt_nom);
Ad = M(1:2, 1:2);
Bd = M(1:2, 3);

% Sistema aumentado LQI: estado = [pos; vel; integral_pos]
Ad_aug = [Ad,       zeros(2, 1);
          dt_nom, 0, 1];
Bd_aug = [Bd;
          0];

% -------------------------------------------------------------------------
% DISEÑO LQI POR ZONAS
%
% Zona cercana: d aproximadamente menor que 20 mm.
%   - Se penaliza más la velocidad para frenar la bola.
%   - Se da más peso al estado integral para corregir errores persistentes.
%   - El peso de posición se mantiene moderado.
%
% Zona alejada: d aproximadamente mayor que 20 mm.
%   - Se da más peso a la posición para recuperar el centro.
%   - Se reduce el peso de velocidad para permitir un desplazamiento mayor.
%   - Se reduce el peso del integrador.
%
% R_lqi se mantiene igual en las dos zonas para conservar la misma
% penalización del esfuerzo de control.
% -------------------------------------------------------------------------
Q_lqi_cerca = diag([0.140, 0.400, 0.0200]);
Q_lqi_lejos = diag([0.700, 0.060, 0.0010]);
R_lqi       = 360.0;
intMax      = 60.0;

% La transición se realiza alrededor de 20 mm para evitar un salto brusco
% de ganancias al cruzar exactamente el límite de zona.
dTransIni = 16.0; % Por debajo: controlador de zona cercana
dTransFin = 24.0; % Por encima: controlador de zona alejada

% Covarianza del filtro de Kalman (se mantiene igual que en tu código)
Q_kal_base = diag([0.05, 260.0]);
R_kal      = 0.35^2;

% Calcular las dos ganancias una sola vez, antes del bucle de cámara.
if exist('dlqr', 'file')
    K_cerca = dlqr(Ad_aug, Bd_aug, Q_lqi_cerca, R_lqi);
    K_lejos = dlqr(Ad_aug, Bd_aug, Q_lqi_lejos, R_lqi);
    [~, Pk0] = dlqr(Ad', C', Q_kal_base, R_kal);
else
    % Solución iterativa de la ecuación de Riccati si no está disponible dlqr.
    P = Q_lqi_cerca;
    for i = 1:600
        P = Q_lqi_cerca + Ad_aug' * P * Ad_aug - ...
            (Ad_aug' * P * Bd_aug) / ...
            (R_lqi + Bd_aug' * P * Bd_aug) * (Bd_aug' * P * Ad_aug);
    end
    K_cerca = (R_lqi + Bd_aug' * P * Bd_aug) \ (Bd_aug' * P * Ad_aug);

    P = Q_lqi_lejos;
    for i = 1:600
        P = Q_lqi_lejos + Ad_aug' * P * Ad_aug - ...
            (Ad_aug' * P * Bd_aug) / ...
            (R_lqi + Bd_aug' * P * Bd_aug) * (Bd_aug' * P * Ad_aug);
    end
    K_lejos = (R_lqi + Bd_aug' * P * Bd_aug) \ (Bd_aug' * P * Ad_aug);

    % Riccati dual para la covarianza inicial del filtro de Kalman.
    Pk0 = Q_kal_base;
    for i = 1:500
        Pk0 = Q_kal_base + Ad * Pk0 * Ad' - ...
            (Ad * Pk0 * C') / (R_kal + C * Pk0 * C') * (C * Pk0 * Ad');
    end
end

% Inicialmente se selecciona la ganancia de la zona cercana.
K = K_cerca;
alphaLQI = 0;
distanciaFiltrada = 0;
zonaLQI = 'CERCANA';

fprintf('\nGanancias LQI calculadas:\n');
fprintf('Zona cercana -> K_pos = %.5f | K_vel = %.5f | K_int = %.5f\n', ...
    K_cerca(1), K_cerca(2), K_cerca(3));
fprintf('Zona alejada -> K_pos = %.5f | K_vel = %.5f | K_int = %.5f\n', ...
    K_lejos(1), K_lejos(2), K_lejos(3));

%% 3. Inicialización de gráficos, estado y registro
img = snapshot(cam);
fig = figure('Name', 'Control LQI dos zonas + Kalman (Iriun 30 FPS)', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) setappdata(src, 'cerrar', true));
setappdata(fig, 'cerrar', false);
hImg = imshow(img); hold on;

hCentroBase = plot(NaN, NaN, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
hCircBase   = plot(NaN, NaN, 'b-', 'LineWidth', 1.2);
hCircMeta   = plot(NaN, NaN, 'g--', 'LineWidth', 1.5); % Círculo objetivo de radio 10 mm
hBola       = plot(NaN, NaN, 'r+', 'MarkerSize', 12, 'LineWidth', 2);
thetaCirc   = linspace(0, 2*pi, 100);

xEst = [0; 0];
yEst = [0; 0];
intX = 0;
intY = 0;
Pk_x = Pk0;
Pk_y = Pk0;
[errX_ant, errY_ant] = deal(NaN);
kalmanIniciado = false;
anguloAnt = 0;
betaX = 0;
betaY = 0;
dt = dt_nom;
contadorVis = 0;

registroControlPD('iniciar');
tic;
tAnt = toc;
tUltimaBola = tAnt;

%% 4. Bucle de control LQI de dos zonas + Kalman adaptativo
while isgraphics(fig) && ~getappdata(fig, 'cerrar')
    img = snapshot(cam);
    [centroBola_x, centroBola_y, centro_x, centro_y, radioBase, mmPorPixel, baseDetectada, bolaDetectada] = detectarBolas(img);
    contadorVis = contadorVis + 1;
    tAhora = toc;

    if isgraphics(fig) && mod(contadorVis, 3) == 0
        set(hImg, 'CData', img);
        if baseDetectada
            set(hCentroBase, 'XData', centro_x, 'YData', centro_y);
            set(hCircBase, 'XData', centro_x + radioBase * cos(thetaCirc), ...
                           'YData', centro_y + radioBase * sin(thetaCirc));
            if mmPorPixel > 0
                rMetaPx = 10.0 / mmPorPixel;
                set(hCircMeta, 'XData', centro_x + rMetaPx * cos(thetaCirc), ...
                               'YData', centro_y + rMetaPx * sin(thetaCirc));
            end
        else
            set(hCentroBase, 'XData', NaN, 'YData', NaN);
            set(hCircBase, 'XData', NaN, 'YData', NaN);
            set(hCircMeta, 'XData', NaN, 'YData', NaN);
        end
    end

    if ~baseDetectada || ~bolaDetectada
        if kalmanIniciado && ((tAhora - tUltimaBola) < 0.25)
            dt_blur = max(min(tAhora - tAnt, 0.10), 0.015);
            tAnt = tAhora;
            Ad_blur = [1, dt_blur; 0, exp(-amortig * dt_blur)];
            xEst = Ad_blur * xEst;
            yEst = Ad_blur * yEst;

            % Se conserva la última ganancia seleccionada mientras la bola
            % está temporalmente oculta.
            betaX = max(min(K(1) * xEst(1) + K(2) * xEst(2) + K(3) * intX, betaMax), -betaMax);
            betaY = max(min(K(1) * yEst(1) + K(2) * yEst(2) + K(3) * intY, betaMax), -betaMax);
            moverPlataforma(betaX, betaY, puerto);
        else
            moverPlataforma(0, 0, puerto);
            kalmanIniciado = false;
            [errX_ant, errY_ant] = deal(NaN);
            intX = 0;
            intY = 0;
            Pk_x = Pk0;
            Pk_y = Pk0;
            betaX = 0;
            betaY = 0;
            K = K_cerca;
            alphaLQI = 0;
            distanciaFiltrada = 0;
            zonaLQI = 'CERCANA';
            tAnt = tAhora;
        end
        if isgraphics(fig) && mod(contadorVis, 3) == 0
            set(hBola, 'XData', NaN, 'YData', NaN);
            title('Esperando detección de base y bola...');
            drawnow limitrate;
        end
        continue;
    end

    tUltimaBola = tAhora;

    angulo = calcularAnguloBase(img, centro_x, centro_y, radioBase);
    angulo = 0;
    if isnan(angulo)
        angulo = anguloAnt;
    else
        anguloAnt = angulo;
    end

    x = (centroBola_x - centro_x) * mmPorPixel;
    y = (centro_y - centroBola_y) * mmPorPixel;

    errX = x;
    errY = y;
    [errX_girado, errY_girado] = rotarError(errX, errY, angulo);

    esFrameNuevo = isnan(errX_ant) || (abs(errX_girado - errX_ant) > 1e-6) || ...
                   (abs(errY_girado - errY_ant) > 1e-6) || ((tAhora - tAnt) >= 0.050);

    if esFrameNuevo
        dt = max(min(tAhora - tAnt, 0.15), 0.015);
        tAnt = tAhora;

        Ad_real = [1, dt;
                   0, exp(-amortig * dt)];
        Qk_real = Q_kal_base * (dt / dt_nom);

        if ~kalmanIniciado
            xEst = [errX_girado; 0];
            yEst = [errY_girado; 0];
            intX = 0;
            intY = 0;
            Pk_x = Pk0;
            Pk_y = Pk0;
            kalmanIniciado = true;
        else
            xPred   = Ad_real * xEst;
            Pk_x    = Ad_real * Pk_x * Ad_real' + Qk_real;
            K_kal_x = (Pk_x * C') / (C * Pk_x * C' + R_kal);
            xEst    = xPred + K_kal_x * (errX_girado - C * xPred);
            Pk_x    = (eye(2) - K_kal_x * C) * Pk_x;

            yPred   = Ad_real * yEst;
            Pk_y    = Ad_real * Pk_y * Ad_real' + Qk_real;
            K_kal_y = (Pk_y * C') / (C * Pk_y * C' + R_kal);
            yEst    = yPred + K_kal_y * (errY_girado - C * yPred);
            Pk_y    = (eye(2) - K_kal_y * C) * Pk_y;
        end

        errX_ant = errX_girado;
        errY_ant = errY_girado;

        % Selección/interpolación de la ganancia según la distancia radial
        % estimada al centro del plato. Se emplea la posición filtrada.
        distanciaFiltrada = hypot(xEst(1), yEst(1));
        alphaLQI = (distanciaFiltrada - dTransIni) / (dTransFin - dTransIni);
        alphaLQI = min(max(alphaLQI, 0), 1);
        K = (1 - alphaLQI) * K_cerca + alphaLQI * K_lejos;

        if alphaLQI <= 0
            zonaLQI = 'CERCANA';
        elseif alphaLQI >= 1
            zonaLQI = 'ALEJADA';
        else
            zonaLQI = 'TRANSICION';
        end

        % Integrador condicional con anti-windup para absorber inclinación
        % residual del plato. Se conserva la lógica original.
       pesoIntegral = 1 - alphaLQI;

        if abs(xEst(1)) < 35.0 && abs(xEst(2)) < 75.0
            intX = max(min(intX + pesoIntegral * xEst(1) * dt, ...
                           intMax), -intMax);
        end
        
        if abs(yEst(1)) < 35.0 && abs(yEst(2)) < 75.0
            intY = max(min(intY + pesoIntegral * yEst(1) * dt, ...
                           intMax), -intMax);
        end

        % Ley LQI con ganancia programada según la zona y saturación ±7.5°.
        betaX = max(min(K(1) * xEst(1) + K(2) * xEst(2) + K(3) * intX, betaMax), -betaMax);
        betaY = max(min(K(1) * yEst(1) + K(2) * yEst(2) + K(3) * intY, betaMax), -betaMax);

        registroControlPD('guardar', [tAhora, x, y, hypot(errX_girado, errY_girado), xEst(2), yEst(2), betaX, betaY]);
        moverPlataforma(betaX, betaY, puerto);
    end

    if isgraphics(fig) && mod(contadorVis, 3) == 0
        set(hBola, 'XData', centroBola_x, 'YData', centroBola_y);
        title(sprintf(['dt: %.0f ms | Pos X: %+.1f mm | Pos Y: %+.1f mm | ' ...
                       'd: %.1f mm | Zona: %s | Beta: (%+.1f°, %+.1f°)'], ...
              dt*1000, x, y, distanciaFiltrada, zonaLQI, betaX, betaY));
        drawnow limitrate;
    end
end

%% 5. Posición segura, exportación del CSV y cierre limpio
moverPlataforma(0, 0, puerto);
archivoCSV = registroControlPD('finalizar');
if ~isempty(archivoCSV)
    fprintf('CSV guardado en: %s\n', archivoCSV);
end
if isgraphics(fig)
    delete(fig);
end
