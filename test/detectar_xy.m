
% 2. Aislar SOLO el color rojo (evitando que el fondo blanco interfiera)
% Extraemos los 3 canales
R = img(:, :, 1);
G = img(:, :, 2);
B = img(:, :, 3);

% Restamos el promedio de Verde y Azul al canal Rojo.
% El blanco tiene R, G y B altos, por lo que se volverá 0 (negro).
% El marcador rojo tiene R alto y G/B bajos, por lo que resaltará en blanco.
soloRojo = R - max(G, B); 

% 3. Binarización con umbral manual o Otsu
% Como soloRojo tiene valores entre 0 y 255, un umbral de 50-80 suele aislar bien el rojo
bw = soloRojo > 60; 

% Limpiamos ruido diminuto (bajamos de 500 a 50 porque tu marca roja es pequeña)
bw = bwareaopen(bw, 50); 
bw = imfill(bw, 'holes');

% 4. Analizar las regiones detectadas
% Añadimos 'Solidity' y 'MajorAxisLength'/'MinorAxisLength' para descartar los cables largos
stats = regionprops(bw, 'Area', 'BoundingBox', 'Extent', 'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'Centroid');

% 5. Mostrar resultados
figure;
subplot(1, 2, 1);
imshow(bw);
title('Máscara de Color Rojo Aislado');

subplot(1, 2, 2);
imshow(img);
title('Rectángulo Rojo Detectado');
hold on;

rectangulosEncontrados = 0;

for k = 1:length(stats)
    % Calculamos la proporción largo/ancho para ignorar los cables finos y alargados
    relacionAspecto = stats(k).MajorAxisLength / stats(k).MinorAxisLength;
    
    % Un rectángulo compacto tiene buena solidez (> 0.8) y no es excesivamente alargado como un cable (< 4)
    if stats(k).Solidity > 0.80 && relacionAspecto < 4
        rectangulosEncontrados = rectangulosEncontrados + 1;
        
        rectangle('Position', stats(k).BoundingBox, ...
                  'EdgeColor', 'g', ...
                  'LineWidth', 2);
              
        plot(stats(k).Centroid(1), stats(k).Centroid(2), 'y+', 'MarkerSize', 8);
    end
end

hold off;
fprintf('Se han detectado %d rectángulo(s) rojo(s).\n', rectangulosEncontrados);