##### supervisor

##### directory structure

```
conf/
	|--supervisord.conf
	|--supervisord_celery_flower.ini
	|--supervisord_celery_worker.ini
	|--supervisord_celery_beat.ini	
```

##### supervisor setup

```
pip install supervisor
```

```
echo_supervisord_conf >conf/supervisord.conf

#open it 
[inet_http_server]         ; inet (TCP) server disabled by default
port=127.0.0.1:9001        ; ip_address:port specifier, *:port for all iface
[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket
serverurl=http://127.0.0.1:9001 ; use an http:// url to specify an inet socket
[include]
files = *.ini
```

##### configure service

```
[program:celery-beat]
command=python manage.py celery beat --loglevel=info
directory=/data/python/inveno
environment=PATH='/data/python_env/inveno/bin/'
stdout_logfile=/data/python/inveno/logs/supervisor_celery_beat.log
stderr_logfile=/data/python/inveno/logs/supervisor_celery_beat_error.log
autostart=true
autorestart=true
startsecs=10
stopwaitsecs=10
priority=997
```

##### 优先级

```
The relative priority of the program in the start and shutdown ordering. Lower priorities indicate programs that start first and shut down last at startup and when aggregate commands are used in various clients (e.g. “start all”/”stop all”). Higher priorities indicate programs that start last and shut down first.

Default: 999
```

##### start service

```
supervisord -c conf/supervisord.conf
shell>supervisorctl
shell>status  #查看服务状态
shell>update  #新增配置文件后，使用这个命令加入
```



