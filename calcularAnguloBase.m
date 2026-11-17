function angulo = calcularAnguloBase(img, centro_x, centro_y, radioBase)
    R = img(:, :, 1);
    G = img(:, :, 2);
    B = img(:, :, 3);
    
    soloRojo = R - max(G, B);
    
    bw = soloRojo > 60;
    bw = bwareaopen(bw, 50);
    bw = imfill(bw, 'holes');
    
    stats = regionprops(bw, 'Area', 'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'Centroid');
    
    angulo = NaN;
    areaMaxima = 0;
    centroMarcador = [];
    
    for k = 1:length(stats)
        relacionAspecto = stats(k).MajorAxisLength / stats(k).MinorAxisLength;
        distAlCentro = hypot(stats(k).Centroid(1) - centro_x, stats(k).Centroid(2) - centro_y);
        
        if stats(k).Solidity > 0.80 && relacionAspecto < 4 && distAlCentro <= radioBase * 1.1
            if stats(k).Area > areaMaxima
                areaMaxima = stats(k).Area;
                centroMarcador = stats(k).Centroid;
            end
        end
    end
    
    if ~isempty(centroMarcador)
        dx = centroMarcador(1) - centro_x;
        dy = centro_y - centroMarcador(2);
        
        angulo = atan2d(dy, dx);
        if angulo < 0
            angulo = angulo + 360;
        end
    end
end