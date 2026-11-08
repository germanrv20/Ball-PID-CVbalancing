function moverPlataforma(betaX,betaY,puerto)

%% =====================================================
%% LIMITE DE SEGURIDAD
%% =====================================================

betaMaxIK = 15;

%% =====================================================
%% APLICAR NUEVO PUNTO DE REPOSO
%% =====================================================

[betaX_IK,betaY_IK] = aplicarReposo(betaX,betaY);

% El limite se comprueba sobre la inclinacion fisica que recibira la IK
if abs(betaX_IK) > betaMaxIK || abs(betaY_IK) > betaMaxIK
    error(['Pendiente fuera del rango seguro. ' ...
           'Tras aplicar el reposo, la IK recibiria (%.2f, %.2f) grados'], ...
           betaX_IK,betaY_IK);
end

%% =====================================================
%% CINEMATICA INVERSA
%% =====================================================

[q1,q2] = cinematicaInversa(betaX_IK,betaY_IK);

%% =====================================================
%% MOSTRAR RESULTADOS
%% =====================================================

% fprintf('\nPendiente solicitada respecto al reposo:\n');
% fprintf('betaX = %.2f grados\n',betaX);
% fprintf('betaY = %.2f grados\n',betaY);
% 
% fprintf('Pendiente aplicada a la IK:\n');
% fprintf('betaX IK = %.2f grados\n',betaX_IK);
% fprintf('betaY IK = %.2f grados\n',betaY_IK);
% 
% fprintf('Servo 1 / D9  = %.3f grados\n',q1);
% fprintf('Servo 2 / D10 = %.3f grados\n',q2);

%% =====================================================
%% ENVIAR AMBOS SERVOS
%% =====================================================

enviarServos(puerto,q1,q2);

end
