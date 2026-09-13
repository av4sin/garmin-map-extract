import argparse
from datetime import datetime
from pathlib import Path

import pandas as pd


def obtener_ruta_csv(ruta_csv):
    if ruta_csv:
        return Path(ruta_csv).expanduser()
    return Path(__file__).resolve().parent / "Activities.csv"


def procesar_actividades(ruta_csv, fecha_inicio_str, fecha_fin_str):
    try:
        # 1. Leer el CSV original
        df = pd.read_csv(ruta_csv, sep=",", encoding="utf-8-sig", engine="python")
        df.columns = df.columns.str.strip()
        
        # --- CORRECCIÓN DE DESPLAZAMIENTO DE COLUMNAS ---
        df_corregido = pd.DataFrame()
        df_corregido['Fecha_Real'] = pd.to_datetime(df['Tipo de actividad'], errors='coerce')
        df_corregido['Duracion_Str'] = df['Calorías'].astype(str).str.strip()
        
        # --- PARSEO DE FECHAS DE ENTRADA ---
        formatos = ['%d/%m/%Y', '%Y-%m-%d']
        fecha_inicio = None
        fecha_fin = None
        
        for fmt in formatos:
            try:
                if not fecha_inicio:
                    fecha_inicio = datetime.strptime(fecha_inicio_str, fmt).date()
                if not fecha_fin:
                    fecha_fin = datetime.strptime(fecha_fin_str, fmt).date()
            except ValueError:
                continue
                
        if not fecha_inicio or not fecha_fin:
            print("\nError: Formato de fecha de entrada inválido. 'DD/MM/YYYY'.")
            return False

        # Extraer solo la parte del día para comparar
        df_corregido['Fecha_Solo_Dia'] = df_corregido['Fecha_Real'].dt.date
        
        # --- FILTRADO POR RANGO (INICIO INCLUIDO, FIN EXCLUIDO) ---
        filtro = (df_corregido['Fecha_Solo_Dia'] >= fecha_inicio) & (df_corregido['Fecha_Solo_Dia'] < fecha_fin)
        df_filtrado = df_corregido[filtro].copy()
        
        # --- CONVERSIÓN DE TIEMPO A SEGUNDOS TOTALES ---
        def hhmmss_a_segundos(tiempo_str):
            try:
                if pd.isna(tiempo_str) or tiempo_str == '--':
                    return 0
                partes = tiempo_str.split(':')
                if len(partes) == 3:  # Formato HH:MM:SS
                    h, m, s = map(int, partes)
                    return (h * 3600) + (m * 60) + s
                elif len(partes) == 2:  # Formato MM:SS
                    m, s = map(int, partes)
                    return (m * 60) + s
                return 0
            except:
                return 0

        # Calculamos los segundos exactos de cada actividad
        df_filtrado['Segundos_Totales'] = df_filtrado['Duracion_Str'].apply(hhmmss_a_segundos)
        
        # --- CÁLCULO DE MÉTRICAS CON PRECISIÓN ---
        total_actividades = len(df_filtrado)
        suma_segundos_totales = df_filtrado['Segundos_Totales'].sum()
        
        # Desglose matemático final sin perder ni un segundo
        horas = suma_segundos_totales // 3600
        minutos = (suma_segundos_totales % 3600) // 60
        segundos = suma_segundos_totales % 60
        
        # --- SALIDA REPORTE ---
        print("\n==================================================")
        print(f"RESUMEN DESDE EL {fecha_inicio.strftime('%d/%m/%Y')} (INC.) HASTA EL {fecha_fin.strftime('%d/%m/%Y')} (EXC.)")
        print("==================================================")
        print(f"· Número de actividades: {total_actividades}")
        print(f"· Tiempo total acumulado: {horas}h {minutos}m {segundos}s")
        print(f"   (Equivalente a {suma_segundos_totales} segundos)")
        print("==================================================\n")
        
        return True

    except FileNotFoundError:
        print(f"\nError: No se pudo encontrar el archivo '{ruta_csv}' en esta carpeta.")
        return True
    except Exception as e:
        print(f"\nOcurrió un error inesperado al procesar los datos: {e}")
        return True

# --- BLOQUE INTERACTIVO ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extrae información resumida de actividades desde un CSV.")
    parser.add_argument(
        "ruta_csv",
        nargs="?",
        default=None,
        help="Ruta al archivo CSV. Si no se indica, se usará Activities.csv en la misma carpeta del script.",
    )
    args = parser.parse_args()

    archivo_csv = obtener_ruta_csv(args.ruta_csv)

    print("¡Bienvenido al extractor de info de actividades!")
    print("Introduce el rango de fechas (Formato: DD/MM/YYYY)")

    exito = False
    while not exito:
        fecha_desde_input = input("\nIntroduce la fecha de INICIO (incluida) DD/MM/YYYY: ").strip()
        fecha_hasta_input = input("Introduce la fecha de FIN (excluida) DD/MM/YYYY: ").strip()

        if not fecha_desde_input or not fecha_hasta_input:
            print("Alguna fecha es errónea, revísalo.")
            continue

        exito = procesar_actividades(archivo_csv, fecha_desde_input, fecha_hasta_input)
