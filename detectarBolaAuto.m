function [xBola,yBola,dx,dy,detectada,radioBola] = ...
    detectarBolaAuto( ...
    img, ...
    xc, ...
    yc, ...
    R, ...
    fondoGray, ...
    xPrev, ...
    yPrev)

%% =========================================================
%% DETECCION AUTOMATICA DE BOLA
%%
%% Metodo:
%% 1. ROI de la plataforma
%% 2. Diferencia respecto al fondo
%% 3. Segmentacion
%% 4. Componentes conectados
%% 5. Filtrado por forma
%% 6. Tracking mediante posicion anterior
%%
%% NO necesita radio de bola previo
%% NO necesita polaridad bright/dark
%% =========================================================


%% =========================================================
%% 1. VALORES POR DEFECTO
%% =========================================================

xBola = NaN;
yBola = NaN;

dx = NaN;
dy = NaN;

radioBola = NaN;

detectada = false;


%% =========================================================
%% 2. IMAGEN EN GRIS
%% =========================================================

if size(img,3) == 3

    gray = rgb2gray(img);

else

    gray = img;

end


[alto,ancho] = size(gray);


%% =========================================================
%% 3. ROI DE LA PLATAFORMA
%% =========================================================

margen = 5;


xMin = max( ...
    1, ...
    floor(xc - R - margen));


xMax = min( ...
    ancho, ...
    ceil(xc + R + margen));


yMin = max( ...
    1, ...
    floor(yc - R - margen));


yMax = min( ...
    alto, ...
    ceil(yc + R + margen));


grayROI = ...
    gray(yMin:yMax,xMin:xMax);


fondoROI = ...
    fondoGray(yMin:yMax,xMin:xMax);


%% Coordenadas centro dentro de ROI

xcROI = ...
    xc - xMin + 1;


ycROI = ...
    yc - yMin + 1;


%% =========================================================
%% 4. DIFERENCIA CON EL FONDO
%% =========================================================

dif = ...
    imabsdiff( ...
    grayROI, ...
    fondoROI);


difDouble = ...
    double(dif);


%% =========================================================
%% 5. MASCARA CIRCULAR DE LA PLATAFORMA
%% =========================================================

[XX,YY] = meshgrid( ...
    1:size(grayROI,2), ...
    1:size(grayROI,1));


distPlataforma = sqrt( ...
    (XX-xcROI).^2 + ...
    (YY-ycROI).^2);


mascaraPlataforma = ...
    distPlataforma <= R;


%% =========================================================
%% 6. UMBRAL AUTOMATICO
%% =========================================================

valores = ...
    difDouble(mascaraPlataforma);


medianaDif = ...
    median(valores);


desviacionRobusta = ...
    median( ...
    abs(valores-medianaDif));


umbral = ...
    medianaDif + ...
    6*desviacionRobusta;


%% Limites razonables

umbral = ...
    max(12,umbral);


umbral = ...
    min(50,umbral);


%% =========================================================
%% 7. SEGMENTAR
%% =========================================================

BW = ...
    difDouble > umbral;


BW = ...
    BW & mascaraPlataforma;


%% =========================================================
%% 8. LIMPIEZA MORFOLOGICA
%% =========================================================

seAbrir = ...
    strel('disk',1,0);


seCerrar = ...
    strel('disk',3,0);


BW = ...
    imopen(BW,seAbrir);


BW = ...
    imclose(BW,seCerrar);


BW = ...
    imfill(BW,'holes');


%% =========================================================
%% 9. ELIMINAR OBJETOS MUY PEQUEÑOS
%% =========================================================

areaPlataforma = ...
    pi * R^2;


areaMin = ...
    max( ...
    25, ...
    round(0.0005 * areaPlataforma));


BW = ...
    bwareaopen(BW,areaMin);


%% =========================================================
%% 10. ANALIZAR COMPONENTES
%% =========================================================

