function angulo = calcularAnguloBase(img, centro_x, centro_y)
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