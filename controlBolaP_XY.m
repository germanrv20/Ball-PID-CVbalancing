%% =========================================================
%% CONTROL PROPORCIONAL DE LA BOLA - EJES X E Y
%% =========================================================

clc;

%% =========================================================
%% 1. COMPROBAR VARIABLES DE VISION
%% =========================================================

variablesNecesarias = {
    'cam'
    'xc'
    'yc'
    'R'
    'radioBolaRef'
    'mmPorPixel'
    'polaridadBola'
};

for k = 1:length(variablesNecesarias)

    if ~exist(variablesNecesarias{k},'var')

        error(['Falta la variable "', ...
            variablesNecesarias{k}, ...
            '". Ejecuta primero inicializarVision.']);

    end

end


%% =========================================================
%% 2. CONECTAR CON ARDUINO
%% =========================================================

if ~exist('puerto','var')

    fprintf('Conectando con Arduino...\n');

    puerto = serialport("COM3",115200);

    configureTerminator(puerto,"LF");

    pause(2);

    flush(puerto);

end


%% =========================================================
%% 3. LLEVAR PLATAFORMA AL REPOSO
%% =========================================================

moverPlataforma(0,0,puerto);

pause(1);


%% =========================================================
%% 4. PARAMETROS DEL CONTROL
%% =========================================================

% Ganancias proporcionales
KpX = 0.02;          % grados/mm
KpY = 0.02;          % grados/mm

% Inclinacion maxima en cada eje
betaMax = 5.0;       % grados

% Zona muerta
zonaMuertaX = 2.0;   % mm
zonaMuertaY = 2.0;   % mm

% Filtro de posicion
alpha = 0.40;

% Frames consecutivos permitidos sin detectar bola
maxFramesPerdidos = 3;


fprintf('\n========================================\n');
fprintf('CONTROL PROPORCIONAL - X E Y\n');
fprintf('========================================\n');

fprintf('KpX = %.3f grados/mm\n',KpX);
fprintf('KpY = %.3f grados/mm\n',KpY);

fprintf('betaMax = %.2f grados\n',betaMax);

fprintf('Zona muerta X = %.2f mm\n',zonaMuertaX);
fprintf('Zona muerta Y = %.2f mm\n',zonaMuertaY);

fprintf('Filtro alpha = %.2f\n',alpha);

fprintf('\nCierra la ventana para detener.\n\n');


%% =========================================================
%% 5. CREAR FIGURA
%% =========================================================

img = snapshot(cam);

fig = figure;

hImg = imshow(img);

hold on;


%% Centro plataforma

