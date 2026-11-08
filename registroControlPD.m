function salida = registroControlPD(accion, varargin)
% REGISTROCONTROLPSD Gestiona el registro del controlador PD.
%
% Uso:
%   registroControlPD('iniciar')
%   registroControlPD('guardar', [t x y dist vx vy betaX betaY])
%   archivo = registroControlPD('finalizar')
%
% Los CSV se guardan automaticamente en la carpeta ./registros

persistent datos idx maxFrames

salida = [];

switch lower(accion)

    case 'iniciar'

        % 10 minutos a 30 FPS
        maxFrames = 30 * 60 * 10;

        % Columnas:
        % t, X, Y, distancia, Vx, Vy, betaX, betaY
        datos = nan(maxFrames,8);
        idx = 0;


    case 'guardar'

        if isempty(datos)
            error('El registro no esta iniciado. Usa registroControlPD(''iniciar'').');
        end

        fila = varargin{1};

        if numel(fila) ~= 8
            error('Cada registro debe contener 8 valores.');
        end

        idx = idx + 1;

        % Ampliar memoria si se superan los 10 minutos
        if idx > size(datos,1)
            ampliacion = 30 * 60 * 5;   % 5 minutos extra
            datos = [datos; nan(ampliacion,8)];
        end

        datos(idx,:) = fila;


    case 'finalizar'

        if isempty(datos) || isempty(idx) || idx == 0
            salida = '';
            datos = [];
            idx = [];
            maxFrames = [];
            return;
        end

        datosValidos = datos(1:idx,:);

        tabla = array2table(datosValidos, ...
            'VariableNames', { ...
            'Tiempo_s', ...
            'X_mm', ...
            'Y_mm', ...
            'DistanciaCentro_mm', ...
            'Vx_mm_s', ...
            'Vy_mm_s', ...
            'BetaX_deg', ...
            'BetaY_deg'});

        % Crear carpeta de registros si no existe
        carpetaRegistros = fullfile(pwd,'registros');

        if ~exist(carpetaRegistros,'dir')
            mkdir(carpetaRegistros);
        end

        marcaTiempo = char(datetime('now','Format','yyyyMMdd_HHmmss'));

        nombreArchivo = ['controlPD_' marcaTiempo '.csv'];

        rutaArchivo = fullfile(carpetaRegistros,nombreArchivo);

        writetable(tabla,rutaArchivo);

        salida = rutaArchivo;

        % Limpiar memoria persistente para el siguiente ensayo
        datos = [];
        idx = [];
        maxFrames = [];


    case 'cancelar'

        datos = [];
        idx = [];
        maxFrames = [];


    otherwise

        error('Accion desconocida: %s',accion);

end

end
