#!/usr/bin/python3
import argparse
from os import system, popen

parser = argparse.ArgumentParser(description='Script para separar usuarios de site')
#Adicionando argumentos
parser.add_argument("-s", "--site",help='Nome do site, ex: site.com.br', required=True)
args = parser.parse_args()
site = args.site.strip()

user = popen(f'echo {site} | cut -f1 -d "." | cut -f1 -d "-"').read().strip()
print('Script Iniciado!')
print('Criando usuario')
system(f'useradd {user} 2>/dev/null ')
system(f'sudo gpasswd -a {user} {user} 2>/dev/null ')
system(f'sudo gpasswd -a www-data {user} 2>/dev/null ')
system(f'sudo gpasswd -a deploy {user} 2>/dev/null ')
system(f'sudo gpasswd -a {user} www-data 2>/dev/null ')
print('Verificando tipo de core')
pocket = popen(f'cat /var/www/vhosts/{site}/httpdocs/wp-cli.yml').read().strip()
if pocket != '':
    pocket = 'pocket'
    print('É Pocket')
else:
    pocket = 'Legba'
    print('É Legba')
print('Atribuindo permissões corretas')
system(f'chown -R {user}:{user} /var/www/vhosts/{site}')
system(f'sudo find /var/www/vhosts/{site} -type d ! -perm 775 -exec chmod 775 {{}} \;')
system(f'sudo find /var/www/vhosts/{site} -type f ! -perm 644 -exec chmod 644 {{}} \;')
system(f'sudo chmod 770 /var/www/vhosts/{site}/')
system(f'sudo chmod 770 /mnt/uploads_apl04/{site}/')
if pocket == 'pocket':
    system(f'chown -R {user}:{user} /var/www/vhosts/{site}/httpdocs/web/app/uploads/')
    system(f'sudo chmod 400 /var/www/vhosts/{site}/httpdocs/.env')
else:
    system(f'chown -R {user}:{user} /var/www/vhosts/{site}/httpdocs/wp-content/uploads/')
    system(f'sudo chmod 400 /var/www/vhosts/{site}/httpdocs/wp-config.php')
print('Identificando o caminho do arquivo de configuração')
file_conf = popen(f"cat /etc/nginx/sites-available/{site}.conf | grep include | grep -v restric | grep -v letsencrypt | grep -v access.log | awk '{{ print $2 }}'").read().strip()[:-1]
if 'etc/nginx' in file_conf:
    file_conf = file_conf[11:]
print(f'Criando arquivo de configuração: /etc/nginx/global/{user}.conf apartir de /etc/nginx/{file_conf}')
system(f'cp /etc/nginx/{file_conf} /etc/nginx/global/{user}.conf')
print('Identificando versão do php')
versao_php = popen(f'cat /etc/nginx/global/{user}.conf | grep php/php | cut -f4 -d "/" | cut -f1 -d "-" | cut -f3 -d "p"').read().strip()[:3]
print('Criando novo pool php-fpm')
system(f"cp /etc/php/{versao_php}/fpm/pool.d/padrao.conf /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf")
print('Configurando o pool php-fpm')
system(f'sed -i "s/\[www\]/\[{user}\]/g" /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf')
system(f'sed -i "s/user = www-data/user = {user}/g" /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf')
system(f'sed -i "s/group = www-data/group = {user}/g" /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf')
system(f'sed -i "s/.group = {user}/.group = www-data/g" /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf')
system(f'sed -i "s/php{versao_php}-fpm.sock/php{versao_php}-fpm-{user}.sock/g" /etc/php/{versao_php}/fpm/pool.d/fpm-{user}.conf')
print(f'Configurando /etc/nginx/sites-available/{site}.conf')
config = file_conf.replace('/', '\/')
system(f'sed -i "s/{config}/global\/{user}.conf/g" /etc/nginx/sites-available/{site}.conf')
print(f'Reiniciando php{versao_php}-fpm')
system(f'service php{versao_php}-fpm restart')
print(f'Ajustando o arquivo /etc/nginx/global/{user}.conf')
php_fpm = popen(f'cat /etc/nginx/global/{user}.conf | grep "php/" | cut -f4 -d "/"').readlines()
for fpm in php_fpm:
    system(f'sed -i "s/{fpm.strip()}/php{versao_php}-fpm-{user}.sock;/g" /etc/nginx/global/{user}.conf')
print(f'Reiniciando php{versao_php}-fpm')
system('service nginx restart')
print('Script Finalizado com Sucesso!')
