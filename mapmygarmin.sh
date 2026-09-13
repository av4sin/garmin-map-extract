#!/bin/bash

# ==============================================================================
# SCRIPT DE GESTIÓN DE MAPAS PARA GARMIN ETREX 10
# ==============================================================================
# Automatiza el backup, selección y carga de mapas personalizados respetando
# el límite estricto de tamaño del dispositivo.

set -e # Detener el script si ocurre algún error inesperado

# --- AYUDA Y ARGUMENTOS ---
mostrar_ayuda() {
        cat <<'EOF'
Uso: mapmygarmin.sh [-h] [DIRECTORIO_MAPAS]

Si no se indica DIRECTORIO_MAPAS, se usa:
    $HOME/Documents/Mapas_Garmin

Opciones:
    -h, --help   Muestra esta ayuda y termina

Ejemplos:
    mapmygarmin.sh
    mapmygarmin.sh /ruta/a/Mapas_Garmin
EOF
}

while [ "$#" -gt 0 ]; do
        case "$1" in
                -h|--help)
                        mostrar_ayuda
                        exit 0
                        ;;
                --)
                        shift
                        break
                        ;;
                -*)
                        echo "Opción no reconocida: $1"
                        echo
                        mostrar_ayuda
                        exit 1
                        ;;
                *)
                        break
                        ;;
        esac
done

# --- CONFIGURACIÓN DE RUTAS ---
# Modifica estas rutas según tu entorno
DIRECTORIO_MAPAS="${1:-$HOME/Documents/Mapas_Garmin}" # Carpeta con los mapas .img preparados; acepta ruta por parámetro
PUNTO_MONTAJE_GARMIN="/run/media/$USER/C29A-DCC5" # Punto de montaje habitual en Linux

# --- CONSTANTES ---
LIMITE_BYTES=8388608 # 8 MiB estrictos
FICHERO_MAPA_DESTINO="gmapbmap.img" # El mapa base a sustituir

# --- REVISIÓN DE REQUISITOS ---
if [ ! -d "$DIRECTORIO_MAPAS" ]; then
    echo "Error: La carpeta de mapas origen '$DIRECTORIO_MAPAS' no existe."
    exit 1
fi

if [ ! -d "$PUNTO_MONTAJE_GARMIN/Garmin" ]; then
    echo "Error: No se detecta el Garmin conectado en '$PUNTO_MONTAJE_GARMIN'."
    echo "   Asegúrate de que está encendido, conectado por USB y montado."
    exit 1
fi

echo "Garmin eTrex 10 detectado correctamente."
echo "------------------------------------------------------------"

# --- 1. ENUMERAR LOS MAPAS DISPONIBLES ---
echo "Buscando mapas disponibles en el catálogo..."
mapfile -t mapas < <(find "$DIRECTORIO_MAPAS" -maxdepth 1 -name "*.img" -printf "%f\n" | sort)

if [ ${#mapas[@]} -eq 0 ]; then
    echo "No se encontraron archivos .img en $DIRECTORIO_MAPAS"
    exit 1
fi

echo "Mapas encontrados:"
for i in "${!mapas[@]}"; do
    tamano_bytes=$(stat -c%s "$DIRECTORIO_MAPAS/${mapas[$i]}")
    tamano_mib=$(echo "scale=2; $tamano_bytes / 1048576" | bc)
    
    # Validar si excede el límite del eTrex 10
    if [ "$tamano_bytes" -gt "$LIMITE_BYTES" ]; then
        status="EXCEDE 8 MiB (No recomendado)"
    else
        status="OK (~$tamano_mib MiB)"
    fi
    
    printf "  [%d] %-30s - %s\n" "$i" "${mapas[$i]}" "$status"
done

# --- 2. ELEGIR EL MAPA A CARGAR ---
echo "------------------------------------------------------------"
read -p "Selecciona el número del mapa que deseas cargar: " seleccion

if [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [ "$seleccion" -ge "${#mapas[@]}" ]; then
    echo "Selección no válida."
    exit 1
fi

MAPA_SELECCIONADO="${mapas[$seleccion]}"
RUTA_MAPA_ORIGEN="$DIRECTORIO_MAPAS/$MAPA_SELECCIONADO"
TAMANO_SELECCIONADO=$(stat -c%s "$RUTA_MAPA_ORIGEN")

# Alerta crítica de tamaño
if [ "$TAMANO_SELECCIONADO" -gt "$LIMITE_BYTES" ]; then
    echo "ATENCIÓN: El mapa elegido supera los 8 MiB de seguridad."
    read -p "¿Deseas continuar bajo tu propio riesgo? (s/N): " confirmar
    if [[ ! "$confirmar" =~ ^[sS]$ ]]; then
        echo "Proceso cancelado."
        exit 0
    fi
fi

# --- 3. CREAR COPIA DE SEGURIDAD COMPLETA ---
FECHA=$(date +%Y%m%d_%H%M%S)
DIR_BACKUP="/tmp/garmin_backup_$FECHA"

echo "------------------------------------------------------------"
echo "Iniciando copia de seguridad completa del dispositivo..."
echo "   Destino temporal: $DIR_BACKUP"

mkdir -p "$DIR_BACKUP"
# Copia toda la estructura del Garmin de forma recursiva preservando atributos
cp -r "$PUNTO_MONTAJE_GARMIN/"* "$DIR_BACKUP/"

echo "Copia de seguridad finalizada con éxito."

# --- 4. SUSTITUIR LOS ARCHIVOS NECESARIOS ---
echo "------------------------------------------------------------"
echo "Preparando la carga del mapa..."

RUTAS_POSIBLES=(
    "$PUNTO_MONTAJE_GARMIN/Garmin/$FICHERO_MAPA_DESTINO"
    "$PUNTO_MONTAJE_GARMIN/$FICHERO_MAPA_DESTINO"
)

DESTINO_FINAL=""
for ruta in "${RUTAS_POSIBLES[@]}"; do
    if [ -f "$ruta" ] || [ -d "$(dirname "$ruta")" ]; then
        DESTINO_FINAL="$ruta"
        break
    fi
done

if [ -z "$DESTINO_FINAL" ]; then
    echo "No se pudo determinar la ubicación correcta para gmapbmap.img"
    exit 1
fi

echo "Reemplazando mapa base en: $DESTINO_FINAL"
cp "$RUTA_MAPA_ORIGEN" "$DESTINO_FINAL"
echo "Archivo copiado."

# --- 5. DEJAR EL EQUIPO LISTO PARA DESCONECTAR ---
echo "------------------------------------------------------------"
echo "Asegurando la integridad de los datos (ejecutando sync)..."
echo "Por favor, NO desconectes el GPS todavía."
sync

echo "¡Todo listo! El mapa '$MAPA_SELECCIONADO' ha sido cargado."
echo "Ya puedes expulsar de forma segura la unidad USB desde tu sistema operativo."
