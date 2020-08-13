# Trabajo Práctico - Microarquitecturas y Softcores

## Estructura

```
trabajo_practico
    /bd     Diagrama en bloques de vivado
    /hdl    Archivos hdl fuente
    /sw     Archivos fuente del software
    /tb     Archivos fuente para simulación
    /vivado Carpeta de proyecto de vivado
    /vivado/generator_wrapper.xsa Hardware file para la creación de la plataforma en Vitis 2019.2
```

## Recrear proyecto en vivado
```
cd vivado
vivado -source generator.tcl
```