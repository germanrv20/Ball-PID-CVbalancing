function [betaX_IK,betaY_IK] = aplicarReposo(betaX,betaY)

%% =====================================================
%% NUEVO CERO / PUNTO DE REPOSO REAL
%% =====================================================

% Punto experimental donde la plataforma queda en reposo
betaX0 = 0;
betaY0 = 1;

% Convertir pendientes relativas al nuevo cero en pendientes
% que entiende la cinematica inversa geometrica
betaX_IK = betaX + betaX0;
betaY_IK = betaY + betaY0;

end