plot(xc,yc,'b+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


%% Borde plataforma

viscircles([xc yc],R,'Color','b');


%% Bola

hBola = plot(NaN,NaN,'r+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


%% =========================================================
%% 6. VARIABLES DEL CONTROL
%% =========================================================

cronometro = tic;

numFrames = 0;

framesPerdidos = 0;

xFiltrado = NaN;
yFiltrado = NaN;


%% =========================================================
%% 7. BUCLE DE CONTROL
%% =========================================================

while isgraphics(fig)

    %% -----------------------------------------------------
    %% CAPTURAR IMAGEN
    %% -----------------------------------------------------

    try

        img = snapshot(cam);

    catch

        fprintf('Error de camara. Frame descartado.\n');
        continue;

    end


    if ~isgraphics(fig)
        break;
    end


    %% -----------------------------------------------------
    %% DETECTAR BOLA
    %% -----------------------------------------------------

    [xBola,yBola,dx,dy,detectada,radioBola] = ...
        detectarBola( ...
        img, ...
        xc, ...
        yc, ...
        R, ...
        radioBolaRef, ...
        polaridadBola);


    %% -----------------------------------------------------
    %% ACTUALIZAR IMAGEN
    %% -----------------------------------------------------

    if isgraphics(hImg)

        set(hImg,'CData',img);

    else

        break;

    end


    %% =====================================================
    %% 8. BOLA NO DETECTADA
    %% =====================================================

    if ~detectada

        framesPerdidos = framesPerdidos + 1;

        fprintf('Bola no detectada (%d/%d)\n', ...
            framesPerdidos, ...
            maxFramesPerdidos);


        if framesPerdidos >= maxFramesPerdidos

            fprintf('\nBola perdida. Plataforma a reposo.\n');

            moverPlataforma(0,0,puerto);

            break;

        end


        if isgraphics(hBola)

            set(hBola, ...
                'XData',NaN, ...
                'YData',NaN);

        end


        drawnow limitrate;

        continue;

    end


    %% Bola detectada

    framesPerdidos = 0;


    %% =====================================================
    %% 9. CONVERTIR PIXELES A COORDENADAS FISICAS
    %% =====================================================

    % Convencion de nuestra plataforma:
    %
    % +X = izquierda de la imagen
    % +Y = abajo de la imagen

    x_mm = -dx * mmPorPixel;

    y_mm = dy * mmPorPixel;


    %% =====================================================
    %% 10. FILTRAR POSICION
    %% =====================================================

    if isnan(xFiltrado)

        xFiltrado = x_mm;
        yFiltrado = y_mm;

    else

        xFiltrado = ...
            alpha*x_mm + ...
            (1-alpha)*xFiltrado;

        yFiltrado = ...
            alpha*y_mm + ...
            (1-alpha)*yFiltrado;

    end


    %% =====================================================
    %% 11. ZONAS MUERTAS
    %% =====================================================

    if abs(xFiltrado) <= zonaMuertaX

        errorX = 0;

    else

        errorX = xFiltrado;

    end


    if abs(yFiltrado) <= zonaMuertaY

        errorY = 0;

    else

        errorY = yFiltrado;

    end


    %% =====================================================
    %% 12. CONTROL PROPORCIONAL
    %% =====================================================

    betaX = -KpX * errorX;

    betaY = -KpY * errorY;


    %% =====================================================
    %% 13. SATURACION
    %% =====================================================

    betaX = max( ...
        min(betaX,betaMax), ...
        -betaMax);


    betaY = max( ...
        min(betaY,betaMax), ...
        -betaMax);


    %% =====================================================
    %% 14. MOVER PLATAFORMA
    %% =====================================================

    moverPlataforma( ...
        betaX, ...
        betaY, ...
        puerto);


    %% =====================================================
    %% 15. ACTUALIZAR BOLA
    %% =====================================================

    if isgraphics(hBola)

        set(hBola, ...
            'XData',xBola, ...
            'YData',yBola);

    end


    %% =====================================================
    %% 16. TITULO
    %% =====================================================

    if isgraphics(fig)

        title(sprintf( ...
            ['X = %+.1f mm | Y = %+.1f mm | ' ...
             'betaX = %+.2f | betaY = %+.2f deg'], ...
            x_mm, ...
            y_mm, ...
            betaX, ...
            betaY));

    end


    %% =====================================================
    %% 17. MOSTRAR CONSOLA
    %% =====================================================

    fprintf( ...
        ['X = %+6.2f | Y = %+6.2f mm | ' ...
         'betaX = %+5.2f | betaY = %+5.2f deg\n'], ...
        xFiltrado, ...
        yFiltrado, ...
        betaX, ...
        betaY);


    %% =====================================================
    %% 18. ACTUALIZAR FIGURA
    %% =====================================================

    if ~isgraphics(fig)
        break;
    end


    drawnow limitrate;

    numFrames = numFrames + 1;

end


%% =========================================================
%% 19. FINALIZACION
%% =========================================================

fprintf('\nDeteniendo control...\n');


%% Volver al reposo

moverPlataforma(0,0,puerto);


%% Estadisticas

tiempoTotal = toc(cronometro);


if numFrames > 0

    fps = numFrames / tiempoTotal;


    fprintf('\n========================================\n');
    fprintf('CONTROL FINALIZADO\n');
    fprintf('========================================\n');

    fprintf('Frames procesados = %d\n',numFrames);
    fprintf('Tiempo total = %.2f s\n',tiempoTotal);
    fprintf('FPS medio = %.2f\n',fps);

end


fprintf('Plataforma en reposo.\n');