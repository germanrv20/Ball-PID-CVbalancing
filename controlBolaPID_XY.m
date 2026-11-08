%% =========================================================
%% CONTROL PID DE LA BOLA
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
%% 4. PARAMETROS PID
%% =========================================================

% Proporcional
KpX = 0.026;
KpY = 0.026;


% Derivativo
KdX = 0.03;
KdY = 0.03;


% Integral
KiX = 0.001;
KiY = 0.001;


% Inclinacion maxima de la plataforma
betaMax = 5.0;              % grados


% Contribucion maxima permitida del integral
betaIntegralMax = 0.75;     % grados


% Zona muerta del termino proporcional
zonaMuertaX = 1.0;          % mm
zonaMuertaY = 1.0;          % mm


% El integral solo actua relativamente cerca del centro
zonaIntegral = 20.0;        % mm


% El integral solo acumula si la bola no va demasiado rapido
velocidadIntegral = 20.0;   % mm/s


% Reposo
velocidadReposo = 3.0;      % mm/s


% Filtros
alphaPos = 0.40;
alphaVel = 0.50;


% Actualizacion de la interfaz
actualizarImagenCada = 5;


%% =========================================================
%% 5. FIGURA
%% =========================================================

img = snapshot(cam);

fig = figure( ...
    'Name','Control PID', ...
    'NumberTitle','off');


hImg = imshow(img);

hold on;


