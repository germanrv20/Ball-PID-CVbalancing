function [centroBola_x, centroBola_y, centroBase_x, centroBase_y, radioBase, mmPorPixel, ...
          baseDetectada, bolaDetectada] = detectarBolas(imagen)

%% 1. PARAMETROS
cfg.paso = 3;

% El plato azul es muy saturado (S > 0.65); subir plateSmin evita cortar
% el reflejo azulado sobre la mitad superior de la bola metalica
cfg.plateH    = [0.55 0.75];
cfg.plateSmin = 0.62;
cfg.plateVmin = 0.15;

cfg.areaMinRelativa = 0.0040;
cfg.areaMaxRelativa = 0.0650;
cfg.circularidadMin = 0.70;
cfg.radioUtilRel    = 0.84;

cfg.plot = false;

persistent seC seM seO seB ultBola framesPerdidos

if isempty(seC)
    seC = strel('disk', 2);
    seM = strel('disk', 4);
    seO = strel('disk', 1);
    seB = strel('disk', 2);
    ultBola = [];
    framesPerdidos = 0;
end

radioPlataforma_mm = 75;

%% 2. REDUCIR RESOLUCION
sub = im2single(imagen(1:cfg.paso:end, 1:cfg.paso:end, :));
R_ch = sub(:,:,1);

%% 3. SEGMENTACION HSV
hsv = rgb2hsv(sub);
H = hsv(:,:,1);
S = hsv(:,:,2);
V = hsv(:,:,3);

azul = H >= cfg.plateH(1) & H <= cfg.plateH(2) & ...
       S >= cfg.plateSmin & V >= cfg.plateVmin;

%% 4. INICIALIZAR SALIDAS
centroBola_x = NaN;
centroBola_y = NaN;
centroBase_x = NaN;
centroBase_y = NaN;
radioBase    = NaN;
mmPorPixel   = NaN;

baseDetectada = false;
bolaDetectada = false;
bolas = false(size(azul));

%% 5. DETECTAR PLATAFORMA
azulCerrado = imclose(azul, seC);
base = bwareafilt(azulCerrado, 1);

if any(base(:))
    baseDetectada = true;

    hull = bwconvhull(base);
    pl = regionprops(hull, 'Centroid', 'EquivDiameter');

    ccBase = pl(1).Centroid;
    centroBase_x = 1 + (ccBase(1) - 1) * cfg.paso;
    centroBase_y = 1 + (ccBase(2) - 1) * cfg.paso;

    radioBase = (pl(1).EquivDiameter / 2) * cfg.paso;
    mmPorPixel = radioPlataforma_mm / radioBase;

    %% 6. DETECTAR BOLA METALICA (INCLUYENDO SU BRILLO ESPECULAR)
    roi = imerode(hull, seM);

    % Todo lo que dentro del plato no sea azul saturado o tenga componente gris/blanca
    bolas = roi & (~azul | R_ch > 0.22);

    radioBaseReducido = radioBase / cfg.paso;
    areaBase   = pi * radioBaseReducido^2;
    areaMinima = cfg.areaMinRelativa * areaBase;
    areaMaxima = cfg.areaMaxRelativa * areaBase;

    % Cerrar bordes y rellenar el brillo blanco interior de la esfera
    bolas = imclose(bolas, seB);
    bolas = imfill(bolas, 'holes');
    bolas = imopen(bolas, seO);
    bolas = bwareaopen(bolas, max(8, ceil(areaMinima)));

    %% 7. SELECCIONAR UNA UNICA BOLA
    stats = regionprops(bolas, 'Area', 'Centroid', 'Perimeter', 'BoundingBox');

    if ~isempty(stats)
        areas      = [stats.Area]';
        perimetros = max([stats.Perimeter]', 1);

        ancho = arrayfun(@(s) s.BoundingBox(3), stats); ancho = ancho(:);
        alto  = arrayfun(@(s) s.BoundingBox(4), stats); alto  = alto(:);

        circularidad = 4 * pi * areas ./ (perimetros.^2);
        relacion     = min(ancho, alto) ./ max(ancho, alto);
        extension    = areas ./ (ancho .* alto);

        centros = reshape([stats.Centroid], 2, [])';
        cx_full = 1 + (centros(:,1) - 1) * cfg.paso;
        cy_full = 1 + (centros(:,2) - 1) * cfg.paso;
        distCentroPx = hypot(cx_full - centroBase_x, cy_full - centroBase_y);

        validas = (areas >= areaMinima) & ...
                  (areas <= areaMaxima) & ...
                  (circularidad >= cfg.circularidadMin) & ...
                  (relacion >= 0.76) & ...
                  (extension >= 0.55) & ...
                  (extension <= 0.92) & ...
                  (distCentroPx <= cfg.radioUtilRel * radioBase);
        validas = validas(:);

        if ~isempty(ultBola) && any(validas(:))
            salto_mm = hypot(cx_full - ultBola(1), cy_full - ultBola(2)) * mmPorPixel;
            cercanas = validas & (salto_mm <= 32.0);
            if any(cercanas(:))
                validas = cercanas;
            end
        end

        puntuacion = zeros(numel(areas), 1);
        for k = 1:numel(areas)
            if validas(k)
                bonusCercania = 1.0;
                if ~isempty(ultBola)
                    d_mm = hypot(cx_full(k) - ultBola(1), cy_full(k) - ultBola(2)) * mmPorPixel;
                    bonusCercania = 1.0 / (1.0 + d_mm / 12.0);
                end
                puntuacion(k) = min(circularidad(k), 1.05) * bonusCercania;
            end
        end

        [mejorScore, idx] = max(puntuacion);

        if mejorScore > 0
            bolaDetectada  = true;
            centroBola_x   = cx_full(idx);
            centroBola_y   = cy_full(idx);
            ultBola        = [centroBola_x, centroBola_y];
            framesPerdidos = 0;
        end
    end
end

if ~bolaDetectada
    framesPerdidos = framesPerdidos + 1;
    if framesPerdidos > 12
        ultBola = [];
    end
end

%% 8. PLOT DE DEPURACION
persistent fig ax1 ax2 hImagen hMascara hBase hBola

if cfg.plot
    if isempty(fig) || ~isgraphics(fig)
        fig = figure('Name', 'Depuracion detectarBolas', 'NumberTitle', 'off');
        ax1 = subplot(1,2,1, 'Parent', fig);
        hImagen = imshow(imagen, 'Parent', ax1);
        hold(ax1, 'on');
        hBase = plot(ax1, NaN, NaN, 'r+', 'MarkerSize', 12, 'LineWidth', 2);
        hBola = plot(ax1, NaN, NaN, 'g+', 'MarkerSize', 12, 'LineWidth', 2);
        title(ax1, 'Imagen original');

        ax2 = subplot(1,2,2, 'Parent', fig);
        hMascara = imshow(bolas, 'Parent', ax2);
        title(ax2, 'Mascara candidata');
    end

    set(hImagen, 'CData', imagen);
    set(hMascara, 'CData', bolas);
    set(hBase, 'XData', centroBase_x, 'YData', centroBase_y);
    set(hBola, 'XData', centroBola_x, 'YData', centroBola_y);
    drawnow limitrate;
end

end