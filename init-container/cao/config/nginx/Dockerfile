FROM localhost:5555/nginx

ARG HOST=host_here
ENV THIS_HOST=$HOST

RUN mkcert -key-file /root/key.pem -cert-file /root/cert.pem $HOST
