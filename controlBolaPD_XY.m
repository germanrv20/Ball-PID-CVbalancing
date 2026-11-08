%% =========================================================
%% CONTROL PD DE LA BOLA
%% VISION AUTOMATICA
%% =========================================================

clc;


%% =========================================================
%% 1. COMPROBAR VISION
%% =========================================================

variablesNecesarias = {
    'cam'
    'xc'
    'yc'
    'R'
    'mmPorPixel'
    'fondoGray'
};

for k = 1:length(variablesNecesarias)

    if ~exist(variablesNecesarias{k},'var')

        error(['Falta "',variablesNecesarias{k}, ...
            '". Ejecuta primero inicializarVisionAuto.']);

    end

end


%% =========================================================
%% 2. ARDUINO
%% =========================================================

if ~exist('puerto','var')

    puerto = serialport("COM3",115200);

    configureTerminator(puerto,"LF");

    pause(2);

    flush(puerto);

end


%% =========================================================
%% 3. REPOSO INICIAL
%% =========================================================

moverPlataforma(0,0,puerto);

pause(1);


%% =========================================================
%% 4. PARAMETROS DEL CONTROL PD
%% =========================================================

KpX = 0.015;
KpY = 0.015;

KdX = 0.03;
KdY = 0.03;

betaMax = 7.0;


% Zona muerta solo para el termino proporcional
zonaMuertaX = 0.0;      % mm
zonaMuertaY = 0.0;      % mm


% Consideramos que el eje esta en reposo si
% posicion y velocidad son suficientemente pequenas
velocidadReposo = 0.0;  % mm/s


% Filtros
alphaPos = 0.40;
alphaVel = 0.50;


% La interfaz se actualiza menos veces que el control
actualizarImagenCada = 5;


%% =========================================================
%% 5. FIGURA DE SUPERVISION
%% =========================================================

img = snapshot(cam);


fig = figure( ...
    'Name','Control PD', ...
    'NumberTitle','off');


hImg = imshow(img);

hold on;


%% Centro de la plataforma