% Centro
plot( ...
    xc, ...
    yc, ...
    'b+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


% Borde plataforma
viscircles( ...
    [xc yc], ...
    R, ...
    'Color','b');


% Bola
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

numFrames = 0;

bolaPerdida = false;


%% Posicion filtrada

xFiltrado = NaN;
yFiltrado = NaN;


%% Velocidad filtrada

vxFiltrada = 0;
vyFiltrada = 0;


%% Posicion anterior

xAnterior = NaN;
yAnterior = NaN;


%% Tracking visual

xPrevVision = NaN;
yPrevVision = NaN;


%% Integral

integralX = 0;
integralY = 0;


%% Tiempo

tAnterior = toc(cronometro);


%% =========================================================
%% 7. INICIAR REGISTRO
%% =========================================================

registroControlPD('iniciar');


%% =========================================================
%% 8. BUCLE DE CONTROL
%% =========================================================

while isgraphics(fig)


    %% =====================================================
    %% CAPTURAR IMAGEN
    %% =====================================================

    try

        img = snapshot(cam);

    catch

        drawnow limitrate;
        continue;

    end


    numFrames = numFrames + 1;


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


        %% Llevar plataforma a reposo

        if ~bolaPerdida

            moverPlataforma( ...
                0, ...
                0, ...
                puerto);

            bolaPerdida = true;

        end


        %% Reiniciar tracking

        xPrevVision = NaN;
        yPrevVision = NaN;


        %% Reiniciar posicion

        xFiltrado = NaN;
        yFiltrado = NaN;

        xAnterior = NaN;
        yAnterior = NaN;


        %% Reiniciar velocidad

        vxFiltrada = 0;
        vyFiltrada = 0;


        %% Reiniciar integral
        %
        % Muy importante para evitar windup al
        % volver a colocar la bola.

        integralX = 0;
        integralY = 0;


        %% Reiniciar tiempo

        tAnterior = toc(cronometro);


        %% Interfaz

        if mod(numFrames,actualizarImagenCada) == 0


            if isgraphics(hImg)

                set( ...
                    hImg, ...
                    'CData',img);

            end


            if isgraphics(hBola)

                set( ...
                    hBola, ...
                    'XData',NaN, ...
                    'YData',NaN);

            end


            if isgraphics(fig)

                title( ...
                    'Bola no detectada - plataforma en reposo');

            end

        end


        drawnow limitrate;

        continue;

    end


    %% =====================================================
    %% BOLA DETECTADA
    %% =====================================================

    bolaPerdida = false;


    %% Tracking

    xPrevVision = xBola;
    yPrevVision = yBola;


    %% =====================================================
    %% POSICION EN mm
    %% =====================================================

    % +X = izquierda
    % +Y = abajo

    x_mm = ...
        -dx * mmPorPixel;

    y_mm = ...
        dy * mmPorPixel;


    %% =====================================================
    %% FILTRO DE POSICION
    %% =====================================================

    if isnan(xFiltrado)


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
    %% TIEMPO
    %% =====================================================

    tActual = toc(cronometro);


    dt = ...
        tActual - tAnterior;


    tAnterior = tActual;


    if dt <= 0

        dt = 1/30;

    end


    %% =====================================================
    %% VELOCIDAD
    %% =====================================================

    if isnan(xAnterior)


        vx = 0;
        vy = 0;


    else


        vx = ...
            (xFiltrado-xAnterior) / dt;


        vy = ...
            (yFiltrado-yAnterior) / dt;


    end


    xAnterior = xFiltrado;
    yAnterior = yFiltrado;


    %% =====================================================
    %% FILTRO DE VELOCIDAD
    %% =====================================================

    vxFiltrada = ...
        alphaVel*vx + ...
        (1-alphaVel)*vxFiltrada;


    vyFiltrada = ...
        alphaVel*vy + ...
        (1-alphaVel)*vyFiltrada;


    %% =====================================================
    %% TERMINO PROPORCIONAL
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

    betaPD_X = ...
        -KpX*errorPX ...
        -KdX*vxFiltrada;


    betaPD_Y = ...
        -KpY*errorPY ...
        -KdY*vyFiltrada;


    %% =====================================================
    %% TERMINO INTEGRAL X
    %% =====================================================
    %
    % El integral solo se acumula:
    %
    % 1. Cerca del centro
    % 2. Fuera de la zona muerta
    % 3. Con velocidad moderada
    %
    % Esto evita que acumule error cuando la bola
    % esta lejos o se mueve rapidamente.

    activarIntegralX = ...
        abs(xFiltrado) > zonaMuertaX && ...
        abs(xFiltrado) <= zonaIntegral && ...
        abs(vxFiltrada) <= velocidadIntegral;


    if activarIntegralX


        integralXProvisional = ...
            integralX + xFiltrado*dt;


        %% Limitar directamente la contribucion en grados

        betaIntegralXProvisional = ...
            -KiX*integralXProvisional;


        betaIntegralXProvisional = ...
            max( ...
            min(betaIntegralXProvisional,betaIntegralMax), ...
            -betaIntegralMax);


        %% Anti-windup:
        %% solo aceptamos el nuevo integral si el control
        %% resultante no supera betaMax.

        betaProvisionalX = ...
            betaPD_X + betaIntegralXProvisional;


        if abs(betaProvisionalX) <= betaMax

            integralX = integralXProvisional;

        end


    elseif abs(xFiltrado) > zonaIntegral

        % Si la bola vuelve a estar lejos,
        % borramos el integral anterior.

        integralX = 0;

    end


    %% =====================================================
    %% TERMINO INTEGRAL Y
    %% =====================================================

    activarIntegralY = ...
        abs(yFiltrado) > zonaMuertaY && ...
        abs(yFiltrado) <= zonaIntegral && ...
        abs(vyFiltrada) <= velocidadIntegral;


    if activarIntegralY


        integralYProvisional = ...
            integralY + yFiltrado*dt;


        betaIntegralYProvisional = ...
            -KiY*integralYProvisional;


        betaIntegralYProvisional = ...
            max( ...
            min(betaIntegralYProvisional,betaIntegralMax), ...
            -betaIntegralMax);


        betaProvisionalY = ...
            betaPD_Y + betaIntegralYProvisional;


        if abs(betaProvisionalY) <= betaMax

            integralY = integralYProvisional;

        end


    elseif abs(yFiltrado) > zonaIntegral

        integralY = 0;

    end


    %% =====================================================
    %% CONTRIBUCION INTEGRAL FINAL
    %% =====================================================

    betaIX = ...
        -KiX*integralX;


    betaIY = ...
        -KiY*integralY;


    %% Limitar integral

    betaIX = ...
        max( ...
        min(betaIX,betaIntegralMax), ...
        -betaIntegralMax);


    betaIY = ...
        max( ...
        min(betaIY,betaIntegralMax), ...
        -betaIntegralMax);


    %% =====================================================
    %% PID COMPLETO
    %% =====================================================

    betaX = ...
        betaPD_X + betaIX;


    betaY = ...
        betaPD_Y + betaIY;


    %% =====================================================
    %% REPOSO REAL
    %% =====================================================

    if abs(xFiltrado) <= zonaMuertaX && ...
       abs(vxFiltrada) <= velocidadReposo


        betaX = 0;

        integralX = 0;


    end


    if abs(yFiltrado) <= zonaMuertaY && ...
       abs(vyFiltrada) <= velocidadReposo


        betaY = 0;

        integralY = 0;


    end


    %% =====================================================
    %% SATURACION FINAL
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
    %% REGISTRO
    %% =====================================================

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
    %% INTERFAZ
    %% =====================================================

    if mod(numFrames,actualizarImagenCada) == 0


        if isgraphics(hImg)

            set( ...
                hImg, ...
                'CData',img);

        end


        if isgraphics(hBola)

            set( ...
                hBola, ...
                'XData',xBola, ...
                'YData',yBola);

        end


        if isgraphics(fig)

            title(sprintf( ...
                ['X=%+.1f Y=%+.1f mm | ' ...
                 'I_X=%+.2f I_Y=%+.2f deg'], ...
                xFiltrado, ...
                yFiltrado, ...
                betaIX, ...
                betaIY));

        end


        drawnow limitrate;

    end


end


%% =========================================================
%% 9. FINALIZAR
%% =========================================================

moverPlataforma( ...
    0, ...
    0, ...
    puerto);


tiempoTotal = ...
    toc(cronometro);


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