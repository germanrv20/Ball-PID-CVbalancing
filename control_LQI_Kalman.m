clc;
listaCamaras = webcamlist;
fprintf('Camaras disponibles:\n\n');
for k = 1:length(listaCamaras)
    fprintf('%d -> %s\n', k, listaCamaras{k});
end
indiceCamara = 1;
cam = webcam(indiceCamara);
if any(strcmp(cam.AvailableResolutions, '640x480'))
    cam.Resolution = '640x480';
end
fprintf('\nCamara seleccionada: %s | Resolucion: %s\n', listaCamaras{indiceCamara}, cam.Resolution);

%% 1. Conexión con Arduino y posición inicial
if ~exist('puerto', 'var') || ~isvalid(puerto)
    puerto = serialport("COM16", 115200);
    configureTerminator(puerto, "LF");
    pause(2);
end
moverPlataforma(0, 0, puerto);

%% 2. Parámetros del controlador LQI + Predictor de Retardo + Kalman
betaMax = 7.5;    % Límite exclusivo del controlador (±7.5°)
dt_nom  = 0.0334; % Periodo medio real Iriun 640x480 (30.0 FPS)

amortig = 0.35;
ku      = 180.0;

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

Q_lqi  = diag([0.320, 0.220, 0.045]);
R_lqi  = 150.0;
intMax = 180.0;
Q_kal_base = diag([0.05, 260.0]);
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

%% 3. Inicialización de gráficos (con ejes X naranja e Y verde de la base)
img = snapshot(cam);
fig = figure('Name', 'Control LQI Predictivo + Ejes Base (Iriun 30 FPS)', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) setappdata(src, 'cerrar', true));
setappdata(fig, 'cerrar', false);
hImg = imshow(img); hold on;

hCentroBase = plot(NaN, NaN, 'wo', 'MarkerFaceColor', 'w', 'MarkerSize', 5);
hCircBase   = plot(NaN, NaN, 'b-', 'LineWidth', 1.2);
hCircMeta   = plot(NaN, NaN, 'g--', 'LineWidth', 1.2);
hEjeX       = plot([NaN NaN], [NaN NaN], '-', 'Color', [1 0.5 0], 'LineWidth', 2.2); % Eje +X (naranja)
hEjeY       = plot([NaN NaN], [NaN NaN], '-g', 'LineWidth', 2.2);                     % Eje +Y (verde)
hTxtX       = text(NaN, NaN, '+X', 'Color', [1 0.6 0], 'FontWeight', 'bold', 'FontSize', 9);
hTxtY       = text(NaN, NaN, '+Y', 'Color', 'g',       'FontWeight', 'bold', 'FontSize', 9);
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

nPred = 4;
betaHistX = zeros(nPred, 1);
betaHistY = zeros(nPred, 1);

dt = dt_nom;
contadorVis = 0;

registroControlPD('iniciar');
tic;
tAnt = toc;
tUltimaBola = tAnt;

