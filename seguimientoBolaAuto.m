%% =========================================================
%% SEGUIMIENTO AUTOMATICO DE BOLA
%% =========================================================

clc;


%% =========================================================
%% 1. COMPROBAR VARIABLES
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

        error(['Falta "', ...
            variablesNecesarias{k}, ...
            '". Ejecuta inicializarVisionAuto.']);

    end

end


%% =========================================================
%% 2. FRAME INICIAL
%% =========================================================

img = snapshot(cam);


fig = figure( ...
    'Name','Seguimiento automatico', ...
    'NumberTitle','off');


hImg = imshow(img);

hold on;


plot( ...
    xc, ...
    yc, ...
    'b+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


viscircles( ...
    [xc yc], ...
    R, ...
    'Color','b');


hBola = plot( ...
    NaN, ...
    NaN, ...
    'r+', ...
    'MarkerSize',15, ...
    'LineWidth',2);


hCirculo = ...
    viscircles( ...
    [0 0], ...
    1, ...
    'Color','r');


%% =========================================================
%% 3. VARIABLES
%% =========================================================

xPrev = NaN;

yPrev = NaN;


cronometro = tic;

numFrames = 0;


%% =========================================================
%% 4. BUCLE
%% =========================================================

while isgraphics(fig)


    img = snapshot(cam);


    [xBola,yBola,dx,dy,detectada,radioBola] = ...
        detectarBolaAuto( ...
        img, ...
        xc, ...
        yc, ...
        R, ...
        fondoGray, ...
        xPrev, ...
        yPrev);


    if detectada


        xPrev = xBola;

        yPrev = yBola;


        x_mm = ...
            -dx * mmPorPixel;


        y_mm = ...
            dy * mmPorPixel;


        if isgraphics(hBola)

            set( ...
                hBola, ...
                'XData',xBola, ...
                'YData',yBola);

        end


        if isgraphics(hCirculo)

            delete(hCirculo);

        end


        hCirculo = ...
            viscircles( ...
            [xBola yBola], ...
            radioBola, ...
            'Color','r');


        title(sprintf( ...
            'X=%+.1f mm | Y=%+.1f mm | Radio=%.1f px', ...
            x_mm, ...
            y_mm, ...
            radioBola));


    else


        title('Bola no detectada');


    end


    if isgraphics(hImg)

        set(hImg,'CData',img);

    end


    drawnow limitrate;


    numFrames = ...
        numFrames + 1;


end


%% =========================================================
%% 5. RESULTADOS
%% =========================================================

tiempoTotal = toc(cronometro);


fprintf('\nSeguimiento finalizado.\n');

fprintf( ...
    'FPS medio = %.2f\n', ...
    numFrames/tiempoTotal);