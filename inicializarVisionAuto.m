%% =========================================================
%% INICIALIZACION AUTOMATICA DE VISION
%%
%% - Seleccion automatica/manual de webcam
%% - Deteccion automatica de plataforma
%% - Calculo automatico centro y radio
%% - Calculo mm/pixel
%% - Captura del fondo SIN BOLA
%%
%% NO hace falta seleccionar:
%% - centro plataforma
%% - borde plataforma
%% - radio de bola
%% - polaridad bright/dark
%% =========================================================

clc;

fprintf('\n========================================\n');
fprintf('INICIALIZACION AUTOMATICA DE VISION\n');
fprintf('========================================\n\n');


%% =========================================================
%% 1. BUSCAR CAMARAS
%% =========================================================

listaCamaras = webcamlist;

if isempty(listaCamaras)

    error('No se ha encontrado ninguna webcam.');

end


fprintf('Camaras disponibles:\n\n');

for k = 1:length(listaCamaras)

    fprintf('%d -> %s\n', ...
        k, ...
        listaCamaras{k});

end


%% =========================================================
%% 2. SELECCIONAR CAMARA
%% =========================================================

if length(listaCamaras) == 1

    indiceCamara = 1;

else

    indiceCamara = input( ...
        '\nSelecciona numero de camara: ');

end


cam = webcam(indiceCamara);


fprintf('\nCamara seleccionada:\n');
fprintf('%s\n',listaCamaras{indiceCamara});


%% =========================================================
%% 3. CALENTAR CAMARA
%% =========================================================

fprintf('\nInicializando camara...\n');


preview(cam);

pause(2);

closePreview(cam);

pause(0.3);


%% =========================================================
%% 4. CONSEGUIR FRAME VALIDO
%% =========================================================

img = [];

for intento = 1:15

    imgTemporal = snapshot(cam); % undistortImage(snapshot(cam), cameraParams);
    
    if max(imgTemporal(:)) > 10

        img = imgTemporal;

        break;

    end

    pause(0.2);

end


if isempty(img)

    error('La camara no esta entregando imagenes validas.');

end


%% =========================================================
%% 5. CONVERTIR A GRIS
%% =========================================================

if size(img,3) == 3

    gray = rgb2gray(img);

else

    gray = img;

end


[alto,ancho] = size(gray);

dimensionMin = min(alto,ancho);


%% =========================================================
%% 6. BUSCAR PLATAFORMA CIRCULAR
%% =========================================================

fprintf('\nDetectando plataforma...\n');

% Busqueda suficientemente amplia para la plataforma

rMin = round(0.18 * dimensionMin);

rMax = round(0.48 * dimensionMin);


%% Buscar circulos claros

[centrosBright,radiosBright,metricasBright] = ...
    imfindcircles( ...
    gray, ...
    [rMin rMax], ...
    'ObjectPolarity','bright', ...
    'Sensitivity',0.95, ...
    'EdgeThreshold',0.05);


%% Buscar circulos oscuros

[centrosDark,radiosDark,metricasDark] = ...
    imfindcircles( ...
    gray, ...
    [rMin rMax], ...
    'ObjectPolarity','dark', ...
    'Sensitivity',0.95, ...
    'EdgeThreshold',0.05);


%% =========================================================
%% 7. UNIR CANDIDATOS
%% =========================================================

centros = [
    centrosBright
    centrosDark
];

radios = [
    radiosBright
    radiosDark
];

metricas = [
    metricasBright
    metricasDark
];


if isempty(centros)

    error(['No se ha podido detectar automaticamente ', ...
           'la plataforma.']);

end


%% =========================================================
%% 8. SELECCIONAR MEJOR CIRCULO
%% =========================================================

centroImagen = [
    ancho/2
    alto/2
];


distCentroImagen = sqrt( ...
    (centros(:,1)-centroImagen(1)).^2 + ...
    (centros(:,2)-centroImagen(2)).^2 );


%% Normalizar distancia

distNorm = ...
    distCentroImagen / dimensionMin;


%% Queremos:
%% - buena metrica
%% - circulo relativamente grande
%% - cerca del centro de imagen

radioNorm = ...
    radios / dimensionMin;


score = ...
    metricas ...
    + 0.5*radioNorm ...
    - 0.5*distNorm;