plot( ...
    xc, ...
    yc, ...
    'b+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


%% Borde de la plataforma

viscircles( ...
    [xc yc], ...
    R, ...
    'Color','b');


%% Posicion detectada de la bola

hBola = plot( ...
    NaN, ...
    NaN, ...
    'r+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


%% =========================================================
%% 6. VARIABLES DEL CONTROL
%% =========================================================

cronometro = tic;


% Numero total de iteraciones procesadas
numFrames = 0;


% Indica si actualmente estamos esperando a encontrar bola
bolaPerdida = false;


%% Posicion filtrada

xFiltrado = NaN;
yFiltrado = NaN;


%% Velocidad filtrada

vxFiltrada = 0;
vyFiltrada = 0;


%% Posicion anterior usada para calcular velocidad

xAnterior = NaN;
yAnterior = NaN;


%% Posicion anterior para tracking visual

xPrevVision = NaN;
yPrevVision = NaN;


%% Tiempo anterior

tAnterior = toc(cronometro);


%% =========================================================
%% 7. INICIAR REGISTRO
%% =========================================================

registroControlPD('iniciar');


%% =========================================================
%% 8. BUCLE DE CONTROL
%%
%% SOLO termina cuando se cierra la figura
%% =========================================================

while isgraphics(fig)


    %% =====================================================
    %% CAPTURAR IMAGEN
    %% =====================================================

    try

        img = snapshot(cam);

    catch

        % Si hay un fallo puntual de camara,
        % seguimos intentandolo
        drawnow limitrate;

        continue;

    end


    %% Contamos el frame
    numFrames = numFrames + 1;


    %% Si la ventana se ha cerrado durante la captura
    if ~isgraphics(fig)

        break;

    end


    %% =====================================================
    %% DETECTAR BOLA
    %% =====================================================

    [xBola,yBola,dx,dy,detectada,~] = ...
        detectarBolaAuto( ...
        img, ...
        xc, ...
        yc, ...
        R, ...
        fondoGray, ...
        xPrevVision, ...
        yPrevVision);


    %% =====================================================
    %% BOLA NO DETECTADA
    %% =====================================================

    if ~detectada


        %% -------------------------------------------------
        %% LLEVAR PLATAFORMA A REPOSO
        %% -------------------------------------------------
        %
        % Solo mandamos la orden una vez cuando pasamos
        % de "bola detectada" a "bola perdida".
        %
        % No es necesario enviar 0,0 continuamente.

        if ~bolaPerdida

            moverPlataforma( ...
                0, ...
                0, ...
                puerto);

            bolaPerdida = true;

        end


        %% -------------------------------------------------
        %% REINICIAR TRACKING VISUAL
        %% -------------------------------------------------

        xPrevVision = NaN;
        yPrevVision = NaN;


        %% -------------------------------------------------
        %% REINICIAR FILTRO DE POSICION
        %% -------------------------------------------------

        xFiltrado = NaN;
        yFiltrado = NaN;


        %% -------------------------------------------------
        %% REINICIAR CALCULO DE VELOCIDAD
        %% -------------------------------------------------

        xAnterior = NaN;
        yAnterior = NaN;

        vxFiltrada = 0;
        vyFiltrada = 0;


        %% -------------------------------------------------
        %% REINICIAR REFERENCIA TEMPORAL
        %% -------------------------------------------------
        %
        % Asi, cuando reaparezca la bola, no calculamos
        % la velocidad usando un intervalo enorme.

        tAnterior = toc(cronometro);


        %% -------------------------------------------------
        %% ACTUALIZAR INTERFAZ
        %% -------------------------------------------------

        if mod(numFrames,actualizarImagenCada) == 0


            %% Imagen actual

            if isgraphics(hImg)

                set( ...
                    hImg, ...
                    'CData',img);

            end


            %% Ocultar marcador de bola

            if isgraphics(hBola)

                set( ...
                    hBola, ...
                    'XData',NaN, ...
                    'YData',NaN);

            end


            %% Aviso

            if isgraphics(fig)

                title( ...
                    'Bola no detectada - plataforma en reposo');

            end


            %% Muy importante:
            %% permite que MATLAB procese el cierre de ventana

            drawnow limitrate;

        else

            % Aunque no actualicemos imagen,
            % procesamos eventos de la interfaz.
            drawnow limitrate;

        end


        %% Volvemos al principio del while.
        %% NO se termina el control.

        continue;

    end


    %% =====================================================
    %% BOLA DETECTADA
    %% =====================================================

    % Si antes estaba perdida, ahora hemos recuperado
    % correctamente la deteccion.

    if bolaPerdida

        bolaPerdida = false;

    end


    %% =====================================================
    %% ACTUALIZAR TRACKING VISUAL
    %% =====================================================

    xPrevVision = xBola;
    yPrevVision = yBola;


    %% =====================================================
    %% POSICION EN mm
    %% =====================================================

    % Convencion:
    %
    % +X = izquierda de la imagen
    % +Y = abajo de la imagen

    x_mm = ...
        -dx * mmPorPixel;


    y_mm = ...
        dy * mmPorPixel;


    %% =====================================================
    %% FILTRAR POSICION
    %% =====================================================

    if isnan(xFiltrado)


        % Primera muestra despues de:
        %
        % - arrancar
        % - recuperar la bola

        xFiltrado = x_mm;
        yFiltrado = y_mm;


    else


        xFiltrado = ...
            alphaPos*x_mm + ...
            (1-alphaPos)*xFiltrado;


        yFiltrado = ...
            alphaPos*y_mm + ...
            (1-alphaPos)*yFiltrado;


    end


    %% =====================================================
    %% TIEMPO ENTRE MUESTRAS
    %% =====================================================

    tActual = ...
        toc(cronometro);


    dt = ...
        tActual - tAnterior;


    tAnterior = ...
        tActual;


    if dt <= 0

        dt = 1/30;

    end


    %% =====================================================
    %% VELOCIDAD
    %% =====================================================

    if isnan(xAnterior)


        % Primera muestra:
        % no podemos calcular velocidad todavía.

        vx = 0;
        vy = 0;


    else


        vx = ...
            (xFiltrado-xAnterior) / dt;


        vy = ...
            (yFiltrado-yAnterior) / dt;


    end


    xAnterior = ...
        xFiltrado;


    yAnterior = ...
        yFiltrado;


    %% =====================================================
    %% FILTRAR VELOCIDAD
    %% =====================================================

    vxFiltrada = ...
        alphaVel*vx + ...
        (1-alphaVel)*vxFiltrada;


    vyFiltrada = ...
        alphaVel*vy + ...
        (1-alphaVel)*vyFiltrada;


    %% =====================================================
    %% ZONA MUERTA
    %% SOLO PARA EL TERMINO PROPORCIONAL
    %% =====================================================

    if abs(xFiltrado) <= zonaMuertaX

        errorPX = 0;

    else

        errorPX = xFiltrado;

    end


    if abs(yFiltrado) <= zonaMuertaY

        errorPY = 0;

    else

        errorPY = yFiltrado;

    end


    %% =====================================================
    %% CONTROL PD
    %% =====================================================

    betaX = ...
        -KpX*errorPX ...
        -KdX*vxFiltrada;


    betaY = ...
        -KpY*errorPY ...
        -KdY*vyFiltrada;


    %% =====================================================
    %% REPOSO REAL
    %% =====================================================

    % Si la bola esta cerca del centro Y ademas
    % casi parada, dejamos ese eje en reposo.

    if abs(xFiltrado) <= zonaMuertaX && ...
       abs(vxFiltrada) <= velocidadReposo

        betaX = 0;

    end


    if abs(yFiltrado) <= zonaMuertaY && ...
       abs(vyFiltrada) <= velocidadReposo

        betaY = 0;

    end


    %% =====================================================
    %% SATURACION
    %% =====================================================

    betaX = ...
        max( ...
        min(betaX,betaMax), ...
        -betaMax);


    betaY = ...
        max( ...
        min(betaY,betaMax), ...
        -betaMax);


    %% =====================================================
    %% DISTANCIA AL CENTRO
    %% =====================================================

    distanciaCentro = ...
        sqrt( ...
        xFiltrado^2 + ...
        yFiltrado^2);


    %% =====================================================
    %% REGISTRAR UNA MUESTRA
    %% =====================================================
    %
    % Solo se registran muestras cuando la bola
    % realmente esta detectada.

    registroControlPD( ...
        'guardar', ...
        [ ...
        tActual, ...
        xFiltrado, ...
        yFiltrado, ...
        distanciaCentro, ...
        vxFiltrada, ...
        vyFiltrada, ...
        betaX, ...
        betaY ...
        ]);


    %% =====================================================
    %% MOVER PLATAFORMA
    %% =====================================================

    moverPlataforma( ...
        betaX, ...
        betaY, ...
        puerto);


    %% =====================================================
    %% INTERFAZ REDUCIDA
    %% =====================================================

    if mod(numFrames,actualizarImagenCada) == 0


        %% Imagen

        if isgraphics(hImg)

            set( ...
                hImg, ...
                'CData',img);

        end


        %% Bola

        if isgraphics(hBola)

            set( ...
                hBola, ...
                'XData',xBola, ...
                'YData',yBola);

        end


        %% Posicion

        if isgraphics(fig)

            title(sprintf( ...
                'X=%+.1f mm | Y=%+.1f mm', ...
                xFiltrado, ...
                yFiltrado));

        end


        drawnow limitrate;

    end


end


%% =========================================================
%% 9. FINALIZAR CONTROL
%% =========================================================

% Al cerrar la ventana siempre volvemos a reposo.

moverPlataforma( ...
    0, ...
    0, ...
    puerto);


tiempoTotal = ...
    toc(cronometro);


%% =========================================================
%% FPS
%% =========================================================

if numFrames > 0

    fps = ...
        numFrames / tiempoTotal;

    fprintf( ...
        '\nFPS medio = %.2f\n', ...
        fps);

end


%% =========================================================
%% 10. FINALIZAR REGISTRO
%% =========================================================

archivoCSV = ...
    registroControlPD('finalizar');


if ~isempty(archivoCSV)

    fprintf( ...
        'CSV guardado en: %s\n', ...
        archivoCSV);

end