%% 4. Bucle de control LQI Predictivo
while isgraphics(fig) && ~getappdata(fig, 'cerrar')
    img = snapshot(cam);
    [centroBola_x, centroBola_y, centro_x, centro_y, radioBase, mmPorPixel, baseDetectada, bolaDetectada] = detectarBolas(img);
    contadorVis = contadorVis + 1;
    tAhora = toc;
    
    % Calcular ángulo de giro siempre que haya base
    if baseDetectada
        angulo = calcularAnguloBase(img, centro_x, centro_y, radioBase);
        if isnan(angulo)
            angulo = anguloAnt;
            marcadorOk = false;
        else
            anguloAnt = angulo;
            marcadorOk = true;
        end
    else
        angulo = anguloAnt;
        marcadorOk = false;
    end
    
    % Dibujar base, pelota y ejes detectados (+X naranja, +Y verde)
    if isgraphics(fig) && mod(contadorVis, 3) == 0
        set(hImg, 'CData', img);
        if baseDetectada
            set(hCentroBase, 'XData', centro_x, 'YData', centro_y);
            set(hCircBase, 'XData', centro_x + radioBase * cos(thetaCirc), ...
                           'YData', centro_y + radioBase * sin(thetaCirc));
            
            pXx = centro_x + radioBase * cosd(angulo);
            pXy = centro_y - radioBase * sind(angulo);
            pYx = centro_x + radioBase * cosd(angulo + 90);
            pYy = centro_y - radioBase * sind(angulo + 90);
            
            set(hEjeX, 'XData', [centro_x, pXx], 'YData', [centro_y, pXy]);
            set(hEjeY, 'XData', [centro_x, pYx], 'YData', [centro_y, pYy]);
            set(hTxtX, 'Position', [pXx + 4, pXy]);
            set(hTxtY, 'Position', [pYx + 4, pYy]);
            
            if mmPorPixel > 0
                rMetaPx = 10.0 / mmPorPixel;
                set(hCircMeta, 'XData', centro_x + rMetaPx * cos(thetaCirc), ...
                               'YData', centro_y + rMetaPx * sin(thetaCirc));
            end
        else
            set(hCentroBase, 'XData', NaN, 'YData', NaN);
            set(hCircBase, 'XData', NaN, 'YData', NaN);
            set(hCircMeta, 'XData', NaN, 'YData', NaN);
            set(hEjeX, 'XData', [NaN NaN], 'YData', [NaN NaN]);
            set(hEjeY, 'XData', [NaN NaN], 'YData', [NaN NaN]);
            set(hTxtX, 'Position', [NaN NaN]);
            set(hTxtY, 'Position', [NaN NaN]);
        end
    end
    
    if ~baseDetectada || ~bolaDetectada
        if kalmanIniciado && ((tAhora - tUltimaBola) < 0.5)
            dt_blur = max(min(tAhora - tAnt, 0.10), 0.015);
            tAnt = tAhora;
            Ad_blur = [1, dt_blur; 0, exp(-amortig * dt_blur)];
            xEst = Ad_blur * xEst;
            yEst = Ad_blur * yEst;
            
            betaX_w = K(1) * xEst(1) + K(2) * xEst(2) + K(3) * intX;
            betaY_w = K(1) * yEst(1) + K(2) * yEst(2) + K(3) * intY;
            [betaX_rot, betaY_rot] = rotarError(betaX_w, betaY_w, angulo);
            betaX = max(min(betaX_rot, betaMax), -betaMax);
            betaY = max(min(-betaY_rot, betaMax), -betaMax);
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
            betaHistX = zeros(nPred, 1);
            betaHistY = zeros(nPred, 1);
            tAnt = tAhora;
        end
        if isgraphics(fig) && mod(contadorVis, 3) == 0
            set(hBola, 'XData', NaN, 'YData', NaN);
            title(sprintf('Giro: %.1f° (Marcador: %d) | Esperando bola...', angulo, marcadorOk));
            drawnow limitrate;
        end
        continue;
    end
    
    tUltimaBola = tAhora;
    
    % Error en marco dextrógiro fijo de cámara (+X derecha, +Y arriba)
    errX = (centroBola_x - centro_x) * mmPorPixel;
    errY = (centro_y - centroBola_y) * mmPorPixel;
    
    esFrameNuevo = isnan(errX_ant) || (abs(errX - errX_ant) > 1e-6) || ...
                   (abs(errY - errY_ant) > 1e-6) || ((tAhora - tAnt) >= 0.032);
    
    if esFrameNuevo
        dt = max(min(tAhora - tAnt, 0.15), 0.015);
        tAnt = tAhora;
        
        Ad_real = [1, dt;
                   0, exp(-amortig * dt)];
        Bd_real = [ku * (dt - (1 - exp(-amortig * dt)) / amortig) / amortig;
                   ku * (1 - exp(-amortig * dt)) / amortig];
        Qk_real = Q_kal_base * (dt / dt_nom);
        
        if ~kalmanIniciado
            xEst = [errX; 0];
            yEst = [errY; 0];
            intX = 0;
            intY = 0;
            Pk_x = Pk0;
            Pk_y = Pk0;
            betaHistX = zeros(nPred, 1);
            betaHistY = zeros(nPred, 1);
            kalmanIniciado = true;
        else
            xPred   = Ad_real * xEst;
            Pk_x    = Ad_real * Pk_x * Ad_real' + Qk_real;
            K_kal_x = (Pk_x * C') / (C * Pk_x * C' + R_kal);
            xEst    = xPred + K_kal_x * (errX - C * xPred);
            Pk_x    = (eye(2) - K_kal_x * C) * Pk_x;
            
            yPred   = Ad_real * yEst;
            Pk_y    = Ad_real * Pk_y * Ad_real' + Qk_real;
            K_kal_y = (Pk_y * C') / (C * Pk_y * C' + R_kal);
            yEst    = yPred + K_kal_y * (errY - C * yPred);
            Pk_y    = (eye(2) - K_kal_y * C) * Pk_y;
        end
        
        errX_ant = errX;
        errY_ant = errY;
        
        % 1. Predictor de estado adelantado con paso nominal fijo (evita picos si dt sube)
        xCtrl = xEst;
        yCtrl = yEst;
        betaEqX = K(3) * intX;
        betaEqY = K(3) * intY;
        for j = 1:nPred
            xCtrl = Ad * xCtrl - Bd * (betaHistX(j) - betaEqX);
            yCtrl = Ad * yCtrl - Bd * (betaHistY(j) - betaEqY);
        end
        
        distPred = hypot(xCtrl(1), yCtrl(1));
        velPred  = hypot(xCtrl(2), yCtrl(2));
        
        % 2. Integrador activo entre 2.0 mm y 70.0 mm (absorbe el desnivel residual sin saltos)
        if distPred > 2.0 && abs(xCtrl(1)) < 70.0 && abs(xCtrl(2)) < 90.0
            intX = max(min(intX + xCtrl(1) * dt, intMax), -intMax);
        end
        if distPred > 2.0 && abs(yCtrl(1)) < 70.0 && abs(yCtrl(2)) < 90.0
            intY = max(min(intY + yCtrl(1) * dt, intMax), -intMax);
        end
        
        % 3. Freno de captura suave + Zona de reposo sin escalones bruscos
        if distPred < 15.0
            kv_eff = K(2) * 1.45;
        else
            kv_eff = K(2);
        end
        
        if distPred < 3.5 && velPred < 7.0
            betaX_w = K(3) * intX;
            betaY_w = K(3) * intY;
        else
            betaX_w = K(1) * xCtrl(1) + kv_eff * xCtrl(2) + K(3) * intX;
            betaY_w = K(1) * yCtrl(1) + kv_eff * yCtrl(2) + K(3) * intY;
        end

        betaX_w = max(min(betaX_w, betaMax), -betaMax);
        betaY_w = max(min(betaY_w, betaMax), -betaMax);
        betaHistX = [betaHistX(2:end); betaX_w];
        betaHistY = [betaHistY(2:end); betaY_w];
        
        % 4. Rotar mando dextrógiro y adaptar sentido físico del servo Y (-betaY_rot)
        [betaX_rot, betaY_rot] = rotarError(betaX_w, betaY_w, angulo);
        betaX = max(min(betaX_rot, betaMax), -betaMax);
        betaY = max(min(-betaY_rot, betaMax), -betaMax);
        
        registroControlPD('guardar', [tAhora, errX, errY, hypot(errX, errY), xEst(2), yEst(2), betaX, betaY]);
        moverPlataforma(betaX, betaY, puerto);
    end
    
    if isgraphics(fig) && mod(contadorVis, 3) == 0
        set(hBola, 'XData', centroBola_x, 'YData', centroBola_y);
        title(sprintf('Giro: %.1f° (OK:%d) | Pos: (%+.1f, %+.1f) mm | Beta: (%+.1f°, %+.1f°)', ...
              angulo, marcadorOk, errX, errY, betaX, betaY));
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