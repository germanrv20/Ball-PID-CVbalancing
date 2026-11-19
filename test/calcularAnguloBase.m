function [anguloGiro, anguloInclinacion, sentidoInclinacion, info] = calcularAnguloBase(img, infoBase)
    % Si no se pasa infoBase desde detectarBolas, llamarlo una vez como respaldo
    if nargin < 2 || isempty(infoBase)
        [~, ~, ~, ~, ~, ~, ~, ~, infoBase] = detectarBolas(img);
    end

    % Geometría física real de la plataforma y pegatinas (en cm)
    radioDiscoCm    = 7.5;  % Radio real de la plataforma azul
    radioPegatinaCm = 8.0;  % Distancia radial del centro de las pegatinas
    desfaseCm       = 0.5;  % Desfase tangencial físico de las pegatinas respecto al eje real

    % Inicializar estructura de salida
    info = infoBase;
    info.pxPorCm            = NaN;
    info.radioDiscoPx       = NaN;
    info.radioPegatinaPx    = NaN;
    info.anguloInclinacion  = NaN;
    info.sentidoInclinacion = NaN;
    info.mascaraNaranja     = false(size(img, 1), size(img, 2));
    info.mascaraVerde       = false(size(img, 1), size(img, 2));
    info.naranja            = inicializarResultadoMarcador();
    info.verde              = inicializarResultadoMarcador();

    if ~infoBase.baseDetectada
        anguloGiro         = NaN;
        anguloInclinacion  = NaN;
        sentidoInclinacion = NaN;
        return;
    end

    % 1. EXTRAER INCLINACIÓN PURA Y SENTIDO DESDE LA ELIPSE DE detectarBolas
    centroDet = infoBase.centroBase;
    a         = infoBase.semiejeMayor;
    b         = infoBase.semiejeMenor;
    phiMayor  = infoBase.orientacionMayor;

    relacionEjes       = min(max(b / a, 0), 1.0);
    anguloInclinacion  = acosd(relacionEjes);
    sentidoInclinacion = mod(phiMayor + 90, 180);

    pxPorCm   = a / radioDiscoCm;
    desfasePx = desfaseCm * pxPorCm;

    info.pxPorCm            = pxPorCm;
    info.radioDiscoPx       = a;
    info.radioPegatinaPx    = radioPegatinaCm * pxPorCm;
    info.anguloInclinacion  = anguloInclinacion;
    info.sentidoInclinacion = sentidoInclinacion;

    % Vector de dirección de pendiente y factor de desproyección al plano del disco
    uMin = [cosd(sentidoInclinacion), -sind(sentidoInclinacion)];
    factorDesproyeccion = 1 / max(cosd(anguloInclinacion), 0.25);

    % 2. CREAR MÁSCARA DE ANILLO ALREDEDOR DE LA BASE (6.0 cm a 10.5 cm)
    [alto, ancho, ~] = size(img);
    [X, Y] = meshgrid(1:ancho, 1:alto);
    dX = X - centroDet(1);
    dY = Y - centroDet(2);

    proyMin = dX * uMin(1) + dY * uMin(2);
    dXPlano = dX + (factorDesproyeccion - 1) * proyMin * uMin(1);
    dYPlano = dY + (factorDesproyeccion - 1) * proyMin * uMin(2);
    distPlanoCm = hypot(dXPlano, dYPlano) / pxPorCm;

    mascaraAnillo = (distPlanoCm >= 6.0) & (distPlanoCm <= 10.5);

    % 3. SEGMENTACIÓN HSV DE PEGATINAS DENTRO DEL ANILLO
    hsv = rgb2hsv(img);
    H = hsv(:, :, 1);
    S = hsv(:, :, 2);
    V = hsv(:, :, 3);

    bwNaranja = (H >= 0.01 & H <= 0.105) & (S > 0.62) & (V > 0.50) & mascaraAnillo;
    bwVerde   = (H >= 0.22 & H <= 0.45)  & (S > 0.35) & (V > 0.25) & mascaraAnillo;

    bwNaranja = imfill(bwareaopen(bwNaranja, 60), 'holes');
    bwVerde   = imfill(bwareaopen(bwVerde,   60), 'holes');

    info.mascaraNaranja = bwNaranja;
    info.mascaraVerde   = bwVerde;

    % Detectar y ajustar cada marcador (-desfasePx en ambos según tu montaje)
    info.naranja = detectarYAjustarMarcador(bwNaranja, centroDet(1), centroDet(2), ...
        radioPegatinaCm, pxPorCm, -desfasePx, uMin, factorDesproyeccion);
    info.verde   = detectarYAjustarMarcador(bwVerde,   centroDet(1), centroDet(2), ...
        radioPegatinaCm, pxPorCm, -desfasePx, uMin, factorDesproyeccion);

    % 4. ÁNGULO DE GIRO FINAL (CON CONTRASTE Y RESPALDO)
    if info.naranja.detectado
        anguloGiro = info.naranja.anguloReal;

        if info.verde.detectado
            anguloEntre = abs(atan2d(sind(info.verde.anguloReal - info.naranja.anguloReal), ...
                                     cosd(info.verde.anguloReal - info.naranja.anguloReal)));
            tolerancia = 15;
            if abs(anguloEntre - 90) > tolerancia
                warning('calcularAnguloBase:ContrasteXY', ...
                    'Desviación detectada: el ángulo entre naranja (%.1f°) y verde (%.1f°) es de %.1f° (esperado ~90°).', ...
                    info.naranja.anguloReal, info.verde.anguloReal, anguloEntre);
            end
        end

    elseif info.verde.detectado
        anguloGiro = mod(info.verde.anguloReal + 90, 360);

    else
        anguloGiro = NaN;
    end
