function [xBola, yBola, dx, dy, detectada, radioBola] = detectarBolaAuto_v2(img, xc, yc, R, fondoGray, xPrev, yPrev)
% DETECCION AUTOMATICA DE BOLA
% ROI -> Diferencia de fondo -> Segmentacion -> Morfologia -> Filtrado -> Tracking

    % 1. Valores por defecto
    [xBola, yBola, dx, dy, radioBola] = deal(NaN);
    detectada = false;

    % 2. Conversion a escala de grises
    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end
    [alto, ancho] = size(gray);

    % 3. Region de interes (ROI) de la plataforma
    margen = 25; % en pixeles
    xMin = max(1, floor(xc - R - margen));
    xMax = min(ancho, ceil(xc + R + margen));
    yMin = max(1, floor(yc - R - margen));
    yMax = min(alto, ceil(yc + R + margen));

    grayROI  = gray(yMin:yMax, xMin:xMax);
    fondoROI = fondoGray(yMin:yMax, xMin:xMax);
    xcROI = xc - xMin + 1;
    ycROI = yc - yMin + 1;

    % 4. Diferencia con el fondo y mascara circular
    difDouble = double(imabsdiff(grayROI, fondoROI));

    [XX, YY] = meshgrid(1:size(grayROI, 2), 1:size(grayROI, 1));
    mascaraPlataforma = sqrt((XX - xcROI).^2 + (YY - ycROI).^2) <= R;

    % 5. Umbralizacion automatica y segmentacion
    valores = difDouble(mascaraPlataforma);
    medianaDif = median(valores);
    desviacionRobusta = median(abs(valores - medianaDif));
    umbral = min(50, max(12, medianaDif + 6 * desviacionRobusta));

    BW = (difDouble > umbral) & mascaraPlataforma;

    % 6. Limpieza morfologica y filtrado de ruido por area
    BW = imopen(BW, strel('disk', 1, 0));
    BW = imclose(BW, strel('disk', 3, 0));
    BW = imfill(BW, 'holes');

    areaPlataforma = pi * R^2;
    areaMin = max(25, round(0.0005 * areaPlataforma));
    BW = bwareaopen(BW, areaMin);

    % 7. Extraccion y filtrado de candidatos por forma
    stats = regionprops(BW, 'Area', 'Centroid', 'Perimeter', ...
        'EquivDiameter', 'Solidity', 'MajorAxisLength', 'MinorAxisLength');
    if isempty(stats), return; end

    areaMax = 0.2 * areaPlataforma;
    centrosValidos = [];
    radiosValidos  = [];
    scores         = [];

    for k = 1:length(stats)
        area = stats(k).Area;
        perimetro = stats(k).Perimeter;
        if perimetro <= 0 || stats(k).MinorAxisLength <= 0
            continue;
        end

        circularidad = min(4 * pi * area / perimetro^2, 1);
        relacionEjes = stats(k).MajorAxisLength / stats(k).MinorAxisLength;
        centro = stats(k).Centroid;
        distanciaCentro = sqrt((centro(1) - xcROI)^2 + (centro(2) - ycROI)^2);

        if area >= areaMin && area <= areaMax && ...
           circularidad >= 0.45 && ...
           stats(k).Solidity >= 0.65 && ...
           relacionEjes <= 1.8 && ...
           distanciaCentro < R

            centrosValidos(end+1, :) = centro;
            radiosValidos(end+1, 1)  = stats(k).EquivDiameter / 2;
            scores(end+1, 1)         = 2 * circularidad + stats(k).Solidity - 0.3 * (relacionEjes - 1);
        end
    end

    if isempty(centrosValidos), return; end

    % 8. Coordenadas globales y seleccion (tracking temporal o mejor puntuacion)
    centrosFull = centrosValidos;
    centrosFull(:, 1) = centrosFull(:, 1) + xMin - 1;
    centrosFull(:, 2) = centrosFull(:, 2) + yMin - 1;

    if nargin >= 7 && ~isempty(xPrev) && ~isempty(yPrev) && isfinite(xPrev) && isfinite(yPrev)
        distanciaAnterior = sqrt((centrosFull(:, 1) - xPrev).^2 + (centrosFull(:, 2) - yPrev).^2);
        candidatosCercanos = distanciaAnterior <= 0.30 * R;

        if any(candidatosCercanos)
            indices = find(candidatosCercanos);
            [~, idxLocal] = min(distanciaAnterior(candidatosCercanos));
            idx = indices(idxLocal);
        else
            [~, idx] = max(scores);
        end
    else
        [~, idx] = max(scores);
    end

    % 9. Resultados finales
    xBola     = centrosFull(idx, 1);
    yBola     = centrosFull(idx, 2);
    radioBola = radiosValidos(idx);
    dx        = xBola - xc;
    dy        = yBola - yc;
    detectada = true;

    % 10. DEBUG VISUALIZACION
    debug = false;
    if debug
        figure('Name', '1. Imagen en gris');
        imshow(grayROI, []);
        hold on;
        viscircles([xcROI, ycROI], R, 'Color', 'y');
        title('ROI en gris');
        hold off;
    
        figure('Name', '2. Fondo');
        imshow(fondoROI, []);
        hold on;
        viscircles([xcROI, ycROI], R, 'Color', 'y');
        title('Fondo en la ROI');
        hold off;
    
        figure('Name', '3. Diferencia con el fondo');
        imshow(difDouble, []);
        hold on;
        viscircles([xcROI, ycROI], R, 'Color', 'y');
        title('Diferencia absoluta');
        hold off;
    
        figure('Name', '4. Segmentacion binaria');
        imshow(BW);
        hold on;
        viscircles([xcROI, ycROI], R, 'Color', 'y');
        if detectada
            plot(xBola - xMin + 1, yBola - yMin + 1, 'r+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        title('Mascara final de la bola');
        hold off;
        drawnow;
    end
end