clc;
listaCamaras = webcamlist;
fprintf('Camaras disponibles:\n\n');
for k = 1:length(listaCamaras)
    fprintf('%d -> %s\n', k, listaCamaras{k});
end
if length(listaCamaras) == 1
    indiceCamara = 1;
else
    indiceCamara = input('\nSelecciona numero de camara (Iriun Webcam): ');
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

%% 2. Parámetros del controlador LQI (LQR + Integral) + Filtro de Kalman Adaptativo
betaMax = 7.5;    % Límite exclusivo del controlador (±7.5° antes de aplicarReposo)
dt_nom  = 0.0334; % Periodo medio real medido con Iriun 640x480 (30.0 FPS)

% Modelo físico identificado sobre el CSV de Iriun Webcam
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

% Ponderaciones LQI calibradas (elimina sesgo de nivelación y extingue órbita de ±10 mm)
Q_lqi = diag([0.020, 0.100, 0.008]); % -> K_pos = 0.0229, K_vel = 0.0274, K_int = 0.0068
R_lqi = 150.0;
intMax = 110.0; % Límite anti-windup (110 mm*s * 0.0068 = ±0.75° máx de corrección de nivel)

% Covarianzas base del Filtro de Kalman
Q_kal_base = diag([0.05, 80.0]);
R_kal      = 0.35^2;

if exist('dlqr', 'file')
    K = dlqr(Ad_aug, Bd_aug, Q_lqi, R_lqi);
    [~, Pk0] = dlqr(Ad', C', Q_kal_base, R_kal);
else
    P = Q_lqi;
    for i = 1:600
        P = Q_lqi + Ad_aug'*P*Ad_aug - (Ad_aug'*P*Bd_aug)/(R_lqi + Bd_aug'*P*Bd_aug)*(Bd_aug'*P*Ad_aug);
    end
    K = (R_lqi + Bd_aug'*P*Bd_aug) \ (Bd_aug'*P*Ad_aug);
    
    Pk0 = Q_kal_base;
    for i = 1:500
        Pk0 = Q_kal_base + Ad*Pk0*Ad' - (Ad*Pk0*C')/(R_kal + C*Pk0*C')*(C*Pk0*Ad');
    end
end
fprintf('Ganancias LQI activas -> K_pos = %.4f | K_vel = %.4f | K_int = %.4f\n', K(1), K(2), K(3));

%% 3. Inicialización de gráficos, estado y registro
img = snapshot(cam);
fig = figure('Name', 'Control LQI + Kalman (Iriun 30 FPS)', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) setappdata(src, 'cerrar', true));
setappdata(fig, 'cerrar', false);
hImg = imshow(img); hold on;

hCentroBase = plot(NaN, NaN, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
hCircBase   = plot(NaN, NaN, 'b-', 'LineWidth', 1.2);
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

%% 4. Bucle de control LQI + Kalman Adaptativo
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
        else
            set(hCentroBase, 'XData', NaN, 'YData', NaN);
            set(hCircBase, 'XData', NaN, 'YData', NaN);
        end
    end
    
    if ~baseDetectada || ~bolaDetectada
        if kalmanIniciado && ((tAhora - tUltimaBola) < 0.25)
            dt_blur = max(min(tAhora - tAnt, 0.10), 0.015);
            tAnt = tAhora;
            Ad_blur = [1, dt_blur; 0, exp(-amortig * dt_blur)];
            xEst = Ad_blur * xEst;
            yEst = Ad_blur * yEst;
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
    errY = -y;
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
        
        % Integrador condicional con anti-windup para absorber inclinación residual del plato
        if abs(xEst(1)) < 35.0 && abs(xEst(2)) < 75.0
            intX = max(min(intX + xEst(1) * dt, intMax), -intMax);
        end
        if abs(yEst(1)) < 35.0 && abs(yEst(2)) < 75.0
            intY = max(min(intY + yEst(1) * dt, intMax), -intMax);
        end
        
        % Ley de control LQI saturada a ±7.5°
        betaX = max(min(K(1) * xEst(1) + K(2) * xEst(2) + K(3) * intX, betaMax), -betaMax);
        betaY = max(min(K(1) * yEst(1) + K(2) * yEst(2) + K(3) * intY, betaMax), -betaMax);
        
        registroControlPD('guardar', [tAhora, x, y, hypot(errX_girado, errY_girado), -xEst(2), yEst(2), betaX, betaY]);
        moverPlataforma(betaX, betaY, puerto);
    end
    
    if isgraphics(fig) && mod(contadorVis, 3) == 0
        set(hBola, 'XData', centroBola_x, 'YData', centroBola_y);
        title(sprintf('dt: %.0f ms | Pos X: %+.1f mm | Pos Y: %+.1f mm | Beta: (%+.1f°, %+.1f°)', ...
              dt*1000, x, y, betaX, betaY));
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