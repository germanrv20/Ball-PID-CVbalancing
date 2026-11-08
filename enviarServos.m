function enviarServos(puerto,q1,q2)

%% LIMITES

if q1 < 0 || q1 > 180
    error('Angulo q1 fuera de rango');
end

if q2 < 0 || q2 > 180
    error('Angulo q2 fuera de rango');
end


%% CREAR MENSAJE

mensaje = sprintf('%.3f,%.3f',q1,q2);


%% ENVIAR LOS DOS ANGULOS JUNTOS

writeline(puerto,mensaje);

end