stats = regionprops( ...
    BW, ...
    'Area', ...
    'Centroid', ...
    'Perimeter', ...
    'EquivDiameter', ...
    'Solidity', ...
    'MajorAxisLength', ...
    'MinorAxisLength');


if isempty(stats)

    return;

end


%% =========================================================
%% 11. FILTRAR CANDIDATOS
%% =========================================================

areaMax = ...
    0.12 * areaPlataforma;


centrosValidos = [];

radiosValidos = [];

scores = [];


for k = 1:length(stats)


    area = ...
        stats(k).Area;


    perimetro = ...
        stats(k).Perimeter;


    if perimetro <= 0

        continue;

    end


    %% Circularidad

    circularidad = ...
        4*pi*area / perimetro^2;


    circularidad = ...
        min(circularidad,1);


    %% Relacion entre ejes

    if stats(k).MinorAxisLength <= 0

        continue;

    end


    relacionEjes = ...
        stats(k).MajorAxisLength / ...
        stats(k).MinorAxisLength;


    %% Centro del candidato

    centro = ...
        stats(k).Centroid;


    distanciaCentro = ...
        sqrt( ...
        (centro(1)-xcROI)^2 + ...
        (centro(2)-ycROI)^2 );


    %% Condiciones

    condicionArea = ...
        area >= areaMin && ...
        area <= areaMax;


    condicionCircularidad = ...
        circularidad >= 0.45;


    condicionSolidez = ...
        stats(k).Solidity >= 0.65;


    condicionForma = ...
        relacionEjes <= 1.8;


    condicionDentro = ...
        distanciaCentro < R;


    if condicionArea && ...
       condicionCircularidad && ...
       condicionSolidez && ...
       condicionForma && ...
       condicionDentro


        centrosValidos(end+1,:) = ...
            centro;


        radiosValidos(end+1,1) = ...
            stats(k).EquivDiameter / 2;


        %% Puntuacion

        score = ...
            2*circularidad ...
            + stats(k).Solidity ...
            - 0.3*(relacionEjes-1);


        scores(end+1,1) = ...
            score;


    end


end


if isempty(centrosValidos)

    return;

end


%% =========================================================
%% 12. CONVERTIR CANDIDATOS A COORDENADAS DE IMAGEN
%% =========================================================

centrosFull = ...
    centrosValidos;


centrosFull(:,1) = ...
    centrosFull(:,1) + xMin - 1;


centrosFull(:,2) = ...
    centrosFull(:,2) + yMin - 1;


%% =========================================================
%% 13. SELECCIONAR BOLA
%% =========================================================

if nargin >= 7 && ...
   ~isempty(xPrev) && ...
   ~isempty(yPrev) && ...
   isfinite(xPrev) && ...
   isfinite(yPrev)


    %% Tracking temporal

    distanciaAnterior = sqrt( ...
        (centrosFull(:,1)-xPrev).^2 + ...
        (centrosFull(:,2)-yPrev).^2 );


    %% Movimiento maximo razonable entre frames

    saltoMax = ...
        0.30 * R;


    candidatosCercanos = ...
        distanciaAnterior <= saltoMax;


    if any(candidatosCercanos)


        indices = ...
            find(candidatosCercanos);


        [~,idxLocal] = ...
            min( ...
            distanciaAnterior(candidatosCercanos));


        idx = ...
            indices(idxLocal);


    else


        %% Si se pierde tracking,
        %% utilizar mejor candidato global

        [~,idx] = ...
            max(scores);


    end


else


    %% Primera deteccion

    [~,idx] = ...
        max(scores);


end


%% =========================================================
%% 14. RESULTADO
%% =========================================================

xBola = ...
    centrosFull(idx,1);


yBola = ...
    centrosFull(idx,2);


radioBola = ...
    radiosValidos(idx);


dx = ...
    xBola - xc;


dy = ...
    yBola - yc;


detectada = true;

end