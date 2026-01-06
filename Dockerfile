FROM nginx:alpine

# Удаляем стандартную страницу nginx
RUN rm -rf /usr/share/nginx/html/*

# Копируем единственный файл
COPY index.html /usr/share/nginx/html/index.html

# Ничего больше не нужно
EXPOSE 80

