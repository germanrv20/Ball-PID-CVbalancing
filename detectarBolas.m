function [centroBola_x, centroBola_y, centroBase_x, centroBase_y, radioBase, mmPorPixel, ...
          baseDetectada, bolaDetectada] = detectarBolas(imagen)

%% 1. PARAMETROS

cfg.paso = 3;

cfg.plateH = [0.55 0.75];
cfg.plateSmin = 0.40;
cfg.plateVmin = 0.15;

cfg.areaMinRelativa = 0.01;
cfg.circularidadMin = 0.80;

cfg.plot = true;

% Elementos estructurantes
persistent seC seM seO

if isempty(seC)
    seC = strel('disk', 1);
    seM = strel('disk', 3);
    seO = strel('disk', 1);
end

% Radio real de la plataforma
radioPlataforma_mm = 75;


%% 2. REDUCIR RESOLUCION

sub = imagen(1:cfg.paso:end, 1:cfg.paso:end, :);


%% 3. SEGMENTACION HSV

hsv = rgb2hsv(im2single(sub));

azul = hsv(:,:,1) >= cfg.plateH(1) & ...
       hsv(:,:,1) <= cfg.plateH(2) & ...
       hsv(:,:,2) >= cfg.plateSmin & ...
       hsv(:,:,3) >= cfg.plateVmin;


%% 4. INICIALIZAR SALIDAS

centroBola_x = NaN;
centroBola_y = NaN;
centroBase_x = NaN;
centroBase_y = NaN;

radioBase = NaN;
mmPorPixel = NaN;

baseDetectada = false;
bolaDetectada = false;

bolas = false(size(azul));


%% 5. DETECTAR PLATAFORMA

% Cerrar pequenos huecos en la mascara azul
azulCerrado = imclose(azul, seC);

% Conservar la region azul de mayor area
base = bwareafilt(azulCerrado, 1);

if any(base(:))

    baseDetectada = true;

    % Envolver la plataforma
    hull = bwconvhull(base);

    % Obtener centro y diametro
    pl = regionprops(hull, 'Centroid', 'EquivDiameter');

    ccBase = pl(1).Centroid;

    centroBase = 1 + (ccBase - 1) * cfg.paso;
    centroBase_x = centroBase(1);
    centroBase_y = centroBase(2);
    
    radioBase = (pl(1).EquivDiameter / 2) * cfg.paso;

    % Conversion de pixeles a milimetros
    mmPorPixel = radioPlataforma_mm / radioBase;


    %% 6. DETECTAR BOLA

    % Crear region interior de la plataforma
    roi = imerode(hull, seM);

    % Bola = interior de la plataforma que no es azul
    bolas = roi & ~azul;

    % Area minima de una posible bola
    radioBaseReducido = radioBase / cfg.paso;

    areaBase = pi * radioBaseReducido^2;

    areaMinima = cfg.areaMinRelativa * areaBase;

    % Eliminar pequenos objetos y ruido
    bolas = imopen(bolas, seO);

    bolas = bwareaopen(bolas, ceil(areaMinima));


    %% 7. SELECCIONAR UNA UNICA BOLA

stats = regionprops(bolas, ...
    'Area', 'Centroid', 'Perimeter', 'BoundingBox');

if ~isempty(stats)

    % Obtener propiedades
    areas = [stats.Area];
    perimetros = [stats.Perimeter];

    ancho = arrayfun(@(s) s.BoundingBox(3), stats);
    alto  = arrayfun(@(s) s.BoundingBox(4), stats);

    % Calcular circularidad
    circularidad = 4*pi*areas ./ (perimetros.^2);

    % Calcular relacion ancho/alto
    relacion = min(ancho, alto) ./ max(ancho, alto);

    % Calcular extension
    extension = areas ./ (ancho .* alto);

    % Comprobar condiciones
    validas = areas >= areaMinima & ...
              circularidad >= 0.80 & ...
              relacion >= 0.85 & ...
              extension <= 0.90;

    % Sustituir las areas no validas por cero
    areasValidas = areas;
    areasValidas(~validas) = 0;

    % Buscar la region valida de mayor area
    [areaMaxima, idx] = max(areasValidas);

    if areaMaxima > 0

        % Obtener centro de la bola
        ccBola = stats(idx).Centroid;

        centroBola = 1 + (ccBola - 1) * cfg.paso;

        bolaDetectada = true;
        centroBola_x = centroBola(1);
        centroBola_y = centroBola(2);

    end

end
end


%% 8. PLOT

% persistent fig ax1 ax2 hImagen hMascara hBase hBola
% 
% if cfg.plot
% 
%     % Crear ventana solo la primera vez
%     if isempty(fig) || ~isgraphics(fig)
% 
%         fig = figure('Name', 'Deteccion de bolas', ...
%                      'NumberTitle', 'off');
% 
%         ax1 = subplot(1,2,1, 'Parent', fig);
% 
%         hImagen = imshow(imagen, 'Parent', ax1);
%         hold(ax1, 'on');
% 
%         hBase = plot(ax1, NaN, NaN, ...
%                      'r+', 'MarkerSize', 12, 'LineWidth', 2);
% 
%         hBola = plot(ax1, NaN, NaN, ...
%                      'g+', 'MarkerSize', 12, 'LineWidth', 2);
% 
%         title(ax1, 'Imagen original');
% 
%         ax2 = subplot(1,2,2, 'Parent', fig);
% 
%         hMascara = imshow(bolas, 'Parent', ax2);
% 
%         title(ax2, 'Mascara binaria');
% 
%     end
% 
%     % Actualizar imagen original
%     set(hImagen, 'CData', imagen);
% 
%     % Actualizar mascara binaria
%     set(hMascara, 'CData', bolas);
% 
%     % Actualizar centro de la plataforma
%     if baseDetectada
%         set(hBase, 'XData', centroBase(1), ...
%                    'YData', centroBase(2));
%     else
%         set(hBase, 'XData', NaN, 'YData', NaN);
%     end
% 
%     % Actualizar centro de la bola
%     if bolaDetectada
%         set(hBola, 'XData', centroBola(1), ...
%                    'YData', centroBola(2));
%     else
%         set(hBola, 'XData', NaN, 'YData', NaN);
%     end
% 
%     drawnow limitrate;
% 
% end

end
