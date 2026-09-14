# Subir EV2 POS y App Web a GitHub

1. En GitHub, crea un repositorio **privado** llamado `ev2-pos-app-web`, sin README, `.gitignore` ni licencia inicial.
2. Descarga y descomprime `ev2-pos-app-web.zip`.
3. En GitHub Desktop elige **File → Add local repository**, selecciona la carpeta descomprimida y pulsa **Publish repository**. Activa **Keep this code private**.

Alternativamente, desde la terminal dentro de la carpeta descomprimida:

```bash
git init
git add .
git commit -m "Initial EV2 POS and web app MVP"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/ev2-pos-app-web.git
git push -u origin main
```

No subas un archivo `.env`. En el VPS, copia `.env.example` como `.env` y reemplaza los valores de ejemplo con secretos nuevos y privados.
