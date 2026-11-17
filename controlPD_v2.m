clc;
listaCamaras = webcamlist;
if isempty(listaCamaras)
    error('No se ha encontrado ninguna webcam.');
end
fprintf('Camaras disponibles:\n\n');
for k = 1:length(listaCamaras)
    fprintf('%d -> %s\n', k, listaCamaras{k});
end
if length(listaCamaras) == 1
    indiceCamara = 1;
else
    indiceCamara = input('\nSelecciona numero de camara: ');
end
cam = webcam(indiceCamara);
fprintf('\nCamara seleccionada:\n%s\n', listaCamaras{indiceCamara});

%% 1. Conexión con Arduino y posición inicial
if ~exist('puerto', 'var')
    puerto = serialport("COM16", 115200);
    configureTerminator(puerto, "LF");
    pause(2);
end
moverPlataforma(0, 0, puerto);

%% 2. Parámetros del controlador PD
Kp = 0.13;
Kd = 0.05;
betaMax = 10.0;

%% 3. Inicialización de gráficos, estado y registro
img = snapshot(cam);
fig = figure('Name', 'Control PD por Error de Posición', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) setappdata(src, 'cerrar', true));
setappdata(fig, 'cerrar', false);

hImg = imshow(img); hold on;
% Handles gráficos dinámicos para la base y la bola
hCentroBase = plot(NaN, NaN, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
hCircBase   = plot(NaN, NaN, 'b-', 'LineWidth', 1.2); % Más rápido que viscircles en tiempo real
hBola       = plot(NaN, NaN, 'r+', 'MarkerSize', 12, 'LineWidth', 2);

thetaCirc = linspace(0, 2*pi, 100); % Precalculado para dibujar el círculo de la base rápido
[errX_girado_Ant, errY_girado_Ant] = deal(NaN);
anguloAnt = 0; % Respaldo por si un frame pierde el marcador rojo

% hMarcador      = plot(NaN, NaN, 'yo', 'MarkerSize', 8, 'LineWidth', 2);       % Centroide del cuadrado rojo
% hLineaAngulo   = plot([NaN NaN], [NaN NaN], 'y--', 'LineWidth', 1.5);         % Línea centro base -> marcador
% hRectMarcador  = rectangle('Position', [0 0 1 1], 'EdgeColor', 'g', 'LineWidth', 2, 'Visible', 'off'); % Cuadrado detectado

registroControlPD('iniciar');
tic;
tAnt = toc;

%% 4. Bucle de control PD
while isgraphics(fig) && ~getappdata(fig, 'cerrar')
    img = snapshot(cam);
    [centroBola_x, centroBola_y, centro_x, centro_y, radioBase, mmPorPixel, baseDetectada, bolaDetectada] = detectarBolas(img);
    
    % Actualizar visualización del centro y borde de la base en todo momento
    if isgraphics(fig)
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
        moverPlataforma(0, 0, puerto);
        [errX_girado_Ant, errY_girado_Ant] = deal(NaN);
        tAnt = toc;
        if isgraphics(fig)
            set(hBola, 'XData', NaN, 'YData', NaN);
            title('Esperando detección de base y bola...');
            % set(hMarcador, 'XData', NaN, 'YData', NaN);
            % set(hLineaAngulo, 'XData', [NaN NaN], 'YData', [NaN NaN]);
            % set(hRectMarcador, 'Visible', 'off');
        end
        drawnow limitrate;
        continue;
    end

    % Calcular ángulo de la base (si falla en un frame, mantiene el último válido)
    angulo= calcularAnguloBase(img, centro_x, centro_y, radioBase);
    angulo = 0;
    if isnan(angulo)
        angulo = anguloAnt;
    else
        anguloAnt = angulo;
    end

    % Posición actual de la bola respecto al centro de la base en mm
    % (X positivo a la derecha, Y positivo hacia arriba)
    x = (centroBola_x - centro_x) * mmPorPixel;
    y = (centro_y - centroBola_y) * mmPorPixel;
    
    % Error respecto al centro (0, 0)
    errX = x;
    errY = y;
    
    % Rotar el error al sistema de referencia de los servos
    [errX_girado, errY_girado] = rotarError(errX, errY, angulo);
    
    % Paso de tiempo y derivada del error girado
    t = toc;
    dt = max(t - tAnt, 1e-3);
    tAnt = t;
    
    if isnan(errX_girado_Ant)
        dErrX = 0; 
        dErrY = 0;
    else
        dErrX = (errX_girado - errX_girado_Ant) / dt;
        dErrY = (errY_girado - errY_girado_Ant) / dt;
    end
    errX_girado_Ant = errX_girado; 
    errY_girado_Ant = errY_girado;
    
    % Ley de control PD
    betaX = max(min(Kp * errX_girado + Kd * dErrX, betaMax), -betaMax);
    betaY = max(min(Kp * errY_girado + Kd * dErrY, betaMax), -betaMax);
    
    % Guardar muestra y mover plataforma
    registroControlPD('guardar', [t, x, y, hypot(errX_girado, errY_girado), -dErrX, -dErrY, betaX, betaY]);
    moverPlataforma(betaX, betaY, puerto);
    
    % Actualizar gráfico de la bola y título
    if isgraphics(fig)
        set(hBola, 'XData', centroBola_x, 'YData', centroBola_y);
        title(sprintf('Ángulo: %.1f° | ErrBase X: %+.1f mm | ErrBase Y: %+.1f mm', angulo, errX_girado, errY_girado));
    end
    % if ~isnan(centroMarcador(1))
    %     set(hMarcador, 'XData', centroMarcador(1), 'YData', centroMarcador(2));
    %     set(hLineaAngulo, 'XData', [centro_x, centroMarcador(1)], 'YData', [centro_y, centroMarcador(2)]);
    %     set(hRectMarcador, 'Position', bboxMarcador, 'Visible', 'on');
    % else
    %     set(hMarcador, 'XData', NaN, 'YData', NaN);
    %     set(hLineaAngulo, 'XData', [NaN NaN], 'YData', [NaN NaN]);
    %     set(hRectMarcador, 'Visible', 'off');
    % end
    drawnow limitrate;
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