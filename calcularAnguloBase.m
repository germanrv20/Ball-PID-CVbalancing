function anguloGiro = calcularAnguloBase(img, centro_x, centro_y, radioBase)
    if isnan(centro_x) || isnan(centro_y) || isnan(radioBase) || radioBase <= 0
        anguloGiro = NaN;
        return;
    end

    % Geometría física real (en cm)
    radioDiscoCm    = 7.5;  % Radio de la plataforma azul
    radioPegatinaCm = 8.0;  % Radio al centro de las pegatinas
    desfaseCm       = 0.5;  % Desfase tangencial respecto a los ejes reales

    pxPorCm   = radioBase / radioDiscoCm;
    desfasePx = desfaseCm * pxPorCm;

    % 1. RECORTAR REGIÓN DE INTERÉS (ROI) ALREDEDOR DE LA BASE PARA MÁXIMA VELOCIDAD
    [alto, ancho, ~] = size(img);
    radioMaxPx = ceil(10.5 * pxPorCm);

    xMin = max(1, floor(centro_x - radioMaxPx));
    xMax = min(ancho, ceil(centro_x + radioMaxPx));
    yMin = max(1, floor(centro_y - radioMaxPx));
    yMax = min(alto, ceil(centro_y + radioMaxPx));

    roi = img(yMin:yMax, xMin:xMax, :);
    cxRoi = centro_x - xMin + 1;
    cyRoi = centro_y - yMin + 1;

    % 2. MÁSCARA DE ANILLO EN EL ROI (6.0 cm a 10.5 cm)
    [altoRoi, anchoRoi, ~] = size(roi);
    [X, Y] = meshgrid(1:anchoRoi, 1:altoRoi);
    distCm = hypot(X - cxRoi, Y - cyRoi) / pxPorCm;
    mascaraAnillo = (distCm >= 6.0) & (distCm <= 10.5);

    % 3. SEGMENTACIÓN HSV DENTRO DEL ANILLO
    hsv = rgb2hsv(im2single(roi));
    H = hsv(:, :, 1);
    S = hsv(:, :, 2);
    V = hsv(:, :, 3);

    bwNaranja = (H >= 0.01 & H <= 0.11) & (S > 0.58) & (V > 0.45) & mascaraAnillo;
    bwVerde   = (H >= 0.20 & H <= 0.48) & (S > 0.25) & (V > 0.18) & mascaraAnillo;

    bwNaranja = bwareaopen(bwNaranja, 35);
    bwVerde   = bwareaopen(bwVerde,   35);

    % 4. CALCULAR ÁNGULO DE CADA MARCADOR CON DESFASE DE 0.5 CM
    angNaranja = obtenerAnguloMarcador(bwNaranja, cxRoi, cyRoi, radioPegatinaCm, pxPorCm, -desfasePx);
    angVerde   = obtenerAnguloMarcador(bwVerde,   cxRoi, cyRoi, radioPegatinaCm, pxPorCm, -desfasePx);

    % 5. SELECCIÓN Y RESPALDO (NARANJA = EJE X, VERDE = EJE Y)
    if ~isnan(angNaranja)
        anguloGiro = mod(angNaranja + 180, 360);
    elseif ~isnan(angVerde)
        anguloGiro = mod(angVerde - 90, 360);
    else
        anguloGiro = NaN;
    end
end

function angulo = obtenerAnguloMarcador(bw, cx, cy, radioPegatinaCm, pxPorCm, desfasePx)
    angulo = NaN;
    stats = regionprops(bw, 'Area', 'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'Centroid');

    areaMax = 0;
    cMejor  = [];

    for k = 1:length(stats)
        if stats(k).MinorAxisLength <= 2.2
            continue;
        end
        relAspecto = stats(k).MajorAxisLength / stats(k).MinorAxisLength;
        distCm     = hypot(stats(k).Centroid(1) - cx, stats(k).Centroid(2) - cy) / pxPorCm;

        if stats(k).Solidity > 0.65 && relAspecto < 12.0 && abs(distCm - radioPegatinaCm) <= 1.4
            if stats(k).Area > areaMax
                areaMax = stats(k).Area;
                cMejor  = stats(k).Centroid;
            end
        end
    end

    if ~isempty(cMejor)
        dx = cMejor(1) - cx;
        dy = cMejor(2) - cy; % +Y apunta hacia abajo en imagen
        distPx = hypot(dx, dy);

        % Vector unitario radial y corrección tangencial de 0.5 cm
        ux = dx / distPx;
        uy = dy / distPx;

        cReal = cMejor + desfasePx * [uy, -ux];

        ang = atan2d(-(cReal(2) - cy), cReal(1) - cx);
        if ang < 0
            ang = ang + 360;
        end
        angulo = ang;
    end
end