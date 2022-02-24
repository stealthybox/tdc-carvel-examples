export CAROOT="$(wslpath "$(mkcert.exe -CAROOT)")"

mkcert 'sslip.io' '*.sslip.io' 'localtest.me' '*.localtest.me' 'localhost' '127.0.0.1' '::1'