[~,idx] = max(score);


xc = centros(idx,1);

yc = centros(idx,2);

R = radios(idx);


%% =========================================================
%% 9. CALCULAR ESCALA REAL
%% =========================================================

diametroPlataforma_mm = 150;

radioPlataforma_mm = ...
    diametroPlataforma_mm / 2;


mmPorPixel = ...
    radioPlataforma_mm / R;


fprintf('\nPlataforma detectada:\n');

fprintf('Centro X = %.1f px\n',xc);
fprintf('Centro Y = %.1f px\n',yc);

fprintf('Radio = %.1f px\n',R);

fprintf('Escala = %.4f mm/pixel\n',mmPorPixel);


%% =========================================================
%% 10. MOSTRAR DETECCION
%% =========================================================

fig = figure( ...
    'Name','Plataforma detectada', ...
    'NumberTitle','off');


imshow(img);

hold on;


viscircles( ...
    [xc yc], ...
    R, ...
    'Color','b');


plot( ...
    xc, ...
    yc, ...
    'r+', ...
    'MarkerSize',20, ...
    'LineWidth',2);


title('Plataforma detectada automaticamente');


drawnow;


%% =========================================================
%% 11. CAPTURAR FONDO VACIO
%% =========================================================

fprintf('\n========================================\n');
fprintf('CAPTURA DEL FONDO\n');
fprintf('========================================\n');

fprintf('\nRetira la bola de la plataforma.\n');
fprintf('El fondo se capturara dentro de 3 segundos...\n');


pause(3);


numFramesFondo = 15;


acumulador = ...
    zeros(alto,ancho,'double');


fprintf('\nCapturando fondo...\n');


for k = 1:numFramesFondo


    frame = snapshot(cam); %undistortImage(snapshot(cam), cameraParams);


    if size(frame,3) == 3

        frameGray = rgb2gray(frame);

    else

        frameGray = frame;

    end


    acumulador = ...
        acumulador + double(frameGray);


end


fondoGray = ...
    uint8(acumulador / numFramesFondo);


fprintf('Fondo capturado correctamente.\n');


%% =========================================================
%% 12. GUARDAR CONFIGURACION
%% =========================================================

save( ...
    'calibracionVisionAuto.mat', ...
    'xc', ...
    'yc', ...
    'R', ...
    'mmPorPixel', ...
    'fondoGray', ...
    'diametroPlataforma_mm');


fprintf('\nCalibracion guardada en:\n');
fprintf('calibracionVisionAuto.mat\n');



%% Deetección angulo

calcularAnguloDisco(img, centros(idx, 1), centros(idx, 2));


%% =========================================================
%% 13. ESPERAR A QUE SE COLOQUE LA BOLA
%% =========================================================


if isgraphics(fig)

    close(fig);

end


fprintf('\nVision preparada.\n');






%%

function angulo = calcularAnguloDisco(img, centro_x, centro_y)
    R = img(:, :, 1);
    G = img(:, :, 2);
    B = img(:, :, 3);
    
    soloRojo = R - max(G, B);
    
    bw = soloRojo > 60; % Umbral de rojo (ajustar según iluminación)
    bw = bwareaopen(bw, 50);
    bw = imfill(bw, 'holes');
    
    stats = regionprops(bw, 'Area', 'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'Centroid');
    
    angulo = NaN;
    areaMaxima = 0;
    centroMarcador = [];
    
    for k = 1:length(stats)
        relacionAspecto = stats(k).MajorAxisLength / stats(k).MinorAxisLength;
        
        % Filtra objetos compactos y descarta cables alargados
        if stats(k).Solidity > 0.80 && relacionAspecto < 4
            if stats(k).Area > areaMaxima
                areaMaxima = stats(k).Area;
                centroMarcador = stats(k).Centroid;
            end
        end
    end
    
    if ~isempty(centroMarcador)
        dx = centroMarcador(1) - centro_x;
        dy = centro_y - centroMarcador(2); % Invierte Y para eje cartesiano real
        
        angulo = atan2d(dy, dx);
        
        if angulo < 0
            angulo = angulo + 360;
        end
    end

fprintf('Ángulo detectado: %.2f grados\n', angulo);

end
