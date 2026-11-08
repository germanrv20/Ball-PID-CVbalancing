%% =========================================================
%% DIAGNOSTICO DE VELOCIDAD
%% =========================================================

N = 30;

tiempoCaptura   = NaN(N,1);
tiempoDeteccion = NaN(N,1);
tiempoTotal     = NaN(N,1);


fprintf('Midiendo tiempos durante %d frames...\n\n',N);


for k = 1:N

    tTotal = tic;


    %% ================================================
    %% 1. CAPTURA
    %% ================================================

    try

        t = tic;

        img = snapshot(cam);

        tiempoCaptura(k) = toc(t);

    catch

        fprintf('Frame %d: ERROR DE CAMARA\n',k);

        continue;

    end


    %% ================================================
    %% 2. DETECCION
    %% ================================================

    t = tic;

    [xBola,yBola,dx,dy,detectada,radioBola] = ...
        detectarBola( ...
        img, ...
        xc, ...
        yc, ...
        R, ...
        radioBolaRef, ...
        polaridadBola);

    tiempoDeteccion(k) = toc(t);


    %% ================================================
    %% 3. TOTAL
    %% ================================================

    tiempoTotal(k) = toc(tTotal);


    fprintf( ...
        'Frame %2d: captura %.3f s | deteccion %.3f s | total %.3f s\n', ...
        k, ...
        tiempoCaptura(k), ...
        tiempoDeteccion(k), ...
        tiempoTotal(k));

end


%% =========================================================
%% RESULTADOS
%% =========================================================

capturaMedia = mean(tiempoCaptura,'omitnan');

deteccionMedia = mean(tiempoDeteccion,'omitnan');

totalMedio = mean(tiempoTotal,'omitnan');


fprintf('\n========================================\n');
fprintf('PROMEDIOS\n');
fprintf('========================================\n');

fprintf('Captura:   %.4f s\n',capturaMedia);

fprintf('Deteccion: %.4f s\n',deteccionMedia);

fprintf('Total:     %.4f s\n',totalMedio);


if totalMedio > 0

    fprintf('\nFPS teorico = %.2f\n', ...
        1/totalMedio);

end