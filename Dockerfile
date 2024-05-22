FROM nginx:stable

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/
RUN mkdir -p /etc/ssl/certs/