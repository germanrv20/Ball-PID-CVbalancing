clc;

% 1. Conexión con Arduino y posición inicial
if ~exist('puerto', 'var')
    puerto = serialport("COM3", 115200);
    configureTerminator(puerto, "LF");
    pause(2);
end
moverPlataforma(0, 0, puerto);

% 2. Parámetros del controlador PD y referencia en el centro (0,0)
Kp = 0.08;
Kd = 0.03;
betaMax = 7.0;

% Punto de referencia para estabilizar la bola
xRef = 0;
yRef = 0;

% 3. Inicialización de gráficos, estado y registro
img = undistortImage(snapshot(cam), cameraParams);
fig = figure('Name', 'Control PD por Error de Posición', 'NumberTitle', 'off', ...
    'CloseRequestFcn', @(src, ~) setappdata(src, 'cerrar', true));
setappdata(fig, 'cerrar', false);

hImg = imshow(img); hold on;
plot(xc, yc, 'b+', 'MarkerSize', 12, 'LineWidth', 1.5);
viscircles([xc yc], R, 'Color', 'b', 'LineWidth', 1);
hBola = plot(NaN, NaN, 'r+', 'MarkerSize', 12, 'LineWidth', 2);

[xPrev, yPrev, errXAnt, errYAnt] = deal(NaN);
registroControlPD('iniciar');
tic;
tAnt = toc;

% 4. Bucle de control PD
while isgraphics(fig) && ~getappdata(fig, 'cerrar')
    img = undistortImage(snapshot(cam), cameraParams);
    [xBola, yBola, dx, dy, detectada, rBola] = detectarBolaAuto_v2(img, xc, yc, R, fondoGray, xPrev, yPrev);

    if ~detectada
        moverPlataforma(0, 0, puerto);
        [xPrev, yPrev, errXAnt, errYAnt] = deal(NaN);
        tAnt = toc;
        if isgraphics(fig)
            set(hImg, 'CData', img);
            set(hBola, 'XData', NaN, 'YData', NaN);
            title('Bola no detectada');
        end
        drawnow limitrate;
        continue;
    end

    % Posición actual en mm y error respecto al centro (0,0)
    xPrev = xBola; yPrev = yBola;
    x = -dx * mmPorPixel;
    y =  dy * mmPorPixel;

    errX = xRef - x;
    errY = yRef - y;

    % Paso de tiempo y derivada del error de posición
    t = toc;
    dt = max(t - tAnt, 1e-3);
    tAnt = t;

    if isnan(errXAnt)
        dErrX = 0; dErrY = 0;
    else
        dErrX = (errX - errXAnt) / dt;
        dErrY = (errY - errYAnt) / dt;
    end
    errXAnt = errX; errYAnt = errY;

    % Ley de control PD basada en el error de posición
    betaX = max(min(Kp * errX + Kd * dErrX, betaMax), -betaMax);
    betaY = max(min(Kp * errY + Kd * dErrY, betaMax), -betaMax);

    % Guardar muestra en el registro
    registroControlPD('guardar', [t, x, y, hypot(errX, errY), -dErrX, -dErrY, betaX, betaY]);
    moverPlataforma(betaX, betaY, puerto);

    % Actualizar gráficos
    if isgraphics(fig)
        set(hImg, 'CData', img);
        set(hBola, 'XData', xBola, 'YData', yBola);
        % Graficar circulo bola
        if exist('hCirc', 'var') && isgraphics(hCirc)
            delete(hCirc);
        end
        hCirc = viscircles([xBola yBola], rBola, 'Color', 'r', 'LineWidth', 0.5);
        title(sprintf('Error X: %+.1f mm | Error Y: %+.1f mm', errX, errY));
    end
    drawnow limitrate;
end

% 5. Posición segura, exportación del CSV y cierre limpio de ventana
moverPlataforma(0, 0, puerto);
archivoCSV = registroControlPD('finalizar');
if ~isempty(archivoCSV)
    fprintf('CSV guardado en: %s\n', archivoCSV);
end
if isgraphics(fig)
    delete(fig);
end