end

function res = inicializarResultadoMarcador()
    res.detectado      = false;
    res.rectangulo     = [];
    res.centroCuadrado = [NaN, NaN];
    res.distCuadradoPx = NaN;
    res.distCuadradoCm = NaN;
    res.anguloCuadrado = NaN;
    res.centroReal     = [NaN, NaN];
    res.distRealPx     = NaN;
    res.distRealCm     = NaN;
    res.anguloReal     = NaN;
end

function res = detectarYAjustarMarcador(bw, centro_x, centro_y, radioPegatinaCm, pxPorCm, desfasePx, uMin, factorDesproyeccion)
    res = inicializarResultadoMarcador();

    stats = regionprops(bw, 'Area', 'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'Centroid', 'PixelList');

    areaMaxima = 0;
    idxMejor   = 0;

    for k = 1:length(stats)
        if stats(k).MinorAxisLength <= 4
            continue;
        end
        relacionAspecto = stats(k).MajorAxisLength / stats(k).MinorAxisLength;

        vRel = [stats(k).Centroid(1) - centro_x, stats(k).Centroid(2) - centro_y];
        vPlano = vRel + (factorDesproyeccion - 1) * sum(vRel .* uMin) * uMin;
        distAlCentroCm = hypot(vPlano(1), vPlano(2)) / pxPorCm;

        if stats(k).Solidity > 0.72 && relacionAspecto < 4.8 && abs(distAlCentroCm - radioPegatinaCm) <= 1.3
            if stats(k).Area > areaMaxima
                areaMaxima = stats(k).Area;
                idxMejor   = k;
            end
        end
    end

    if idxMejor > 0
        res.detectado = true;
        cCuad = stats(idxMejor).Centroid;
        res.centroCuadrado = cCuad;

        pts0 = stats(idxMejor).PixelList - cCuad;
        [~, ~, V] = svd(pts0, 'econ');
        proj = pts0 * V;
        minP = min(proj, [], 1);
        maxP = max(proj, [], 1);
        esquinasProj = [minP(1), minP(2);
                        maxP(1), minP(2);
                        maxP(1), maxP(2);
                        minP(1), maxP(2);
                        minP(1), minP(2)];
        res.rectangulo = esquinasProj * V' + cCuad;

        vCuad = [cCuad(1) - centro_x, cCuad(2) - centro_y];
        vCuadPlano = vCuad + (factorDesproyeccion - 1) * sum(vCuad .* uMin) * uMin;

        res.distCuadradoPx = hypot(vCuadPlano(1), vCuadPlano(2));
        res.distCuadradoCm = res.distCuadradoPx / pxPorCm;

        angCuad = atan2d(-vCuadPlano(2), vCuadPlano(1));
        if angCuad < 0, angCuad = angCuad + 360; end
        res.anguloCuadrado = angCuad;

        ux = vCuadPlano(1) / res.distCuadradoPx;
        uy = vCuadPlano(2) / res.distCuadradoPx;

        vRealPlano = vCuadPlano + desfasePx * [uy, -ux];
        res.distRealPx = hypot(vRealPlano(1), vRealPlano(2));
        res.distRealCm = res.distRealPx / pxPorCm;

        angReal = atan2d(-vRealPlano(2), vRealPlano(1));
        if angReal < 0, angReal = angReal + 360; end
        res.anguloReal = angReal;

        invFactor = 1 / factorDesproyeccion;
        vRealImg = vRealPlano + (invFactor - 1) * sum(vRealPlano .* uMin) * uMin;
        res.centroReal = [centro_x, centro_y] + vRealImg;
    end
end