##### celery

#####  directory structure

```
tasks
	|---celeryconfig.py
	|---run.py
	|---test1.py
	|---test2.py
```

##### celery config

```
from datetime import timedelta
from celery.schedules import crontab


# celery & redis
BROKER_URL = 'redis://localhost:6379/0'

CELERY_RESULT_BACKEND = 'redis://localhost:6379/1'

CELERY_TIMEZONE = 'Asia/Shanghai'

BROKER_TRANSPORT_OPTIONS = {'visibility_timeout': 3600}

CELERY_TASK_SERIALIZER = 'msgpack'

CELERY_RESULT_SERIALIZER = 'json'

CELERY_TASK_RESULT_EXPIRES = 60 * 60 * 24

# 导入指定的任务模块
CELERY_IMPORTS = (
    'tasks.test1',
    'tasks.test2'
)

CELERYBEAT_SCHEDULE = {
    'task1': {
        'task': 'tasks.test2.add',
        'schedule': timedelta(seconds=10),
        'args': (2, 9)
    },
    'task2': {
        'task': 'tasks.test1.multiply',
        'schedule': crontab(hour=16, minute=8),
        'args': (2, 9)
    },
}

# celery - A tasks worker - -loglevel = info
# celery - A tasks beat - -loglevel = info
# celery -B  -A tasks worker --loglevel=info 一条命令执行beat&work
# pip install redis >2.10.6 <3
# django python manage.py celery worker -Q queue

```

##### test2.py

```
from tasks import app


@app.task
def add(x, y):
    return x + y
```

##### test1.py

```
from tasks import app


@app.task
def multiply(x, y):
    return x * y
```

##### run.py

```
from tasks import test1
from tasks import test2


test1.multiply.delay(4, 5)
test2.add.delay(2, 3)

```

